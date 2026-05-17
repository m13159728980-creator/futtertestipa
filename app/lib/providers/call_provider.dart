import 'dart:async';

import 'package:app/core/services/sound_effect_service.dart';
import 'package:app/core/services/webrtc_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/models/call_session.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final webRtcServiceProvider = Provider<WebRtcService>((ref) {
  final service = FlutterWebRtcService();
  ref.onDispose(service.cleanup);
  return service;
});

final callProvider = ChangeNotifierProvider<CallProvider>((ref) {
  final auth = ref.watch(authProvider);
  final webSocketService = ref.watch(webSocketServiceProvider);
  return CallProvider(
    currentUserId: auth.user?.id ?? '',
    currentUserName: auth.user?.displayName ?? '',
    signalingService: WebSocketCallSignalingService(webSocketService),
    webRtcService: ref.watch(webRtcServiceProvider),
    soundEffects: ref.watch(soundEffectPlayerProvider),
  );
}, dependencies: [soundEffectPlayerProvider]);

abstract interface class CallSignalingService {
  Stream<WebSocketEvent> get events;
  void send(WebSocketEvent event);
}

class WebSocketCallSignalingService implements CallSignalingService {
  const WebSocketCallSignalingService(this._webSocketService);

  final WebSocketService _webSocketService;

  @override
  Stream<WebSocketEvent> get events => _webSocketService.events;

  @override
  void send(WebSocketEvent event) => _webSocketService.send(event);
}

class CallProvider extends ChangeNotifier {
  CallProvider({
    required String currentUserId,
    String currentUserName = '',
    required CallSignalingService signalingService,
    required WebRtcService webRtcService,
    SoundEffectPlayer? soundEffects,
    String Function()? callIdFactory,
    DateTime Function()? now,
  }) : _currentUserId = currentUserId,
       _currentUserName = currentUserName,
       _signalingService = signalingService,
       _webRtcService = webRtcService,
       _soundEffects = soundEffects,
       _callIdFactory = callIdFactory ?? const Uuid().v4,
       _now = now ?? DateTime.now {
    _subscription = _signalingService.events.listen(handleEvent);
  }

  static const maxParticipants = 8;

  final String _currentUserId;
  final String _currentUserName;
  final CallSignalingService _signalingService;
  final WebRtcService _webRtcService;
  final SoundEffectPlayer? _soundEffects;
  final String Function() _callIdFactory;
  final DateTime Function() _now;
  StreamSubscription<WebSocketEvent>? _subscription;

  CallSession? _session;
  final List<Map<String, dynamic>> _pendingSdp = [];
  final List<Map<String, dynamic>> _pendingIce = [];
  bool _isMicMuted = false;
  bool _isSpeakerOn = false;
  bool _isCameraOff = false;
  bool _isVideoCall = false;

  CallSession? get session => _session;
  bool get isMicMuted => _isMicMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isCameraOff => _isCameraOff;
  bool get isVideoCall => _isVideoCall;

  Future<void> startOneToOneCall({
    required String peerId,
    required String peerName,
    bool video = false,
  }) async {
    await _startCall(
      peerIds: [peerId],
      title: peerName,
      isGroup: false,
      video: video,
    );
  }

  Future<void> startGroupCall({
    required List<String> peerIds,
    required String groupName,
    bool video = false,
  }) async {
    await _startCall(
      peerIds: peerIds,
      title: groupName,
      isGroup: true,
      video: video,
    );
  }

  Future<void> _startCall({
    required List<String> peerIds,
    required String title,
    required bool isGroup,
    required bool video,
  }) async {
    final participantIds = [_currentUserId, ...peerIds];
    if (participantIds.length > maxParticipants) {
      throw ArgumentError('Group calls support up to 8 participants');
    }
    final callId = _callIdFactory();
    _session = CallSession(
      id: callId,
      state: CallState.outgoing,
      participantIds: participantIds,
      participants: {
        for (final id in participantIds) id: CallParticipantState.invited,
      },
      isGroup: isGroup,
      title: title,
      peerId: isGroup ? null : peerIds.first,
    );
    _isVideoCall = video;
    _isCameraOff = !video;
    unawaited(_soundEffects?.startRinging() ?? Future.value());
    await _webRtcService.startLocalMedia(video: video);
    await _ensurePeerConnections(peerIds);
    _signalingService.send(
      WebSocketEvent(
        type: 'call.invite',
        payload: {
          'callId': callId,
          'participantIds': peerIds,
          'isGroup': isGroup,
          'video': video,
          'title': title,
          'peerTitle': title,
          if (_currentUserName.trim().isNotEmpty)
            'fromName': _currentUserName.trim(),
        },
      ),
    );
    for (final peerId in peerIds) {
      final offer = await _webRtcService.createOffer(peerId);
      await _webRtcService.setLocalDescription(peerId, offer);
      _sendSdp(peerId, offer);
    }
    notifyListeners();
  }

  Future<void> accept() async {
    final current = _session;
    if (current == null) {
      return;
    }
    await _soundEffects?.stopRinging();
    unawaited(_soundEffects?.play(SoundEffect.callAccepted) ?? Future.value());
    await _webRtcService.startLocalMedia(video: _isVideoCall);
    await _ensurePeerConnections(
      current.participantIds.where((id) => id != _currentUserId),
    );
    _session = current.copyWith(
      state: CallState.active,
      startedAt: _now(),
      participants: {
        ...current.participants,
        _currentUserId: CallParticipantState.active,
      },
    );
    _signalingService.send(
      WebSocketEvent(type: 'call.accept', payload: {'callId': current.id}),
    );
    await _flushPendingSignaling();
    notifyListeners();
  }

  Future<void> reject() async {
    await _sendTerminal('call.reject');
  }

  Future<void> hangup() async {
    await _sendTerminal('call.hangup');
  }

  Future<void> _sendTerminal(String type) async {
    final current = _session;
    if (current == null) {
      return;
    }
    _signalingService.send(
      WebSocketEvent(type: type, payload: {'callId': current.id}),
    );
    await _soundEffects?.stopRinging();
    unawaited(_soundEffects?.play(SoundEffect.callEnded) ?? Future.value());
    await _endLocalCall(stopRinging: false);
  }

  Future<void> toggleMic() async {
    _isMicMuted = !_isMicMuted;
    await _webRtcService.setMicrophoneEnabled(!_isMicMuted);
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await _webRtcService.setSpeakerEnabled(_isSpeakerOn);
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    _isCameraOff = !_isCameraOff;
    await _webRtcService.setCameraEnabled(!_isCameraOff);
    notifyListeners();
  }

  Future<void> handleEvent(WebSocketEvent event) async {
    switch (event.type) {
      case 'call.invite':
        _handleInvite(event.payload);
      case 'call.accept':
        _updateFromParticipantEvent(event.payload, CallState.active);
      case 'call.reject':
      case 'call.hangup':
        await _handleRemoteTerminal(event.payload);
      case 'call.sdp':
        await _handleSdp(event.payload);
      case 'call.ice':
        await _handleIce(event.payload);
    }
  }

  void _handleInvite(Map<String, dynamic> payload) {
    final callId = payload['callId']?.toString();
    final fromId = payload['fromId']?.toString();
    if (callId == null || fromId == null) {
      return;
    }
    final ids = _stringList(payload['participantIds']);
    final participantIds = ids.contains(_currentUserId)
        ? ids
        : [...ids, _currentUserId];
    _session = CallSession(
      id: callId,
      state: CallState.incoming,
      participantIds: participantIds,
      participants: _participantsFromPayload(payload, participantIds),
      isGroup: payload['isGroup'] == true,
      title: _incomingTitle(
        payload,
        currentUserName: _currentUserName,
        fallback: fromId,
      ),
      peerId: fromId,
    );
    _isVideoCall = payload['video'] == true;
    _isCameraOff = !_isVideoCall;
    unawaited(_soundEffects?.startRinging() ?? Future.value());
    notifyListeners();
  }

  void _updateFromParticipantEvent(
    Map<String, dynamic> payload,
    CallState? state,
  ) {
    final current = _session;
    if (current == null || payload['callId']?.toString() != current.id) {
      return;
    }
    final participants = _participantsFromPayload(
      payload,
      current.participantIds,
    );
    _session = current.copyWith(
      state: state ?? current.state,
      startedAt: state == CallState.active && current.startedAt == null
          ? _now()
          : current.startedAt,
      participants: participants,
    );
    if (state == CallState.active) {
      unawaited(_soundEffects?.stopRinging() ?? Future.value());
      unawaited(
        _soundEffects?.play(SoundEffect.callAccepted) ?? Future.value(),
      );
    }
    notifyListeners();
  }

  Future<void> _handleRemoteTerminal(Map<String, dynamic> payload) async {
    final current = _session;
    if (current == null || payload['callId']?.toString() != current.id) {
      return;
    }
    await _soundEffects?.stopRinging();
    unawaited(_soundEffects?.play(SoundEffect.callEnded) ?? Future.value());
    await _endLocalCall(stopRinging: false);
  }

  Future<void> _endLocalCall({bool stopRinging = true}) async {
    if (stopRinging) {
      await _soundEffects?.stopRinging();
    }
    _session = null;
    _pendingSdp.clear();
    _pendingIce.clear();
    _isMicMuted = false;
    _isSpeakerOn = false;
    _isCameraOff = false;
    _isVideoCall = false;
    await _webRtcService.cleanup();
    notifyListeners();
  }

  Future<void> _handleSdp(Map<String, dynamic> payload) async {
    if (_session?.state == CallState.incoming) {
      _pendingSdp.add(Map<String, dynamic>.from(payload));
      return;
    }
    final fromId = payload['fromId']?.toString();
    final description = _map(payload['description']);
    if (fromId == null || description == null) {
      return;
    }
    await _webRtcService.ensurePeerConnection(
      fromId,
      onIceCandidate: (candidate) => _sendIce(fromId, candidate),
    );
    final rtcDescription = RtcSessionDescription.fromMap(description);
    await _webRtcService.setRemoteDescription(fromId, rtcDescription);
    if (rtcDescription.type == 'offer') {
      final answer = await _webRtcService.createAnswer(fromId);
      await _webRtcService.setLocalDescription(fromId, answer);
      _sendSdp(fromId, answer);
    }
  }

  Future<void> _handleIce(Map<String, dynamic> payload) async {
    if (_session?.state == CallState.incoming) {
      _pendingIce.add(Map<String, dynamic>.from(payload));
      return;
    }
    final fromId = payload['fromId']?.toString();
    final candidate = _map(payload['candidate']);
    if (fromId == null || candidate == null) {
      return;
    }
    await _webRtcService.addIceCandidate(fromId, candidate);
  }

  Future<void> _flushPendingSignaling() async {
    final pendingSdp = [..._pendingSdp];
    final pendingIce = [..._pendingIce];
    _pendingSdp.clear();
    _pendingIce.clear();
    for (final payload in pendingSdp) {
      await _handleSdp(payload);
    }
    for (final payload in pendingIce) {
      await _handleIce(payload);
    }
  }

  Future<void> _ensurePeerConnections(Iterable<String> peerIds) async {
    for (final peerId in peerIds) {
      await _webRtcService.ensurePeerConnection(
        peerId,
        onIceCandidate: (candidate) => _sendIce(peerId, candidate),
      );
    }
  }

  void _sendIce(String peerId, Map<String, dynamic> candidate) {
    final current = _session;
    if (current == null) {
      return;
    }
    _signalingService.send(
      WebSocketEvent(
        type: 'call.ice',
        payload: {
          'callId': current.id,
          'targetId': peerId,
          'candidate': candidate,
        },
      ),
    );
  }

  void _sendSdp(String peerId, RtcSessionDescription description) {
    final current = _session;
    if (current == null) {
      return;
    }
    _signalingService.send(
      WebSocketEvent(
        type: 'call.sdp',
        payload: {
          'callId': current.id,
          'targetId': peerId,
          'description': description.toMap(),
        },
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(_webRtcService.cleanup());
    super.dispose();
  }
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map((item) => item.toString()).toList();
}

Map<String, CallParticipantState> _participantsFromPayload(
  Map<String, dynamic> payload,
  List<String> participantIds,
) {
  final raw = payload['participants'];
  if (raw is Map) {
    return {
      for (final entry in raw.entries)
        entry.key.toString(): callParticipantStateFromJson(entry.value),
    };
  }
  return {for (final id in participantIds) id: CallParticipantState.invited};
}

String _incomingTitle(
  Map<String, dynamic> payload, {
  required String currentUserName,
  required String fallback,
}) {
  if (payload['isGroup'] == true) {
    return _firstNonEmpty([payload['title'], payload['groupName'], fallback]);
  }
  return _firstNonEmpty([
    payload['fromName'],
    payload['callerName'],
    payload['caller'] is Map ? (payload['caller'] as Map)['displayName'] : null,
    _legacyTitleIfNotCurrentUser(payload['title'], currentUserName),
    fallback,
  ]);
}

String? _legacyTitleIfNotCurrentUser(Object? value, String currentUserName) {
  final title = value?.toString().trim();
  if (title == null || title.isEmpty) {
    return null;
  }
  final current = currentUserName.trim();
  if (current.isNotEmpty && title == current) {
    return null;
  }
  return title;
}

String _firstNonEmpty(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

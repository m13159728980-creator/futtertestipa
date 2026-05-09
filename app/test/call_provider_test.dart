import 'dart:async';

import 'package:app/core/services/webrtc_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/models/call_session.dart';
import 'package:app/providers/call_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts outgoing one-to-one call and sends invite', () async {
    final signaling = _FakeSignalingService();
    final media = _FakeWebRtcService();
    final provider = CallProvider(
      currentUserId: 'me',
      signalingService: signaling,
      webRtcService: media,
      callIdFactory: () => 'call-1',
    );

    await provider.startOneToOneCall(peerId: 'alice', peerName: 'Alice');

    expect(provider.session?.state, CallState.outgoing);
    expect(provider.session?.participantIds, ['me', 'alice']);
    expect(signaling.sent.single.type, 'call.invite');
    expect(signaling.sent.single.payload, containsPair('participantIds', ['alice']));
    expect(media.localMediaStarted, isTrue);
  });

  test('rejects group calls above 8 participants', () async {
    final provider = CallProvider(
      currentUserId: 'me',
      signalingService: _FakeSignalingService(),
      webRtcService: _FakeWebRtcService(),
    );

    expect(
      () => provider.startGroupCall(peerIds: ['1', '2', '3', '4', '5', '6', '7', '8'], groupName: 'Team'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('incoming accept starts duration and sends accept', () async {
    final signaling = _FakeSignalingService();
    final media = _FakeWebRtcService();
    final provider = CallProvider(
      currentUserId: 'me',
      signalingService: signaling,
      webRtcService: media,
      now: () => DateTime.utc(2026, 5, 10, 1),
    );

    await provider.handleEvent(
      const WebSocketEvent(
        type: 'call.invite',
        payload: {
          'callId': 'call-2',
          'fromId': 'alice',
          'participantIds': ['me'],
          'isGroup': false,
        },
      ),
    );
    await provider.accept();

    expect(provider.session?.state, CallState.active);
    expect(provider.session?.startedAt, DateTime.utc(2026, 5, 10, 1));
    expect(signaling.sent.last.type, 'call.accept');
    expect(media.localMediaStarted, isTrue);
  });

  test('toggles local mic speaker and camera', () async {
    final media = _FakeWebRtcService();
    final provider = CallProvider(
      currentUserId: 'me',
      signalingService: _FakeSignalingService(),
      webRtcService: media,
    );

    await provider.toggleMic();
    await provider.toggleSpeaker();
    await provider.toggleCamera();

    expect(provider.isMicMuted, isTrue);
    expect(provider.isSpeakerOn, isTrue);
    expect(provider.isCameraOff, isTrue);
    expect(media.micEnabled, isFalse);
    expect(media.speakerEnabled, isTrue);
    expect(media.cameraEnabled, isFalse);
  });

  test('processes sdp and ice through web rtc service', () async {
    final media = _FakeWebRtcService();
    final provider = CallProvider(
      currentUserId: 'me',
      signalingService: _FakeSignalingService(),
      webRtcService: media,
    );
    await provider.startOneToOneCall(peerId: 'alice', peerName: 'Alice');

    await provider.handleEvent(
      const WebSocketEvent(
        type: 'call.sdp',
        payload: {
          'callId': 'call-1',
          'fromId': 'alice',
          'description': {'type': 'answer', 'sdp': 'v=0'},
        },
      ),
    );
    await provider.handleEvent(
      const WebSocketEvent(
        type: 'call.ice',
        payload: {
          'callId': 'call-1',
          'fromId': 'alice',
          'candidate': {'candidate': 'candidate:1'},
        },
      ),
    );

    expect(media.remoteDescriptions, containsPair('alice', {'type': 'answer', 'sdp': 'v=0'}));
    expect(media.iceCandidates, containsPair('alice', {'candidate': 'candidate:1'}));
  });
}

class _FakeSignalingService implements CallSignalingService {
  final sent = <WebSocketEvent>[];

  @override
  Stream<WebSocketEvent> get events => const Stream.empty();

  @override
  void send(WebSocketEvent event) {
    sent.add(event);
  }
}

class _FakeWebRtcService implements WebRtcService {
  bool localMediaStarted = false;
  bool micEnabled = true;
  bool speakerEnabled = false;
  bool cameraEnabled = true;
  final remoteDescriptions = <String, Map<String, dynamic>>{};
  final iceCandidates = <String, Map<String, dynamic>>{};

  @override
  Future<void> startLocalMedia({bool video = true}) async {
    localMediaStarted = true;
  }

  @override
  Future<void> ensurePeerConnection(String peerId, {required void Function(Map<String, dynamic>) onIceCandidate}) async {}

  @override
  Future<void> setRemoteDescription(String peerId, Map<String, dynamic> description) async {
    remoteDescriptions[peerId] = description;
  }

  @override
  Future<void> addIceCandidate(String peerId, Map<String, dynamic> candidate) async {
    iceCandidates[peerId] = candidate;
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    micEnabled = enabled;
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {
    speakerEnabled = enabled;
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    cameraEnabled = enabled;
  }

  @override
  Future<void> cleanup() async {}
}

import 'package:flutter_webrtc/flutter_webrtc.dart';

class RtcSessionDescription {
  const RtcSessionDescription({required this.type, required this.sdp});

  final String type;
  final String sdp;

  factory RtcSessionDescription.fromMap(Map<String, dynamic> map) {
    return RtcSessionDescription(
      type: map['type']?.toString() ?? '',
      sdp: map['sdp']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'type': type, 'sdp': sdp};

  RTCSessionDescription toWebRtc() => RTCSessionDescription(sdp, type);

  static RtcSessionDescription fromWebRtc(RTCSessionDescription description) {
    return RtcSessionDescription(
      type: description.type ?? '',
      sdp: description.sdp ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RtcSessionDescription &&
            other.type == type &&
            other.sdp == sdp;
  }

  @override
  int get hashCode => Object.hash(type, sdp);
}

abstract interface class WebRtcService {
  Future<void> startLocalMedia({bool video = true});
  Future<void> ensurePeerConnection(
    String peerId, {
    required void Function(Map<String, dynamic>) onIceCandidate,
  });
  Future<RtcSessionDescription> createOffer(String peerId);
  Future<RtcSessionDescription> createAnswer(String peerId);
  Future<void> setLocalDescription(
    String peerId,
    RtcSessionDescription description,
  );
  Future<void> setRemoteDescription(
    String peerId,
    RtcSessionDescription description,
  );
  Future<void> addIceCandidate(String peerId, Map<String, dynamic> candidate);
  Future<void> setMicrophoneEnabled(bool enabled);
  Future<void> setSpeakerEnabled(bool enabled);
  Future<void> setCameraEnabled(bool enabled);
  Future<void> cleanup();
}

class FlutterWebRtcService implements WebRtcService {
  final Map<String, RTCPeerConnection> _connections = {};
  MediaStream? _localStream;

  static const Map<String, dynamic> defaultConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  @override
  Future<void> startLocalMedia({bool video = true}) async {
    _localStream ??= await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video,
    });
  }

  @override
  Future<void> ensurePeerConnection(
    String peerId, {
    required void Function(Map<String, dynamic>) onIceCandidate,
  }) async {
    if (_connections.containsKey(peerId)) {
      return;
    }
    final connection = await createPeerConnection(defaultConfiguration);
    final stream = _localStream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await connection.addTrack(track, stream);
      }
    }
    connection.onIceCandidate = (candidate) {
      if (candidate.candidate == null) {
        return;
      }
      onIceCandidate(candidate.toMap());
    };
    _connections[peerId] = connection;
  }

  @override
  Future<RtcSessionDescription> createOffer(String peerId) async {
    final description = await _connectionFor(peerId).createOffer();
    return RtcSessionDescription.fromWebRtc(description);
  }

  @override
  Future<RtcSessionDescription> createAnswer(String peerId) async {
    final description = await _connectionFor(peerId).createAnswer();
    return RtcSessionDescription.fromWebRtc(description);
  }

  @override
  Future<void> setLocalDescription(
    String peerId,
    RtcSessionDescription description,
  ) async {
    await _connectionFor(peerId).setLocalDescription(description.toWebRtc());
  }

  @override
  Future<void> setRemoteDescription(
    String peerId,
    RtcSessionDescription description,
  ) async {
    await _connectionFor(peerId).setRemoteDescription(description.toWebRtc());
  }

  @override
  Future<void> addIceCandidate(
    String peerId,
    Map<String, dynamic> candidate,
  ) async {
    final connection = _connections[peerId];
    if (connection == null) {
      return;
    }
    await connection.addCandidate(
      RTCIceCandidate(
        candidate['candidate']?.toString(),
        candidate['sdpMid']?.toString(),
        candidate['sdpMLineIndex'] as int?,
      ),
    );
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    for (final track
        in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = enabled;
    }
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) {
    return Helper.setSpeakerphoneOn(enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    for (final track
        in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = enabled;
    }
  }

  @override
  Future<void> cleanup() async {
    for (final connection in _connections.values) {
      await connection.close();
    }
    _connections.clear();
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _localStream?.dispose();
    _localStream = null;
  }

  RTCPeerConnection _connectionFor(String peerId) {
    final connection = _connections[peerId];
    if (connection == null) {
      throw StateError('Peer connection has not been created for $peerId');
    }
    return connection;
  }
}

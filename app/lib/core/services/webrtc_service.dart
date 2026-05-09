import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract interface class WebRtcService {
  Future<void> startLocalMedia({bool video = true});
  Future<void> ensurePeerConnection(
    String peerId, {
    required void Function(Map<String, dynamic>) onIceCandidate,
  });
  Future<void> setRemoteDescription(
    String peerId,
    Map<String, dynamic> description,
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
  Future<void> setRemoteDescription(
    String peerId,
    Map<String, dynamic> description,
  ) async {
    final connection = _connections[peerId];
    if (connection == null) {
      return;
    }
    await connection.setRemoteDescription(
      RTCSessionDescription(
        description['sdp']?.toString(),
        description['type']?.toString(),
      ),
    );
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
    for (final track in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = enabled;
    }
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) {
    return Helper.setSpeakerphoneOn(enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    for (final track in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
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
}

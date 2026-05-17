import 'dart:async';

import 'package:app/core/services/sound_effect_service.dart';
import 'package:app/core/services/webrtc_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/models/call_session.dart';
import 'package:app/providers/call_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts outgoing one-to-one call and sends invite then offer', () async {
    final signaling = _FakeSignalingService();
    final media = _FakeWebRtcService();
    media.offers['alice'] = const RtcSessionDescription(
      type: 'offer',
      sdp: 'offer-sdp',
    );
    final provider = CallProvider(
      currentUserId: 'me',
      signalingService: signaling,
      webRtcService: media,
      callIdFactory: () => 'call-1',
    );

    await provider.startOneToOneCall(peerId: 'alice', peerName: 'Alice');

    expect(provider.session?.state, CallState.outgoing);
    expect(provider.session?.participantIds, ['me', 'alice']);
    expect(signaling.sent.map((event) => event.type), [
      'call.invite',
      'call.sdp',
    ]);
    expect(
      signaling.sent.first.payload,
      containsPair('participantIds', ['alice']),
    );
    expect(signaling.sent.last.payload, {
      'callId': 'call-1',
      'targetId': 'alice',
      'description': {'type': 'offer', 'sdp': 'offer-sdp'},
    });
    expect(media.localMediaStarted, isTrue);
    expect(media.lastVideoEnabled, isFalse);
    expect(
      media.localDescriptions,
      containsPair('alice', media.offers['alice']),
    );
  });

  test('rejects group calls above 8 participants', () async {
    final provider = CallProvider(
      currentUserId: 'me',
      signalingService: _FakeSignalingService(),
      webRtcService: _FakeWebRtcService(),
    );

    expect(
      () => provider.startGroupCall(
        peerIds: ['1', '2', '3', '4', '5', '6', '7', '8'],
        groupName: 'Team',
      ),
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
    expect(media.lastVideoEnabled, isFalse);
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

  test(
    'active call receiving offer sets remote description and sends answer',
    () async {
      final signaling = _FakeSignalingService();
      final media = _FakeWebRtcService();
      media.answers['alice'] = const RtcSessionDescription(
        type: 'answer',
        sdp: 'answer-sdp',
      );
      final provider = CallProvider(
        currentUserId: 'me',
        signalingService: signaling,
        webRtcService: media,
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
      signaling.sent.clear();

      await provider.handleEvent(
        const WebSocketEvent(
          type: 'call.sdp',
          payload: {
            'callId': 'call-2',
            'fromId': 'alice',
            'description': {'type': 'offer', 'sdp': 'offer-sdp'},
          },
        ),
      );

      expect(
        media.remoteDescriptions,
        containsPair(
          'alice',
          const RtcSessionDescription(type: 'offer', sdp: 'offer-sdp'),
        ),
      );
      expect(
        media.localDescriptions,
        containsPair('alice', media.answers['alice']),
      );
      expect(signaling.sent.single.type, 'call.sdp');
      expect(signaling.sent.single.payload, {
        'callId': 'call-2',
        'targetId': 'alice',
        'description': {'type': 'answer', 'sdp': 'answer-sdp'},
      });
    },
  );

  test(
    'incoming offer waits until accept so local media is attached first',
    () async {
      final signaling = _FakeSignalingService();
      final media = _FakeWebRtcService();
      media.answers['alice'] = const RtcSessionDescription(
        type: 'answer',
        sdp: 'answer-sdp',
      );
      final provider = CallProvider(
        currentUserId: 'me',
        signalingService: signaling,
        webRtcService: media,
      );
      await provider.handleEvent(
        const WebSocketEvent(
          type: 'call.invite',
          payload: {
            'callId': 'call-2',
            'fromId': 'alice',
            'participantIds': ['alice', 'me'],
            'isGroup': false,
          },
        ),
      );

      await provider.handleEvent(
        const WebSocketEvent(
          type: 'call.sdp',
          payload: {
            'callId': 'call-2',
            'fromId': 'alice',
            'description': {'type': 'offer', 'sdp': 'offer-sdp'},
          },
        ),
      );

      expect(signaling.sent, isEmpty);
      expect(media.remoteDescriptions, isEmpty);

      await provider.accept();

      expect(media.localMediaStarted, isTrue);
      expect(
        media.remoteDescriptions,
        containsPair(
          'alice',
          const RtcSessionDescription(type: 'offer', sdp: 'offer-sdp'),
        ),
      );
      expect(signaling.sent.map((event) => event.type), [
        'call.accept',
        'call.sdp',
      ]);
    },
  );

  test(
    'incoming invite notifies listeners so the shell can open call screen',
    () async {
      var listenerCalls = 0;
      final provider = CallProvider(
        currentUserId: 'me',
        signalingService: _FakeSignalingService(),
        webRtcService: _FakeWebRtcService(),
      )..addListener(() => listenerCalls += 1);

      await provider.handleEvent(
        const WebSocketEvent(
          type: 'call.invite',
          payload: {
            'callId': 'call-2',
            'fromId': 'alice',
            'participantIds': ['alice', 'me'],
            'isGroup': false,
            'title': 'Alice',
          },
        ),
      );

      expect(provider.session?.state, CallState.incoming);
      expect(provider.session?.title, 'Alice');
      expect(listenerCalls, 1);
    },
  );

  test(
    'incoming one-to-one call title uses caller name instead of callee title',
    () async {
      final provider = CallProvider(
        currentUserId: 'me',
        currentUserName: 'Me',
        signalingService: _FakeSignalingService(),
        webRtcService: _FakeWebRtcService(),
      );

      await provider.handleEvent(
        const WebSocketEvent(
          type: 'call.invite',
          payload: {
            'callId': 'call-3',
            'fromId': 'alice',
            'fromName': 'Alice',
            'participantIds': ['alice', 'me'],
            'isGroup': false,
            'title': 'Me',
          },
        ),
      );

      expect(provider.session?.title, 'Alice');
    },
  );

  test(
    'outgoing one-to-one call includes caller name in invite payload',
    () async {
      final signaling = _FakeSignalingService();
      final provider = CallProvider(
        currentUserId: 'me',
        currentUserName: 'Me',
        signalingService: signaling,
        webRtcService: _FakeWebRtcService(),
        callIdFactory: () => 'call-4',
      );

      await provider.startOneToOneCall(peerId: 'alice', peerName: 'Alice');

      expect(signaling.sent.first.type, 'call.invite');
      expect(signaling.sent.first.payload, containsPair('fromName', 'Me'));
      expect(signaling.sent.first.payload, containsPair('peerTitle', 'Alice'));
    },
  );

  test('incoming and answered calls play call sound effects', () async {
    final sounds = _FakeSoundEffects();
    final provider = CallProvider(
      currentUserId: 'me',
      signalingService: _FakeSignalingService(),
      webRtcService: _FakeWebRtcService(),
      soundEffects: sounds,
      now: () => DateTime.utc(2026, 5, 10, 1),
    );

    await provider.handleEvent(
      const WebSocketEvent(
        type: 'call.invite',
        payload: {
          'callId': 'call-2',
          'fromId': 'alice',
          'participantIds': ['alice', 'me'],
          'isGroup': false,
          'title': 'Alice',
        },
      ),
    );
    await provider.accept();
    await provider.handleEvent(
      const WebSocketEvent(
        type: 'call.hangup',
        payload: {'callId': 'call-2', 'fromId': 'alice'},
      ),
    );

    expect(sounds.events, [
      'ring',
      'stop',
      SoundEffect.callAccepted.name,
      'stop',
      SoundEffect.callEnded.name,
    ]);
  });

  test('receiving answer sets remote description', () async {
    final media = _FakeWebRtcService();
    media.offers['alice'] = const RtcSessionDescription(
      type: 'offer',
      sdp: 'offer-sdp',
    );
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

    expect(
      media.remoteDescriptions,
      containsPair(
        'alice',
        const RtcSessionDescription(type: 'answer', sdp: 'v=0'),
      ),
    );
  });

  test('processes ice through web rtc service', () async {
    final media = _FakeWebRtcService();
    final provider = CallProvider(
      currentUserId: 'me',
      signalingService: _FakeSignalingService(),
      webRtcService: media,
    );
    await provider.startOneToOneCall(peerId: 'alice', peerName: 'Alice');

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

    expect(
      media.iceCandidates,
      containsPair('alice', {'candidate': 'candidate:1'}),
    );
  });

  test('remote hangup ends call locally and cleans up media', () async {
    final media = _FakeWebRtcService();
    final provider = CallProvider(
      currentUserId: 'me',
      signalingService: _FakeSignalingService(),
      webRtcService: media,
    );
    await provider.handleEvent(
      const WebSocketEvent(
        type: 'call.invite',
        payload: {
          'callId': 'call-2',
          'fromId': 'alice',
          'participantIds': ['alice', 'me'],
          'isGroup': false,
        },
      ),
    );
    await provider.accept();

    await provider.handleEvent(
      const WebSocketEvent(
        type: 'call.hangup',
        payload: {
          'callId': 'call-2',
          'fromId': 'alice',
          'participants': {'alice': 'left', 'me': 'active'},
        },
      ),
    );

    expect(provider.session, isNull);
    expect(media.cleanedUp, isTrue);
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
  bool? lastVideoEnabled;
  bool micEnabled = true;
  bool speakerEnabled = false;
  bool cameraEnabled = true;
  final offers = <String, RtcSessionDescription>{};
  final answers = <String, RtcSessionDescription>{};
  final localDescriptions = <String, RtcSessionDescription>{};
  final remoteDescriptions = <String, RtcSessionDescription>{};
  final iceCandidates = <String, Map<String, dynamic>>{};
  bool cleanedUp = false;

  @override
  Future<void> startLocalMedia({bool video = true}) async {
    localMediaStarted = true;
    lastVideoEnabled = video;
  }

  @override
  Future<void> ensurePeerConnection(
    String peerId, {
    required void Function(Map<String, dynamic>) onIceCandidate,
  }) async {}

  @override
  Future<RtcSessionDescription> createOffer(String peerId) async {
    return offers[peerId] ??
        RtcSessionDescription(type: 'offer', sdp: 'offer-$peerId');
  }

  @override
  Future<RtcSessionDescription> createAnswer(String peerId) async {
    return answers[peerId] ??
        RtcSessionDescription(type: 'answer', sdp: 'answer-$peerId');
  }

  @override
  Future<void> setLocalDescription(
    String peerId,
    RtcSessionDescription description,
  ) async {
    localDescriptions[peerId] = description;
  }

  @override
  Future<void> setRemoteDescription(
    String peerId,
    RtcSessionDescription description,
  ) async {
    remoteDescriptions[peerId] = description;
  }

  @override
  Future<void> addIceCandidate(
    String peerId,
    Map<String, dynamic> candidate,
  ) async {
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
  Future<void> cleanup() async {
    cleanedUp = true;
  }
}

class _FakeSoundEffects implements SoundEffectPlayer {
  final events = <String>[];

  @override
  Future<void> play(SoundEffect effect) async {
    events.add(effect.name);
  }

  @override
  Future<void> startRinging() async {
    events.add('ring');
  }

  @override
  Future<void> stopRinging() async {
    events.add('stop');
  }
}

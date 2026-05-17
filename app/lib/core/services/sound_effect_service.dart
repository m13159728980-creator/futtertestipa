import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SoundEffect {
  messageReceived('assets/sounds/message_received.wav'),
  messageSent('assets/sounds/message_sent.wav'),
  callRinging('assets/sounds/call_ringing.wav'),
  callAccepted('assets/sounds/call_accepted.wav'),
  callEnded('assets/sounds/call_ended.wav');

  const SoundEffect(this.assetPath);

  final String assetPath;
}

abstract interface class SoundEffectPlayer {
  Future<void> play(SoundEffect effect);

  Future<void> startRinging();

  Future<void> stopRinging();
}

final soundEffectPlayerProvider = Provider<SoundEffectPlayer>((ref) {
  final enabled = ref.watch(
    settingsSoundEnabledProvider,
  );
  if (!enabled) {
    return const SilentSoundEffectPlayer();
  }
  final player = SystemSoundEffectPlayer();
  ref.onDispose(player.stopRinging);
  return player;
});

final settingsSoundEnabledProvider = Provider<bool>((ref) => true);

class SilentSoundEffectPlayer implements SoundEffectPlayer {
  const SilentSoundEffectPlayer();

  @override
  Future<void> play(SoundEffect effect) async {}

  @override
  Future<void> startRinging() async {}

  @override
  Future<void> stopRinging() async {}
}

class SystemSoundEffectPlayer implements SoundEffectPlayer {
  SystemSoundEffectPlayer({AudioPlayer? player})
    : _player = player;

  AudioPlayer? _player;
  Timer? _ringTimer;

  @override
  Future<void> play(SoundEffect effect) async {
    try {
      final player = _ensurePlayer();
      await player.stop();
      await player.play(AssetSource(_assetName(effect)));
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'sound_effect_service',
          context: ErrorDescription('while playing ${effect.name}'),
        ),
      );
    }
  }

  @override
  Future<void> startRinging() async {
    if (_ringTimer != null) {
      return;
    }
    await play(SoundEffect.callRinging);
    _ringTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(play(SoundEffect.callRinging));
    });
  }

  @override
  Future<void> stopRinging() async {
    _ringTimer?.cancel();
    _ringTimer = null;
  }

  String _assetName(SoundEffect effect) {
    return effect.assetPath.replaceFirst('assets/', '');
  }

  AudioPlayer _ensurePlayer() {
    return _player ??= AudioPlayer();
  }
}

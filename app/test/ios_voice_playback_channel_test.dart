import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ios app delegate registers voice playback channel', () async {
    final appDelegate = await File(
      'ios/Runner/AppDelegate.swift',
    ).readAsString();
    final sceneDelegate = await File(
      'ios/Runner/SceneDelegate.swift',
    ).readAsString();

    expect(appDelegate, contains('AVAudioPlayer'));
    expect(appDelegate, contains('static let shared = VoicePlaybackController()'));
    expect(sceneDelegate, contains('app/voice_playback'));
    expect(sceneDelegate, contains('FlutterViewController'));
    expect(sceneDelegate, contains('registerVoicePlaybackChannel'));
    expect(sceneDelegate, contains('VoicePlaybackController.shared'));
  });
}

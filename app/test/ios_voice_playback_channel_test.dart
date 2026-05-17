import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ios app delegate registers voice playback channel', () async {
    final source = await File('ios/Runner/AppDelegate.swift').readAsString();

    expect(source, contains('app/voice_playback'));
    expect(source, contains('AVAudioPlayer'));
    expect(source, contains('playVoice'));
  });
}

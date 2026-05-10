import 'dart:io';

import 'package:app/core/services/voice_recording_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('records to a real audio file path and reports duration on stop', () async {
    final tempDir = await Directory.systemTemp.createTemp('voice_record_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final clock = _ManualClock(DateTime.utc(2026, 5, 10, 1));
    final recorder = _FakeVoiceRecorder();
    final service = VoiceRecordingService(
      rootDirectory: tempDir,
      recorder: recorder,
      clock: clock,
    );

    final startedPath = await service.start();
    expect(startedPath, endsWith('.m4a'));
    expect(startedPath, contains('${p.separator}voice${p.separator}'));
    expect(recorder.startedPath, startedPath);
    clock.now = DateTime.utc(2026, 5, 10, 1, 0, 3);

    final recording = await service.stop();

    expect(recording.file.path, startedPath);
    expect(recording.duration, const Duration(seconds: 3));
  });
}

class _ManualClock implements VoiceRecordingClock {
  _ManualClock(this.now);

  @override
  DateTime now;
}

class _FakeVoiceRecorder implements VoiceRecorderAdapter {
  String? startedPath;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start(String path) async {
    startedPath = path;
    await File(path).create(recursive: true);
    await File(path).writeAsBytes([1, 2, 3]);
  }

  @override
  Future<String?> stop() async => startedPath;

  @override
  Future<void> dispose() async {}
}

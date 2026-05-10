import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

abstract interface class VoiceRecordingClock {
  DateTime get now;
}

class SystemVoiceRecordingClock implements VoiceRecordingClock {
  const SystemVoiceRecordingClock();

  @override
  DateTime get now => DateTime.now();
}

abstract interface class VoiceRecorderAdapter {
  Future<bool> hasPermission();

  Future<void> start(String path);

  Future<String?> stop();

  Future<void> dispose();
}

class RecordVoiceRecorderAdapter implements VoiceRecorderAdapter {
  RecordVoiceRecorderAdapter({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() {
    return _recorder.hasPermission();
  }

  @override
  Future<void> start(String path) {
    return _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
      ),
      path: path,
    );
  }

  @override
  Future<String?> stop() {
    return _recorder.stop();
  }

  @override
  Future<void> dispose() {
    return _recorder.dispose();
  }
}

class VoiceRecording {
  const VoiceRecording({required this.file, required this.duration});

  final File file;
  final Duration duration;
}

class VoiceRecordingService {
  VoiceRecordingService({
    Directory? rootDirectory,
    VoiceRecorderAdapter? recorder,
    VoiceRecordingClock clock = const SystemVoiceRecordingClock(),
  }) : _rootDirectory = rootDirectory,
       _recorder = recorder ?? RecordVoiceRecorderAdapter(),
       _clock = clock;

  final Directory? _rootDirectory;
  final VoiceRecorderAdapter _recorder;
  final VoiceRecordingClock _clock;
  DateTime? _startedAt;
  String? _recordingPath;

  Future<String> start() async {
    if (!await _recorder.hasPermission()) {
      throw const VoiceRecordingException('Microphone permission denied');
    }
    final directory = await _voiceDirectory();
    final path = p.join(
      directory.path,
      'voice_${_clock.now.microsecondsSinceEpoch}.m4a',
    );
    _startedAt = _clock.now;
    _recordingPath = path;
    await _recorder.start(path);
    return path;
  }

  Future<VoiceRecording> stop() async {
    final startedAt = _startedAt;
    final path = await _recorder.stop() ?? _recordingPath;
    _startedAt = null;
    _recordingPath = null;
    if (startedAt == null || path == null) {
      throw const VoiceRecordingException('Recording was not started');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw const VoiceRecordingException('Recording file was not created');
    }
    final duration = _clock.now.difference(startedAt);
    return VoiceRecording(
      file: file,
      duration: duration < const Duration(seconds: 1)
          ? const Duration(seconds: 1)
          : duration,
    );
  }

  Future<void> dispose() {
    return _recorder.dispose();
  }

  Future<Directory> _voiceDirectory() async {
    final root = _rootDirectory ?? await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'media', 'voice'));
    return directory.create(recursive: true);
  }
}

class VoiceRecordingException implements Exception {
  const VoiceRecordingException(this.message);

  final String message;

  @override
  String toString() => message;
}

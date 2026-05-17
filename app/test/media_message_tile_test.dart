import 'package:app/models/message.dart';
import 'package:app/widgets/media_message_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('voice tile is compact and starts playback when tapped', (
    tester,
  ) async {
    final playback = _FakeVoicePlaybackController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MediaMessageTile(
              type: MessageType.voice,
              localPath: 'local-voice.m4a',
              remoteUrl: '/media/voice-1',
              duration: const Duration(seconds: 3),
              fileSizeBytes: 2048,
              voicePlaybackController: playback,
            ),
          ),
        ),
      ),
    );

    final box = tester.widget<ConstrainedBox>(
      find.descendant(
        of: find.byKey(const Key('media-message-tile')),
        matching: find.byType(ConstrainedBox),
      ),
    );
    expect(box.constraints.maxWidth, lessThanOrEqualTo(220));

    await tester.tap(find.byKey(const Key('voice-message-play-button')));
    await tester.pump();

    expect(playback.localPath, 'local-voice.m4a');
    expect(playback.remoteUrl, '/media/voice-1');
  });
}

class _FakeVoicePlaybackController implements VoicePlaybackController {
  String? localPath;
  String? remoteUrl;

  @override
  Future<bool> play({String? localPath, String? remoteUrl}) async {
    this.localPath = localPath;
    this.remoteUrl = remoteUrl;
    return true;
  }

  @override
  void dispose() {}
}

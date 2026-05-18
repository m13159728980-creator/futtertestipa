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

  testWidgets('image tile previews media and opens a viewer on tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MediaMessageTile(
              type: MessageType.image,
              remoteUrl: '/media/photo-1',
              title: 'photo.png',
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('media-image-preview')), findsOneWidget);

    await tester.tap(find.byKey(const Key('media-message-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('media-image-viewer')), findsOneWidget);
  });

  testWidgets('file tile opens through the system media opener', (
    tester,
  ) async {
    final opener = _FakeMediaOpenController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MediaMessageTile(
              type: MessageType.file,
              localPath: '/local/doc.pdf',
              remoteUrl: '/media/doc-1',
              title: 'doc.pdf',
              fileSizeBytes: 4096,
              mediaOpenController: opener,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('media-message-tile')));
    await tester.pump();

    expect(opener.openedLocalPath, '/local/doc.pdf');
    expect(opener.openedRemoteUrl, '/media/doc-1');
    expect(opener.openedTitle, 'doc.pdf');
    expect(opener.openedIsVideo, isFalse);
  });

  testWidgets('video tile opens through the system media opener', (
    tester,
  ) async {
    final opener = _FakeMediaOpenController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MediaMessageTile(
              type: MessageType.file,
              isVideo: true,
              remoteUrl: '/media/video-1',
              title: 'video.mp4',
              mediaOpenController: opener,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('media-message-tile')));
    await tester.pump();

    expect(opener.openedRemoteUrl, '/media/video-1');
    expect(opener.openedTitle, 'video.mp4');
    expect(opener.openedIsVideo, isTrue);
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

class _FakeMediaOpenController implements MediaOpenController {
  String? openedLocalPath;
  String? openedRemoteUrl;
  String? openedTitle;
  bool? openedIsVideo;

  @override
  Future<MediaOpenResult> open({
    String? localPath,
    String? remoteUrl,
    String? title,
    required bool isVideo,
  }) async {
    openedLocalPath = localPath;
    openedRemoteUrl = remoteUrl;
    openedTitle = title;
    openedIsVideo = isVideo;
    return const MediaOpenResult(success: true);
  }
}

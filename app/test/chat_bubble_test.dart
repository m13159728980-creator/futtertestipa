import 'package:app/models/message.dart';
import 'package:app/widgets/chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('my messages align right and use green styling', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: _message(fromId: 'me'),
            currentUserId: 'me',
          ),
        ),
      ),
    );

    final align = tester.widget<Align>(
      find.byKey(const Key('chat-bubble-align')),
    );
    expect(align.alignment, Alignment.centerRight);

    final decoration = _bubbleDecoration(tester);
    expect(decoration.color, const Color(0xFFDCF8C6));
  });

  testWidgets('other messages align left and use gray styling', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: _message(fromId: 'alice'),
            currentUserId: 'me',
          ),
        ),
      ),
    );

    final align = tester.widget<Align>(
      find.byKey(const Key('chat-bubble-align')),
    );
    expect(align.alignment, Alignment.centerLeft);

    final decoration = _bubbleDecoration(tester);
    expect(decoration.color, const Color(0xFFEDEDED));
  });

  testWidgets('burn messages show timer area', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: _message(
              fromId: 'alice',
              type: MessageType.burn,
              burnAfter: const Duration(seconds: 30),
            ),
            currentUserId: 'me',
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('burn-timer-area')), findsOneWidget);
    expect(find.text('30s'), findsOneWidget);
  });

  testWidgets('voice messages render a playable voice tile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: _message(
              fromId: 'alice',
              type: MessageType.voice,
              content:
                  '{"url":"/media/voice-1","durationMs":3000,"sizeBytes":2048}',
            ),
            currentUserId: 'me',
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('media-message-tile')), findsOneWidget);
    expect(find.textContaining('0:03'), findsOneWidget);
  });

  testWidgets('image messages render media tile metadata', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: _message(
              fromId: 'alice',
              type: MessageType.image,
              content:
                  '{"kind":"image","url":"/media/photo-1","localPath":"/local/photo.jpg","title":"photo.jpg","sizeBytes":4096}',
            ),
            currentUserId: 'me',
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('media-message-tile')), findsOneWidget);
    expect(find.text('photo.jpg'), findsOneWidget);
    expect(find.textContaining('4.0 KB'), findsOneWidget);
  });

  testWidgets('file messages render media tile metadata', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: _message(
              fromId: 'alice',
              type: MessageType.file,
              content:
                  '{"kind":"file","url":"/media/doc-1","localPath":"/local/doc.pdf","title":"doc.pdf","sizeBytes":8192}',
            ),
            currentUserId: 'me',
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('media-message-tile')), findsOneWidget);
    expect(find.text('doc.pdf'), findsOneWidget);
    expect(find.textContaining('8.0 KB'), findsOneWidget);
  });

  testWidgets('long pressing text message copies content', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: _message(fromId: 'alice', content: 'copy me'),
            currentUserId: 'me',
          ),
        ),
      ),
    );

    await tester.longPress(find.text('copy me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();

    expect(copied, ['copy me']);
    expect(find.text('已复制'), findsOneWidget);
  });

  testWidgets(
    'burn voice messages render a playable voice tile instead of JSON',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: _message(
                fromId: 'alice',
                type: MessageType.burn,
                burnAfter: const Duration(seconds: 10),
                content:
                    '{"kind":"voice","url":"/media/voice-1","durationMs":3000,"sizeBytes":2048}',
              ),
              currentUserId: 'me',
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('media-message-tile')), findsOneWidget);
      expect(find.textContaining('"url"'), findsNothing);
    },
  );

  testWidgets('legacy burn voice URL messages render as voice tiles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: _message(
              fromId: 'alice',
              type: MessageType.burn,
              burnAfter: const Duration(seconds: 10),
              content: '/media/voice-legacy.m4a',
            ),
            currentUserId: 'me',
          ),
        ),
      ),
    );

    expect(find.text('/media/voice-legacy.m4a'), findsNothing);
    expect(find.byKey(const Key('media-message-tile')), findsOneWidget);
    expect(find.byKey(const Key('voice-message-play-button')), findsOneWidget);
  });

  testWidgets('burn JSON text stays text when it is not voice metadata', (
    tester,
  ) async {
    const content = '{"kind":"note","text":"hello"}';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: _message(
              fromId: 'alice',
              type: MessageType.burn,
              burnAfter: const Duration(seconds: 10),
              content: content,
            ),
            currentUserId: 'me',
          ),
        ),
      ),
    );

    expect(find.text(content), findsOneWidget);
    expect(find.byKey(const Key('media-message-tile')), findsNothing);
  });

  testWidgets('message bubbles show the send time under the message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: _message(
              fromId: 'me',
              timestamp: DateTime(2026, 5, 10, 1, 2),
            ),
            currentUserId: 'me',
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('chat-bubble-time')), findsOneWidget);
    expect(find.text('01:02'), findsOneWidget);
  });

  testWidgets('dark theme keeps text readable inside light message bubbles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ChatBubble(
            message: _message(fromId: 'me', content: 'dark readable'),
            currentUserId: 'me',
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('dark readable'));
    expect(text.style?.color, const Color(0xFF10201B));
  });
}

BoxDecoration _bubbleDecoration(WidgetTester tester) {
  final decoratedBox = tester.widget<DecoratedBox>(
    find.byKey(const Key('chat-bubble-decoration')),
  );
  return decoratedBox.decoration as BoxDecoration;
}

Message _message({
  required String fromId,
  MessageType type = MessageType.text,
  Duration? burnAfter,
  String? content,
  DateTime? timestamp,
}) {
  return Message(
    id: 'm1',
    fromId: fromId,
    toId: 'me',
    toType: ConversationType.user,
    type: type,
    content: content ?? 'hello',
    timestamp: timestamp ?? DateTime.utc(2026, 5, 10, 1),
    burnAfter: burnAfter,
    status: MessageStatus.sent,
  );
}

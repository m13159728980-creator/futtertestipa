import 'package:app/models/message.dart';
import 'package:app/widgets/chat_bubble.dart';
import 'package:flutter/material.dart';
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
}) {
  return Message(
    id: 'm1',
    fromId: fromId,
    toId: 'me',
    toType: ConversationType.user,
    type: type,
    content: content ?? 'hello',
    timestamp: DateTime.utc(2026, 5, 10, 1),
    burnAfter: burnAfter,
    status: MessageStatus.sent,
  );
}

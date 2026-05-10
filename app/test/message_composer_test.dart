import 'package:app/widgets/message_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('composer toggles between text input and voice bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageComposer(onSend: (_) {}, onVoiceSend: (_) {}),
        ),
      ),
    );

    expect(find.byKey(const Key('message-input')), findsOneWidget);
    expect(find.byKey(const Key('voice-record-bar')), findsNothing);

    await tester.tap(find.byKey(const Key('composer-mode-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('message-input')), findsNothing);
    expect(find.byKey(const Key('voice-record-bar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('composer-mode-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('message-input')), findsOneWidget);
  });
}

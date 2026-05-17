import 'package:app/widgets/message_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('composer toggles between text input and voice bar', (
    tester,
  ) async {
    Duration? sentDuration;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageComposer(
            onSend: (_) {},
            onVoiceSend: (duration) => sentDuration = duration,
          ),
        ),
      ),
    );

    final toggle = find.byKey(const Key('composer-mode-toggle'));
    expect(
      tester.getTopLeft(toggle).dx,
      lessThan(tester.getTopLeft(find.byKey(const Key('message-input'))).dx),
    );
    expect(find.byKey(const Key('message-input')), findsOneWidget);
    expect(find.byKey(const Key('voice-record-bar')), findsNothing);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('message-input')), findsNothing);
    expect(find.byKey(const Key('voice-record-bar')), findsOneWidget);
    expect(find.byKey(const Key('voice-record-overlay')), findsNothing);
    expect(find.text('按住说话'), findsOneWidget);

    final center = tester.getCenter(find.byKey(const Key('voice-record-bar')));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('松开发送'), findsWidgets);
    expect(find.byKey(const Key('voice-record-overlay')), findsOneWidget);
    final overlayCenter = tester.getCenter(
      find.byKey(const Key('voice-record-overlay')),
    );
    final screenCenter = tester.getCenter(find.byType(Scaffold));
    expect((overlayCenter.dx - screenCenter.dx).abs(), lessThan(2));
    expect((overlayCenter.dy - screenCenter.dy).abs(), lessThan(2));
    expect(find.text('00:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('00:03'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(sentDuration, isNotNull);
    expect(find.byKey(const Key('voice-record-overlay')), findsNothing);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('message-input')), findsOneWidget);
  });

  testWidgets('voice bar auto sends at 60 seconds', (tester) async {
    Duration? sentDuration;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageComposer(
            onSend: (_) {},
            onVoiceSend: (duration) => sentDuration = duration,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('composer-mode-toggle')));
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byKey(const Key('voice-record-bar')));
    await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('松开发送'), findsWidgets);
    await tester.pump(const Duration(seconds: 60));

    expect(sentDuration, const Duration(seconds: 60));
    expect(find.text('按住说话'), findsOneWidget);
    expect(find.byKey(const Key('voice-record-overlay')), findsNothing);
  });
}

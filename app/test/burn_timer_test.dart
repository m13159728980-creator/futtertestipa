import 'package:app/widgets/burn_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('formats supported burn durations as remaining seconds', (
    tester,
  ) async {
    for (final seconds in [5, 10, 30, 60]) {
      await tester.pumpWidget(
        MaterialApp(
          home: BurnTimer(
            duration: Duration(seconds: seconds),
            onExpired: () {},
          ),
        ),
      );

      expect(find.text('${seconds}s'), findsOneWidget);
    }
  });

  testWidgets('counts down to zero and calls expiry callback once', (
    tester,
  ) async {
    var expiryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: BurnTimer(
          duration: const Duration(seconds: 5),
          onExpired: () => expiryCount += 1,
        ),
      ),
    );

    expect(find.text('5s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('4s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('0s'), findsOneWidget);
    expect(expiryCount, 1);

    await tester.pump(const Duration(seconds: 2));
    expect(expiryCount, 1);
  });
}

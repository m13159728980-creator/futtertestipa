import 'package:app/core/constants/avatar_catalog.dart';
import 'package:app/widgets/default_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders selected avatar icon, background, and white foreground', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DefaultAvatar(index: 5),
        ),
      ),
    );

    final circleAvatar = tester.widget<CircleAvatar>(
      find.byType(CircleAvatar),
    );
    final icon = tester.widget<Icon>(find.byType(Icon));

    expect(circleAvatar.backgroundColor, Colors.yellow);
    expect(icon.icon, Icons.sentiment_satisfied);
    expect(icon.color, Colors.white);
  });

  testWidgets('falls back to first avatar for invalid index', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DefaultAvatar(index: 999),
        ),
      ),
    );

    final circleAvatar = tester.widget<CircleAvatar>(
      find.byType(CircleAvatar),
    );
    final icon = tester.widget<Icon>(find.byType(Icon));
    final fallback = avatarCatalog.first;

    expect(circleAvatar.backgroundColor, fallback.color);
    expect(icon.icon, fallback.icon);
    expect(icon.color, Colors.white);
  });
}

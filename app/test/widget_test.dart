import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('shows private chat shell', (WidgetTester tester) async {
    await tester.pumpWidget(const PrivateChatApp());

    expect(find.text('Private Chat'), findsOneWidget);
  });
}

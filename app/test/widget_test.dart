import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('shows private chat shell', (WidgetTester tester) async {
    await tester.pumpWidget(const PrivateChatApp());
    await tester.pumpAndSettle();

    expect(find.text('Private Chat'), findsOneWidget);
  });

  testWidgets('shows Chinese private chat shell labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PrivateChatApp());
    await tester.binding.setLocale('zh', '');
    await tester.pumpAndSettle();

    expect(find.text('聊天'), findsOneWidget);
    expect(find.byTooltip('设置'), findsOneWidget);
    expect(find.text('连接状态'), findsOneWidget);
  });
}

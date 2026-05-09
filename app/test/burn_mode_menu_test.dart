import 'package:app/widgets/burn_mode_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('close item is selectable and reports disabled burn mode', (
    tester,
  ) async {
    Duration? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              appBar: AppBar(
                actions: [
                  BurnModeMenu(
                    selected: selected,
                    onSelected: (duration) {
                      setState(() => selected = duration);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byTooltip('Burn timer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5绉?'));
    await tester.pumpAndSettle();

    expect(selected, const Duration(seconds: 5));
    expect(_burnIcon(tester).color, isNotNull);

    await tester.tap(find.byTooltip('Burn timer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('鍏抽棴'));
    await tester.pumpAndSettle();

    expect(selected, isNull);
    expect(_burnIcon(tester).color, isNull);
  });
}

Icon _burnIcon(WidgetTester tester) {
  return tester.widget<Icon>(find.byIcon(Icons.local_fire_department).last);
}

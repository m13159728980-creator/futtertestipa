import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('English and Chinese ARB files are valid JSON', () {
    for (final path in ['lib/l10n/app_en.arb', 'lib/l10n/app_zh.arb']) {
      final decoded = jsonDecode(File(path).readAsStringSync());

      expect(decoded, isA<Map<String, dynamic>>());
    }
  });

  test('Chinese ARB file contains readable localized labels', () {
    final decoded =
        jsonDecode(File('lib/l10n/app_zh.arb').readAsStringSync())
            as Map<String, dynamic>;

    expect(decoded['chat'], '聊天');
    expect(decoded['settings'], '设置');
    expect(decoded['connectionStatus'], '连接状态');
  });
}

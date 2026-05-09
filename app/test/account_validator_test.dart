import 'package:app/core/utils/account_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountValidator', () {
    test('accepts valid @ZCMX', () {
      expect(AccountValidator.validateAccount('@ZCMX'), isNull);
    });

    test('rejects missing @ prefix with exact Chinese message', () {
      expect(AccountValidator.validateAccount('ZCMX'), '账号必须是英文，且以@开头');
    });

    test('rejects account with digits with same message', () {
      expect(AccountValidator.validateAccount('@ZCMX1'), '账号必须是英文，且以@开头');
    });

    test('rejects blank display name with exact Chinese message', () {
      expect(AccountValidator.validateDisplayName('   '), '请输入名字');
    });

    test('rejects display name over 24 runes', () {
      expect(
        AccountValidator.validateDisplayName('一二三四五六七八九十一二三四五六七八九十一二三四五'),
        '名字不能超过24个字符',
      );
    });
  });
}

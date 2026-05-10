import 'package:app/core/utils/account_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountValidator', () {
    test('accepts valid 10 digit user ID', () {
      expect(AccountValidator.validateUserId('1000000001'), isNull);
    });

    test('rejects non 10 digit user ID', () {
      expect(AccountValidator.validateUserId('@ZCMX'), '请输入10位数字ID');
      expect(AccountValidator.validateUserId('123'), '请输入10位数字ID');
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

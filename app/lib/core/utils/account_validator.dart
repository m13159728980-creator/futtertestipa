class AccountValidator {
  static final RegExp _accountRegex = RegExp(r'^@[A-Za-z]{1,9}$');

  static const String accountMessage = '账号必须是英文，且以@开头';
  static const String displayNameRequiredMessage = '请输入名字';
  static const String displayNameMaxLengthMessage = '名字不能超过24个字符';

  static String? validateAccount(String account) {
    if (!_accountRegex.hasMatch(account)) {
      return accountMessage;
    }

    return null;
  }

  static String? validateDisplayName(String displayName) {
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      return displayNameRequiredMessage;
    }
    if (trimmedName.runes.length > 24) {
      return displayNameMaxLengthMessage;
    }

    return null;
  }
}

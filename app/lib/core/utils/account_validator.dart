class AccountValidator {
  static final RegExp _userIdRegex = RegExp(r'^\d{10}$');

  static const String accountMessage = '请输入10位数字ID';
  static const String displayNameRequiredMessage = '请输入名字';
  static const String displayNameMaxLengthMessage = '名字不能超过24个字符';

  static String? validateAccount(String account) {
    return validateUserId(account);
  }

  static String? validateUserId(String id) {
    return _userIdRegex.hasMatch(id) ? null : accountMessage;
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

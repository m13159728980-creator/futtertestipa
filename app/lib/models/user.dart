import 'dart:convert';

class User {
  const User({
    required this.id,
    required this.displayName,
    required this.account,
    required this.token,
    this.avatarIndex = 0,
  });

  final String id;
  final String displayName;
  final String account;
  final String token;
  final int avatarIndex;

  factory User.fromJson(Map<String, dynamic> json, {String? token}) {
    return User(
      id: json['id'].toString(),
      displayName: json['displayName'] as String? ?? '',
      account: json['account'] as String? ?? '',
      token: token ?? json['token'] as String? ?? '',
      avatarIndex: json['avatarIndex'] as int? ?? 0,
    );
  }

  factory User.fromStorageJson(String source) {
    return User.fromJson(jsonDecode(source) as Map<String, dynamic>);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'account': account,
      'token': token,
      'avatarIndex': avatarIndex,
    };
  }

  String toStorageJson() {
    return jsonEncode(toJson());
  }

  User copyWith({String? displayName, String? token, int? avatarIndex}) {
    return User(
      id: id,
      displayName: displayName ?? this.displayName,
      account: account,
      token: token ?? this.token,
      avatarIndex: avatarIndex ?? this.avatarIndex,
    );
  }
}

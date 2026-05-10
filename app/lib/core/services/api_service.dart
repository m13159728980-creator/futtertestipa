import 'dart:convert';

import 'package:app/core/config/app_config.dart';
import 'package:app/models/group.dart';
import 'package:app/models/message.dart';
import 'package:app/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final apiServiceProvider = Provider<ApiService>((ref) {
  return HttpApiService();
});

abstract interface class ApiService {
  Future<User> register({required String displayName});

  Future<User> validate(String token);

  Future<bool> checkAccount(String account);

  Future<void> deleteAccount({
    required String token,
    required String accountConfirmation,
  });

  Future<List<User>> listContacts({required String token});

  Future<User> addContact({required String token, required String account});

  Future<Group> createGroup({
    required String token,
    required String name,
    required List<String> memberIds,
  });

  Future<Group> getGroup({required String token, required String groupId});

  Future<Group> renameGroup({
    required String token,
    required String groupId,
    required String name,
  });

  Future<Group> addGroupMembers({
    required String token,
    required String groupId,
    required List<String> memberIds,
  });

  Future<User> updateProfile({
    required String token,
    required String displayName,
  });

  Future<User> updateAvatar({required String token, required int avatarIndex});

  Future<List<Message>> syncMessages({required String token});

  Future<void> registerPushToken({
    required String token,
    required String pushToken,
    String platform = 'android',
  });
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _fallbackErrorMessage = '请求失败，请稍后重试';

class HttpApiService implements ApiService {
  HttpApiService({http.Client? client, String baseUrl = AppConfig.apiBaseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<User> register({required String displayName}) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: _jsonHeaders(),
      body: jsonEncode({'displayName': displayName}),
    );
    final body = _decode(response);
    if (response.statusCode != 201) {
      throw ApiException(_message(body));
    }

    return User.fromJson(
      body['user'] as Map<String, dynamic>,
      token: body['token'] as String? ?? '',
    );
  }

  @override
  Future<User> validate(String token) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/validate'),
      headers: _jsonHeaders(token: token),
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(_message(body));
    }

    return User.fromJson(body['user'] as Map<String, dynamic>, token: token);
  }

  @override
  Future<bool> checkAccount(String account) async {
    final uri = Uri.parse(
      '$_baseUrl/users/check-account',
    ).replace(queryParameters: {'account': account});
    final response = await _client.get(uri, headers: _jsonHeaders());
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(_message(body));
    }

    return body['available'] == true;
  }

  @override
  Future<void> deleteAccount({
    required String token,
    required String accountConfirmation,
  }) async {
    final request = http.Request('DELETE', Uri.parse('$_baseUrl/users/me'))
      ..headers.addAll(_jsonHeaders(token: token))
      ..body = jsonEncode({'account': accountConfirmation});
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode != 204) {
      throw ApiException(_message(_decode(response)));
    }
  }

  @override
  Future<List<User>> listContacts({required String token}) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/contacts'),
      headers: _jsonHeaders(token: token),
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(_message(body));
    }
    return [
      for (final item in (body['contacts'] as List? ?? const []))
        if (item is Map<String, dynamic>) User.fromJson(item, token: token),
    ];
  }

  @override
  Future<User> addContact({
    required String token,
    required String account,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/contacts'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode({'id': account.trim()}),
    );
    final body = _decode(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(_message(body));
    }
    return User.fromJson(body['contact'] as Map<String, dynamic>, token: token);
  }

  @override
  Future<Group> createGroup({
    required String token,
    required String name,
    required List<String> memberIds,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/groups'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode({
        'name': name.trim(),
        'memberIds': memberIds.map(int.parse).toList(),
      }),
    );
    final body = _decode(response);
    if (response.statusCode != 201) {
      throw ApiException(_message(body));
    }
    return Group.fromJson(body['group'] as Map<String, dynamic>);
  }

  @override
  Future<Group> getGroup({
    required String token,
    required String groupId,
  }) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/groups/$groupId'),
      headers: _jsonHeaders(token: token),
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(_message(body));
    }
    return Group.fromJson(body['group'] as Map<String, dynamic>);
  }

  @override
  Future<Group> renameGroup({
    required String token,
    required String groupId,
    required String name,
  }) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/groups/$groupId'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode({'name': name.trim()}),
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(_message(body));
    }
    return Group.fromJson(body['group'] as Map<String, dynamic>);
  }

  @override
  Future<Group> addGroupMembers({
    required String token,
    required String groupId,
    required List<String> memberIds,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/groups/$groupId/members'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode({'memberIds': memberIds.map(int.parse).toList()}),
    );
    final body = _decode(response);
    if (response.statusCode != 201) {
      throw ApiException(_message(body));
    }
    return Group.fromJson(body['group'] as Map<String, dynamic>);
  }

  @override
  Future<User> updateProfile({
    required String token,
    required String displayName,
  }) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/users/me/profile'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode({'displayName': displayName.trim()}),
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(_message(body));
    }
    return User.fromJson(body['user'] as Map<String, dynamic>, token: token);
  }

  @override
  Future<User> updateAvatar({
    required String token,
    required int avatarIndex,
  }) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/users/me/avatar'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode({'avatarIndex': avatarIndex}),
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(_message(body));
    }
    return User.fromJson(body['user'] as Map<String, dynamic>, token: token);
  }

  @override
  Future<List<Message>> syncMessages({required String token}) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/messages/sync'),
      headers: _jsonHeaders(token: token),
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(_message(body));
    }
    return [
      for (final item in (body['messages'] as List? ?? const []))
        if (item is Map<String, dynamic>) Message.fromJson(item),
    ];
  }

  @override
  Future<void> registerPushToken({
    required String token,
    required String pushToken,
    String platform = 'android',
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/users/me/push-token'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode({'token': pushToken, 'platform': platform}),
    );
    final body = _decode(response);
    if (response.statusCode != 204) {
      throw ApiException(_message(body));
    }
  }

  Map<String, String> _jsonHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      throw const ApiException(_fallbackErrorMessage);
    }
    throw const ApiException(_fallbackErrorMessage);
  }

  String _message(Map<String, dynamic> body) {
    final message = body['message'];
    return message is String ? message : _fallbackErrorMessage;
  }
}

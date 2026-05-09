import 'dart:convert';

import 'package:app/core/config/app_config.dart';
import 'package:app/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final apiServiceProvider = Provider<ApiService>((ref) {
  return HttpApiService();
});

abstract interface class ApiService {
  Future<User> register({required String displayName, required String account});

  Future<User> validate(String token);

  Future<bool> checkAccount(String account);

  Future<void> deleteAccount({
    required String token,
    required String accountConfirmation,
  });
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _fallbackErrorMessage = '璇锋眰澶辫触锛岃绋嶅悗閲嶈瘯';

class HttpApiService implements ApiService {
  HttpApiService({http.Client? client, String baseUrl = AppConfig.apiBaseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<User> register({
    required String displayName,
    required String account,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: _jsonHeaders(),
      body: jsonEncode({'displayName': displayName, 'account': account}),
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

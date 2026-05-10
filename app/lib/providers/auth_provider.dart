import 'package:app/core/services/api_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/models/user.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authProvider = ChangeNotifierProvider<AuthProvider>((ref) {
  return AuthProvider(
    apiService: ref.watch(apiServiceProvider),
    storageService: ref.watch(secureStorageServiceProvider),
  )..initialize();
});

enum AuthStatus { loading, unauthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required ApiService apiService,
    required SecureStorageService storageService,
  }) : _apiService = apiService,
       _storageService = storageService;

  final ApiService _apiService;
  final SecureStorageService _storageService;

  AuthStatus _status = AuthStatus.loading;
  User? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    final token = await _storageService.readToken();
    final cachedUser = await _storageService.readUser();
    if (token == null || cachedUser == null) {
      _setUnauthenticated();
      return;
    }

    try {
      final validatedUser = await _apiService.validate(token);
      _user = validatedUser;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      await _storageService.saveSession(validatedUser);
      notifyListeners();
    } catch (_) {
      await _storageService.clearAllLocalSecrets();
      _setUnauthenticated();
    }
  }

  Future<void> register({required String displayName}) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final registeredUser = await _apiService.register(displayName: displayName);
      await _storageService.saveSession(registeredUser);
      await _storageService.ensureMasterKey();
      _user = registeredUser;
      _status = AuthStatus.authenticated;
      notifyListeners();
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      rethrow;
    } catch (_) {
      _errorMessage = '注册失败，请稍后重试';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logoutLocal() async {
    await _storageService.clearAllLocalSecrets();
    _setUnauthenticated();
  }

  Future<void> deleteAccount(String accountConfirmation) async {
    final currentUser = _user;
    if (currentUser == null) {
      return;
    }

    await _apiService.deleteAccount(
      token: currentUser.token,
      accountConfirmation: accountConfirmation,
    );
    await logoutLocal();
  }

  void _setUnauthenticated() {
    _user = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }
}

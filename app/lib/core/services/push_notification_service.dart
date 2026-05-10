import 'package:app/core/services/api_service.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService(
    apiService: ref.watch(apiServiceProvider),
    auth: ref.watch(authProvider),
  );
});

class PushNotificationService {
  const PushNotificationService({
    required ApiService apiService,
    required AuthProvider auth,
  }) : _apiService = apiService,
       _auth = auth;

  final ApiService _apiService;
  final AuthProvider _auth;

  Future<void> initialize() async {
    final user = _auth.user;
    if (user == null || user.token.isEmpty) {
      return;
    }
    try {
      final token = const String.fromEnvironment('FCM_TOKEN');
      if (token.isEmpty) {
        return;
      }
      await _apiService.registerPushToken(
        token: user.token,
        pushToken: token,
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'push_notification_service',
          context: ErrorDescription(
            'while registering push notification token',
          ),
        ),
      );
    }
  }
}

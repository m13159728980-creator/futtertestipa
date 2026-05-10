import 'package:app/core/services/api_service.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:getuiflut/getuiflut.dart';

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
      final getui = Getuiflut();
      getui.addEventHandler(
        onReceiveClientId: (clientId) async {
          await _registerClientId(clientId);
        },
        onNotificationMessageArrived: (_) async {},
        onNotificationMessageClicked: (_) async {},
        onTransmitUserMessageReceive: (_) async {},
        onReceiveOnlineState: (_) async {},
        onRegisterDeviceToken: (_) async {},
        onReceivePayload: (_) async {},
        onReceiveNotificationResponse: (_) async {},
        onAppLinkPayload: (_) async {},
        onPushModeResult: (_) async {},
        onSetTagResult: (_) async {},
        onAliasResult: (_) async {},
        onQueryTagResult: (_) async {},
        onWillPresentNotification: (_) async {},
        onOpenSettingsForNotification: (_) async {},
        onGrantAuthorization: (_) async {},
        onLiveActivityResult: (_) async {},
        onRegisterPushToStartTokenResult: (_) async {},
      );
      getui.initGetuiSdk;
      getui.turnOnPush();
      getui.bindAlias(user.id, 'bind-${user.id}');
      final clientId = await getui.getClientId;
      await _registerClientId(clientId);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'push_notification_service',
          context: ErrorDescription(
            'while initializing Getui push notifications',
          ),
        ),
      );
    }
  }

  Future<void> _registerClientId(String clientId) async {
    final user = _auth.user;
    final normalized = clientId.trim();
    if (user == null || user.token.isEmpty || normalized.isEmpty) {
      return;
    }
    try {
      await _apiService.registerPushToken(
        token: user.token,
        pushToken: normalized,
        platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'getui',
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'push_notification_service',
          context: ErrorDescription(
            'while registering Getui client id',
          ),
        ),
      );
    }
  }
}

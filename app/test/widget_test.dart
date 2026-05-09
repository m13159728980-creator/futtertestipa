import 'package:app/core/services/api_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/main.dart';
import 'package:app/models/user.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows create account shell', (WidgetTester tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('欢迎'), findsOneWidget);
  });

  testWidgets('keeps Chinese locale available', (WidgetTester tester) async {
    await tester.pumpWidget(_testApp());
    await tester.binding.setLocale('zh', '');
    await tester.pumpAndSettle();

    expect(find.text('欢迎'), findsOneWidget);
  });
}

Widget _testApp() {
  return ProviderScope(
    overrides: [
      secureStorageServiceProvider.overrideWithValue(InMemorySecureStorage()),
      apiServiceProvider.overrideWithValue(_OfflineApiService()),
    ],
    child: const PrivateChatApp(),
  );
}

class _OfflineApiService implements ApiService {
  @override
  Future<bool> checkAccount(String account) async => true;

  @override
  Future<void> deleteAccount({
    required String token,
    required String accountConfirmation,
  }) async {}

  @override
  Future<User> register({
    required String displayName,
    required String account,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<User> validate(String token) {
    throw UnimplementedError();
  }
}

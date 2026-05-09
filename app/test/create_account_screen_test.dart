import 'package:app/core/services/api_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/models/user.dart';
import 'package:app/screens/create_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('blank name shows exactly 请输入名字', (tester) async {
    await tester.pumpWidget(_testApp());

    await tester.tap(find.text('开始聊天'));
    await tester.pump();

    expect(find.text('请输入名字'), findsOneWidget);
  });

  testWidgets('invalid account shows exactly 账号必须是英文，且以@开头', (tester) async {
    await tester.pumpWidget(_testApp());

    await tester.enterText(find.widgetWithText(TextFormField, '名字'), '小明');
    await tester.enterText(
      find.widgetWithText(TextFormField, '账号'),
      'xiaoming',
    );
    await tester.pump();

    expect(find.text('账号必须是英文，且以@开头'), findsOneWidget);
  });

  testWidgets('valid form enables 开始聊天 button', (tester) async {
    await tester.pumpWidget(_testApp());

    await tester.enterText(find.widgetWithText(TextFormField, '名字'), '小明');
    await tester.enterText(
      find.widgetWithText(TextFormField, '账号'),
      '@XiaoMing',
    );
    await tester.pump();

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '开始聊天'),
    );
    expect(button.onPressed, isNotNull);
  });
}

Widget _testApp() {
  final api = _FakeApiService();
  final storage = InMemorySecureStorage();

  return ProviderScope(
    overrides: [
      apiServiceProvider.overrideWithValue(api),
      secureStorageServiceProvider.overrideWithValue(storage),
    ],
    child: const MaterialApp(home: CreateAccountScreen()),
  );
}

class _FakeApiService implements ApiService {
  @override
  Future<User> register({
    required String displayName,
    required String account,
  }) async {
    return User(
      id: 'user-1',
      displayName: displayName,
      account: account,
      token: 'token-1',
    );
  }

  @override
  Future<User> validate(String token) async {
    return const User(
      id: 'user-1',
      displayName: '小明',
      account: '@XiaoMing',
      token: 'token-1',
    );
  }

  @override
  Future<bool> checkAccount(String account) async => true;

  @override
  Future<void> deleteAccount({
    required String token,
    required String accountConfirmation,
  }) async {}
}

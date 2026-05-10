import 'package:app/core/services/api_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/models/user.dart';
import 'package:app/models/group.dart';
import 'package:app/models/message.dart';
import 'package:app/screens/create_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('blank name disables submit button', (tester) async {
    await tester.pumpWidget(_testApp());

    expect(_submitButton(tester).onPressed, isNull);
  });

  testWidgets('create account screen has no username field', (tester) async {
    await tester.pumpWidget(_testApp());

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '名字'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '账号'), findsNothing);
    expect(find.widgetWithText(TextFormField, '用户名'), findsNothing);
  });

  testWidgets('valid name enables start button', (tester) async {
    await tester.pumpWidget(_testApp());

    await tester.enterText(find.widgetWithText(TextFormField, '名字'), '小明');
    await tester.pump();

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '开始聊天'),
    );
    expect(button.onPressed, isNotNull);
  });
}

ElevatedButton _submitButton(WidgetTester tester) {
  return tester.widget<ElevatedButton>(find.byType(ElevatedButton));
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
  Future<User> register({required String displayName}) async {
    return User(
      id: '1',
      displayName: displayName,
      account: '1000000001',
      token: 'token-1',
    );
  }

  @override
  Future<User> validate(String token) async {
    return const User(
      id: '1',
      displayName: '小明',
      account: '1000000001',
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

  @override
  Future<List<User>> listContacts({required String token}) async => const [];

  @override
  Future<User> addContact({required String token, required String account}) {
    throw UnimplementedError();
  }

  @override
  Future<Group> createGroup({
    required String token,
    required String name,
    required List<String> memberIds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Group> getGroup({required String token, required String groupId}) {
    throw UnimplementedError();
  }

  @override
  Future<Group> renameGroup({
    required String token,
    required String groupId,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Group> addGroupMembers({
    required String token,
    required String groupId,
    required List<String> memberIds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<User> updateProfile({
    required String token,
    required String displayName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<User> updateAvatar({required String token, required int avatarIndex}) {
    throw UnimplementedError();
  }

  @override
  Future<List<Message>> syncMessages({required String token}) async => const [];

  @override
  Future<void> registerPushToken({
    required String token,
    required String pushToken,
    String platform = 'android',
  }) async {}
}

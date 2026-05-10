import 'package:app/core/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('HttpApiService', () {
    test(
      'uses fallback ApiException message for non-JSON error bodies',
      () async {
        final service = HttpApiService(
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            return http.Response('service unavailable', 503);
          }),
        );

        await expectLater(
          service.checkAccount('@XiaoMing'),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              '请求失败，请稍后重试',
            ),
          ),
        );
      },
    );

    test(
      'uses fallback ApiException message for non-object JSON bodies',
      () async {
        final service = HttpApiService(
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            return http.Response('["invalid"]', 400);
          }),
        );

        await expectLater(
          service.checkAccount('@XiaoMing'),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              '请求失败，请稍后重试',
            ),
          ),
        );
      },
    );

    test(
      'uses fallback ApiException message when message is not a string',
      () async {
        final service = HttpApiService(
          baseUrl: 'https://example.test',
          client: MockClient((request) async {
            return http.Response('{"message":404}', 400);
          }),
        );

        await expectLater(
          service.checkAccount('@XiaoMing'),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              '请求失败，请稍后重试',
            ),
          ),
        );
      },
    );

    test('adds a contact by 10 digit ID', () async {
      late http.Request captured;
      final service = HttpApiService(
        baseUrl: 'https://example.test/api',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            '{"contact":{"id":2,"account":"2222222222","displayName":"Bob","avatarIndex":1}}',
            201,
          );
        }),
      );

      final contact = await service.addContact(
        token: 'token-1',
        account: '2222222222',
      );

      expect(captured.method, 'POST');
      expect(captured.url.toString(), 'https://example.test/api/contacts');
      expect(captured.headers['Authorization'], 'Bearer token-1');
      expect(captured.body, '{"id":"2222222222"}');
      expect(contact.account, '2222222222');
      expect(contact.displayName, 'Bob');
    });

    test('creates a group with selected member IDs', () async {
      late http.Request captured;
      final service = HttpApiService(
        baseUrl: 'https://example.test/api',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            '{"group":{"id":7,"groupCode":"12345678","name":"Team","ownerId":1,"burnEnabled":false,"members":[]}}',
            201,
          );
        }),
      );

      final group = await service.createGroup(
        token: 'token-1',
        name: 'Team',
        memberIds: const ['2', '3'],
      );

      expect(captured.method, 'POST');
      expect(captured.url.toString(), 'https://example.test/api/groups');
      expect(captured.body, '{"name":"Team","memberIds":[2,3]}');
      expect(group.id, '7');
      expect(group.name, 'Team');
    });

    test('updates current user profile display name', () async {
      late http.Request captured;
      final service = HttpApiService(
        baseUrl: 'https://example.test/api',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            '{"user":{"id":1,"account":"1000000001","displayName":"New Name","avatarIndex":0}}',
            200,
          );
        }),
      );

      final user = await service.updateProfile(
        token: 'token-1',
        displayName: 'New Name',
      );

      expect(captured.method, 'PATCH');
      expect(
        captured.url.toString(),
        'https://example.test/api/users/me/profile',
      );
      expect(captured.body, '{"displayName":"New Name"}');
      expect(user.displayName, 'New Name');
      expect(user.token, 'token-1');
    });

    test('updates current user avatar index', () async {
      late http.Request captured;
      final service = HttpApiService(
        baseUrl: 'https://example.test/api',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            '{"user":{"id":1,"account":"1000000001","displayName":"Me","avatarIndex":5}}',
            200,
          );
        }),
      );

      final user = await service.updateAvatar(token: 'token-1', avatarIndex: 5);

      expect(captured.method, 'PATCH');
      expect(
        captured.url.toString(),
        'https://example.test/api/users/me/avatar',
      );
      expect(captured.body, '{"avatarIndex":5}');
      expect(user.avatarIndex, 5);
      expect(user.token, 'token-1');
    });

    test('syncs messages and maps backend payloads', () async {
      final service = HttpApiService(
        baseUrl: 'https://example.test/api',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://example.test/api/messages/sync',
          );
          expect(request.headers['Authorization'], 'Bearer token-1');
          return http.Response(
            '{"messages":[{"id":"11111111-1111-4111-8111-111111111111","fromId":2,"toId":1,"toType":"user","type":"text","content":"hello","timestamp":"2026-05-10T00:00:00.000Z","burnAfter":0,"status":"sent"}]}',
            200,
          );
        }),
      );

      final messages = await service.syncMessages(token: 'token-1');

      expect(messages.single.id, '11111111-1111-4111-8111-111111111111');
      expect(messages.single.content, 'hello');
    });

    test('registers a push token for Android notifications', () async {
      late http.Request captured;
      final service = HttpApiService(
        baseUrl: 'https://example.test/api',
        client: MockClient((request) async {
          captured = request;
          return http.Response('', 204);
        }),
      );

      await service.registerPushToken(
        token: 'token-1',
        pushToken: 'fcm-token-1',
        platform: 'android',
      );

      expect(captured.method, 'POST');
      expect(
        captured.url.toString(),
        'https://example.test/api/users/me/push-token',
      );
      expect(captured.headers['Authorization'], 'Bearer token-1');
      expect(captured.body, '{"token":"fcm-token-1","platform":"android"}');
    });
  });
}

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
  });
}

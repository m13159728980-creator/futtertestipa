import 'package:app/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses unix timestamp seconds as the expected date', () {
    final message = Message.fromJson(_json(timestamp: 1700000000));

    expect(message.timestamp, DateTime.utc(2023, 11, 14, 22, 13, 20));
  });

  test('parses unix timestamp milliseconds as the expected date', () {
    final message = Message.fromJson(_json(timestamp: 1700000000000));

    expect(message.timestamp, DateTime.utc(2023, 11, 14, 22, 13, 20));
  });

  test('uses safe enum defaults for unknown values', () {
    final message = Message.fromJson(
      _json(toType: 'invalid-to-type', type: 'invalid-type', status: 'bad'),
    );

    expect(message.toType, ConversationType.user);
    expect(message.type, MessageType.text);
    expect(message.status, MessageStatus.sent);
  });

  test('safely converts non-string content values', () {
    final message = Message.fromJson(
      _json(content: 123, encryptedContent: {'cipher': 'abc'}),
    );

    expect(message.content, '123');
    expect(message.encryptedContent, '{cipher: abc}');
  });
}

Map<String, dynamic> _json({
  Object? timestamp = '2026-05-10T01:00:00Z',
  Object? toType = 'user',
  Object? type = 'text',
  Object? status = 'sent',
  Object? content = 'hello',
  Object? encryptedContent,
}) {
  return {
    'id': 'm1',
    'fromId': 'alice',
    'toId': 'bob',
    'toType': toType,
    'type': type,
    'content': content,
    'encryptedContent': encryptedContent,
    'timestamp': timestamp,
    'status': status,
  };
}

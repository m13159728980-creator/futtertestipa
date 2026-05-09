enum ConversationType {
  user,
  group;

  static ConversationType fromJson(Object? value) {
    return _enumByNameOrNull(ConversationType.values, value) ??
        ConversationType.user;
  }
}

enum MessageType {
  text,
  image,
  voice,
  file,
  burn;

  static MessageType fromJson(Object? value) {
    return _enumByNameOrNull(MessageType.values, value) ?? MessageType.text;
  }
}

enum MessageStatus {
  sent,
  delivered,
  read,
  burned,
  revoked;

  static MessageStatus fromJson(Object? value) {
    return _enumByNameOrNull(MessageStatus.values, value) ?? MessageStatus.sent;
  }
}

class Message {
  const Message({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.toType,
    required this.type,
    required this.timestamp,
    required this.status,
    this.content,
    this.encryptedContent,
    this.burnAfter,
  });

  final String id;
  final String fromId;
  final String toId;
  final ConversationType toType;
  final MessageType type;
  final String? content;
  final String? encryptedContent;
  final DateTime timestamp;
  final Duration? burnAfter;
  final MessageStatus status;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'].toString(),
      fromId: (json['fromId'] ?? json['from_id']).toString(),
      toId: (json['toId'] ?? json['to_id']).toString(),
      toType: ConversationType.fromJson(json['toType'] ?? json['to_type']),
      type: MessageType.fromJson(json['type']),
      content: _stringOrNull(json['content']),
      encryptedContent: _stringOrNull(
        json['encryptedContent'] ?? json['encrypted_content'],
      ),
      timestamp: _parseTimestamp(json['timestamp']),
      burnAfter: _parseBurnAfter(json['burnAfter'] ?? json['burn_after']),
      status: MessageStatus.fromJson(json['status']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromId': fromId,
      'toId': toId,
      'toType': toType.name,
      'type': type.name,
      'content': content,
      'encryptedContent': encryptedContent,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'burnAfter': burnAfter?.inSeconds,
      'status': status.name,
    };
  }

  Message copyWith({
    String? content,
    String? encryptedContent,
    MessageStatus? status,
  }) {
    return Message(
      id: id,
      fromId: fromId,
      toId: toId,
      toType: toType,
      type: type,
      content: content ?? this.content,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      timestamp: timestamp,
      burnAfter: burnAfter,
      status: status ?? this.status,
    );
  }
}

DateTime _parseTimestamp(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is int) {
    final milliseconds = value < 1000000000000 ? value * 1000 : value;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }
  return DateTime.parse(value.toString()).toUtc();
}

String? _stringOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  return value.toString();
}

T? _enumByNameOrNull<T extends Enum>(List<T> values, Object? value) {
  final name = value?.toString();
  for (final enumValue in values) {
    if (enumValue.name == name) {
      return enumValue;
    }
  }
  return null;
}

Duration? _parseBurnAfter(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Duration) {
    return value;
  }
  if (value is int) {
    return Duration(seconds: value);
  }
  return Duration(seconds: int.parse(value.toString()));
}

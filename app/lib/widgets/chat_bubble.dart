import 'dart:convert';

import 'package:app/models/message.dart';
import 'package:app/widgets/burn_timer.dart';
import 'package:app/widgets/media_message_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    required this.message,
    required this.currentUserId,
    this.senderName,
    this.onBurnExpired,
    super.key,
  });

  static const mineColor = Color(0xFFDCF8C6);
  static const otherColor = Color(0xFFEDEDED);
  static const bubbleTextColor = Color(0xFF10201B);
  static const bubbleSecondaryTextColor = Color(0x990F1F1A);
  static const bubbleTertiaryTextColor = Color(0x730F1F1A);

  final Message message;
  final String currentUserId;
  final String? senderName;
  final ValueChanged<String>? onBurnExpired;

  @override
  Widget build(BuildContext context) {
    final isMine = message.fromId == currentUserId;
    final isBurned = message.status == MessageStatus.burned;
    final content = message.status == MessageStatus.revoked
        ? 'Message revoked'
        : isBurned
        ? 'Message burned'
        : message.content ?? '';
    final voicePayload = !isBurned
        ? _mediaPayload(message.content, type: message.type)
        : null;
    final copyText = _copyableText(message);

    return Align(
      key: const Key('chat-bubble-align'),
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: GestureDetector(
          onLongPressStart: copyText == null
              ? null
              : (details) =>
                    _showMessageMenu(context, details.globalPosition, copyText),
          child: DecoratedBox(
            key: const Key('chat-bubble-decoration'),
            decoration: BoxDecoration(
              color: isMine ? mineColor : otherColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isMine ? 14 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 14),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMine && senderName != null) ...[
                    Text(
                      senderName!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: bubbleSecondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    child: voicePayload == null
                        ? Text(
                            content,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: bubbleTextColor),
                          )
                        : MediaMessageTile(
                            type: voicePayload.type,
                            localPath: voicePayload.localPath,
                            remoteUrl: voicePayload.url,
                            title: voicePayload.title,
                            fileSizeBytes: voicePayload.sizeBytes,
                            duration: voicePayload.duration,
                          ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: message.type == MessageType.burn && !isBurned
                            ? _BurnTimerArea(
                                key: ValueKey('burn-timer-${message.id}'),
                                message: message,
                                onExpired: onBurnExpired,
                              )
                            : const SizedBox.shrink(),
                      ),
                      Text(
                        _messageTimeLabel(message.timestamp),
                        key: const Key('chat-bubble-time'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: bubbleTertiaryTextColor,
                          fontSize: 11,
                        ),
                      ),
                      if (isMine) const SizedBox(width: 3),
                      _MessageStatusIcon(
                        status: message.status,
                        visible: isMine,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMessageMenu(
    BuildContext context,
    Offset position,
    String copyText,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<_MessageMenuAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: _MessageMenuAction.copy, child: Text('复制')),
      ],
    );
    if (selected != _MessageMenuAction.copy || !context.mounted) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: copyText));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制')));
  }
}

enum _MessageMenuAction { copy }

String _messageTimeLabel(DateTime timestamp) {
  final local = timestamp.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

_MediaBubblePayload? _mediaPayload(
  String? content, {
  required MessageType type,
}) {
  if (content == null || content.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final kind = decoded['kind']?.toString();
    final payloadType = _mediaTypeFromKind(kind) ?? type;
    if (!_isMediaMessageType(payloadType) &&
        !(type == MessageType.burn && _isMediaKind(kind))) {
      return null;
    }
    return _MediaBubblePayload(
      type: payloadType,
      url: decoded['url']?.toString(),
      localPath: decoded['localPath']?.toString(),
      title: decoded['title']?.toString(),
      sizeBytes: decoded['sizeBytes'] is int
          ? decoded['sizeBytes'] as int
          : int.tryParse(decoded['sizeBytes']?.toString() ?? ''),
      duration: Duration(
        milliseconds: decoded['durationMs'] is int
            ? decoded['durationMs'] as int
            : int.tryParse(decoded['durationMs']?.toString() ?? '') ?? 0,
      ),
    );
  } catch (_) {
    if ((type == MessageType.voice || type == MessageType.burn) &&
        _looksLikeVoiceUrl(content)) {
      return _MediaBubblePayload(
        type: MessageType.voice,
        url: content,
        localPath: null,
        title: null,
        sizeBytes: null,
        duration: Duration.zero,
      );
    }
    return null;
  }
}

String? _copyableText(Message message) {
  if (message.status == MessageStatus.burned ||
      message.status == MessageStatus.revoked) {
    return null;
  }
  if (message.type == MessageType.text ||
      (message.type == MessageType.burn &&
          _mediaPayload(message.content, type: message.type) == null)) {
    final content = message.content?.trim();
    return content == null || content.isEmpty ? null : content;
  }
  return null;
}

MessageType? _mediaTypeFromKind(String? kind) {
  return switch (kind) {
    'image' => MessageType.image,
    'voice' => MessageType.voice,
    'file' || 'video' => MessageType.file,
    _ => null,
  };
}

bool _isMediaKind(String? kind) {
  return kind == 'image' ||
      kind == 'voice' ||
      kind == 'file' ||
      kind == 'video';
}

bool _isMediaMessageType(MessageType type) {
  return type == MessageType.image ||
      type == MessageType.voice ||
      type == MessageType.file;
}

bool _looksLikeVoiceUrl(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty || normalized.contains(RegExp(r'\s'))) {
    return false;
  }
  final isMediaPath =
      normalized.startsWith('/media/') ||
      normalized.startsWith('media/') ||
      normalized.startsWith('http://') ||
      normalized.startsWith('https://');
  final isAudio =
      normalized.endsWith('.m4a') ||
      normalized.endsWith('.aac') ||
      normalized.endsWith('.mp3') ||
      normalized.endsWith('.wav') ||
      normalized.endsWith('.ogg') ||
      normalized.contains('/voice');
  return isMediaPath && isAudio;
}

class _MediaBubblePayload {
  const _MediaBubblePayload({
    required this.type,
    required this.url,
    required this.localPath,
    required this.title,
    required this.sizeBytes,
    required this.duration,
  });

  final MessageType type;
  final String? url;
  final String? localPath;
  final String? title;
  final int? sizeBytes;
  final Duration duration;
}

class _MessageStatusIcon extends StatelessWidget {
  const _MessageStatusIcon({required this.status, required this.visible});

  final MessageStatus status;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    final color = status == MessageStatus.read
        ? const Color(0xFF2AABEE)
        : ChatBubble.bubbleTertiaryTextColor;
    final icon = switch (status) {
      MessageStatus.sent => Icons.check,
      MessageStatus.delivered || MessageStatus.read => Icons.done_all,
      MessageStatus.burned => Icons.local_fire_department,
      MessageStatus.revoked => Icons.block,
    };
    return Icon(icon, size: 16, color: color);
  }
}

class _BurnTimerArea extends StatelessWidget {
  const _BurnTimerArea({
    required this.message,
    required this.onExpired,
    super.key,
  });

  final Message message;
  final ValueChanged<String>? onExpired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('burn-timer-area'),
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, size: 14),
          const SizedBox(width: 2),
          if (message.burnAfter == null)
            Text('--', style: Theme.of(context).textTheme.labelSmall)
          else
            BurnTimer(
              duration: message.burnAfter!,
              onExpired: () => onExpired?.call(message.id),
            ),
        ],
      ),
    );
  }
}

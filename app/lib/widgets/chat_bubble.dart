import 'dart:convert';

import 'package:app/models/message.dart';
import 'package:app/widgets/burn_timer.dart';
import 'package:app/widgets/media_message_tile.dart';
import 'package:flutter/material.dart';

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
    final voicePayload = message.type == MessageType.voice && !isBurned
        ? _voicePayload(message.content)
        : null;

    return Align(
      key: const Key('chat-bubble-align'),
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
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
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: voicePayload == null
                      ? Text(
                          content,
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      : MediaMessageTile(
                          type: MessageType.voice,
                          localPath: voicePayload.localPath,
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
                    _MessageStatusIcon(status: message.status, visible: isMine),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

_VoiceBubblePayload? _voicePayload(String? content) {
  if (content == null || content.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return _VoiceBubblePayload(
      localPath: decoded['localPath']?.toString(),
      sizeBytes: decoded['sizeBytes'] is int
          ? decoded['sizeBytes'] as int
          : int.tryParse(decoded['sizeBytes']?.toString() ?? ''),
      duration: Duration(
        milliseconds:
            decoded['durationMs'] is int
                ? decoded['durationMs'] as int
                : int.tryParse(decoded['durationMs']?.toString() ?? '') ?? 0,
      ),
    );
  } catch (_) {
    return null;
  }
}

class _VoiceBubblePayload {
  const _VoiceBubblePayload({
    required this.localPath,
    required this.sizeBytes,
    required this.duration,
  });

  final String? localPath;
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
        : Colors.black45;
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

import 'package:app/models/message.dart';
import 'package:app/widgets/burn_timer.dart';
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

    return Align(
      key: const Key('chat-bubble-align'),
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DecoratedBox(
          key: const Key('chat-bubble-decoration'),
          decoration: BoxDecoration(
            color: isMine ? mineColor : otherColor,
            borderRadius: BorderRadius.circular(8),
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
                  child: Text(
                    content,
                    style: Theme.of(context).textTheme.bodyMedium,
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
                      _statusText(message.status),
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusText(MessageStatus status) {
    return switch (status) {
      MessageStatus.sent => 'sent',
      MessageStatus.delivered => 'delivered',
      MessageStatus.read => 'read',
      MessageStatus.burned => 'burned',
      MessageStatus.revoked => 'revoked',
    };
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

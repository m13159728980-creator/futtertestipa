import 'dart:async';

import 'package:app/core/services/secure_window_service.dart';
import 'package:app/models/message.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/providers/call_provider.dart';
import 'package:app/providers/chat_provider.dart';
import 'package:app/screens/call_screen.dart';
import 'package:app/widgets/burn_mode_menu.dart';
import 'package:app/widgets/chat_bubble.dart';
import 'package:app/widgets/default_avatar.dart';
import 'package:app/widgets/message_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    required this.peerId,
    required this.title,
    this.avatarIndex = 0,
    super.key,
  });

  final String peerId;
  final String title;
  final int avatarIndex;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _secureWindowService = SecureWindowService();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(chatProvider).loadMessages(widget.peerId));
  }

  @override
  void dispose() {
    unawaited(_secureWindowService.disable());
    super.dispose();
  }

  Future<void> _setBurnAfter(Duration? duration) async {
    await ref.read(chatProvider).setBurnAfter(widget.peerId, duration);
    await _secureWindowService.setEnabled(duration != null);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final currentUserId = ref.watch(authProvider).user?.id ?? '';
    final messages = chat.messagesFor(widget.peerId);
    final burnAfter = chat.burnAfterFor(widget.peerId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            DefaultAvatar(index: widget.avatarIndex, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    burnAfter == null ? '在线' : '阅后即焚 ${burnAfter.inSeconds} 秒',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Start call',
            onPressed: () async {
              await ref
                  .read(callProvider)
                  .startOneToOneCall(
                    peerId: widget.peerId,
                    peerName: widget.title,
                  );
              if (context.mounted) {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CallScreen()),
                );
              }
            },
            icon: const Icon(Icons.call),
          ),
          BurnModeMenu(selected: burnAfter, onSelected: _setBurnAfter),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _MessageList(
              messages: messages,
              currentUserId: currentUserId,
              onBurnExpired: (messageId) =>
                  ref.read(chatProvider).markBurned(messageId),
            ),
          ),
          MessageComposer(
            onSend: (text) =>
                ref.read(chatProvider).sendText(widget.peerId, text),
            onVoiceSend: (duration) =>
                ref.read(chatProvider).sendVoice(widget.peerId, duration),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.currentUserId,
    this.onBurnExpired,
  });

  final List<Message> messages;
  final String currentUserId;
  final ValueChanged<String>? onBurnExpired;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - index - 1];
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Padding(
            key: ValueKey(message.id),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ChatBubble(
              message: message,
              currentUserId: currentUserId,
              onBurnExpired: onBurnExpired,
            ),
          ),
        );
      },
    );
  }
}

import 'dart:async';

import 'package:app/core/services/secure_window_service.dart';
import 'package:app/models/message.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/providers/chat_provider.dart';
import 'package:app/widgets/chat_bubble.dart';
import 'package:app/widgets/message_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.peerId, required this.title, super.key});

  final String peerId;
  final String title;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _secureWindowService = SecureWindowService();

  Duration? _burnAfter;

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
    setState(() {
      _burnAfter = duration;
    });
    await _secureWindowService.setEnabled(duration != null);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final currentUserId = ref.watch(authProvider).user?.id ?? '';
    final messages = chat.messagesFor(widget.peerId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.person)),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.title)),
          ],
        ),
        actions: [
          _BurnModeMenu(selected: _burnAfter, onSelected: _setBurnAfter),
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
            onSend: (text) => ref
                .read(chatProvider)
                .sendText(widget.peerId, text, burnAfter: _burnAfter),
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

class _BurnModeMenu extends StatelessWidget {
  const _BurnModeMenu({required this.selected, required this.onSelected});

  final Duration? selected;
  final ValueChanged<Duration?> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Duration?>(
      tooltip: 'Burn timer',
      icon: Icon(
        Icons.local_fire_department,
        color: selected == null ? null : Theme.of(context).colorScheme.error,
      ),
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(value: Duration(seconds: 5), child: Text('5秒')),
        PopupMenuItem(value: Duration(seconds: 10), child: Text('10秒')),
        PopupMenuItem(value: Duration(seconds: 30), child: Text('30秒')),
        PopupMenuItem(value: Duration(seconds: 60), child: Text('1分钟')),
        PopupMenuDivider(),
        PopupMenuItem(value: null, child: Text('关闭')),
      ],
    );
  }
}

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
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(chatProvider).loadMessages(widget.peerId));
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
      ),
      body: Column(
        children: [
          Expanded(
            child: _MessageList(
              messages: messages,
              currentUserId: currentUserId,
            ),
          ),
          MessageComposer(
            onSend: (text) =>
                ref.read(chatProvider).sendText(widget.peerId, text),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages, required this.currentUserId});

  final List<Message> messages;
  final String currentUserId;

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
            child: ChatBubble(message: message, currentUserId: currentUserId),
          ),
        );
      },
    );
  }
}

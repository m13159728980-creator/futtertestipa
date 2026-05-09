import 'package:app/providers/auth_provider.dart';
import 'package:app/providers/group_provider.dart';
import 'package:app/widgets/chat_bubble.dart';
import 'package:app/widgets/message_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({required this.groupId, this.title, super.key});

  final String groupId;
  final String? title;

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(groupProvider).loadMessages(widget.groupId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupProvider);
    final group = groups.groupFor(widget.groupId);
    final currentUserId = ref.watch(authProvider).user?.id ?? '';
    final messages = groups.messagesFor(widget.groupId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.group)),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.title ?? group.name)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
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
                      senderName:
                          group.memberNames[message.fromId] ?? message.fromId,
                    ),
                  ),
                );
              },
            ),
          ),
          MessageComposer(
            onSend: (text) =>
                ref.read(groupProvider).sendText(widget.groupId, text),
          ),
        ],
      ),
    );
  }
}

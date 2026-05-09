import 'package:app/models/message.dart';
import 'package:app/providers/chat_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final groupProvider = ChangeNotifierProvider<GroupProvider>((ref) {
  return GroupProvider(chat: ref.watch(chatProvider));
});

class GroupConversation {
  const GroupConversation({
    required this.id,
    required this.name,
    this.memberNames = const {},
  });

  final String id;
  final String name;
  final Map<String, String> memberNames;
}

class GroupProvider extends ChangeNotifier {
  GroupProvider({required ChatProvider chat}) : _chat = chat {
    _chat.addListener(notifyListeners);
  }

  final ChatProvider _chat;
  final Map<String, GroupConversation> _groups = {};

  List<Message> messagesFor(String groupId) {
    return _chat
        .messagesForConversation(
          toType: ConversationType.group,
          peerId: groupId,
        )
        .where((message) => message.toType == ConversationType.group)
        .toList(growable: false);
  }

  GroupConversation groupFor(String groupId) {
    return _groups[groupId] ??
        GroupConversation(id: groupId, name: 'Group $groupId');
  }

  void rememberGroup(GroupConversation group) {
    _groups[group.id] = group;
    notifyListeners();
  }

  Future<void> loadMessages(String groupId) {
    return _chat.loadConversation(
      toType: ConversationType.group,
      peerId: groupId,
    );
  }

  Future<void> sendText(String groupId, String text) {
    return _chat.sendConversationText(
      toType: ConversationType.group,
      peerId: groupId,
      text: text,
    );
  }

  @override
  void dispose() {
    _chat.removeListener(notifyListeners);
    super.dispose();
  }
}

import 'package:app/models/message.dart';
import 'package:app/providers/chat_provider.dart';
import 'package:app/providers/social_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final groupProvider = ChangeNotifierProvider<GroupProvider>((ref) {
  return GroupProvider(
    chat: ref.watch(chatProvider),
    social: ref.watch(socialProvider),
  );
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
  GroupProvider({required ChatProvider chat, SocialProvider? social})
    : _chat = chat,
      _social = social {
    _chat.addListener(notifyListeners);
    _social?.addListener(notifyListeners);
  }

  final ChatProvider _chat;
  final SocialProvider? _social;
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
    final socialGroups = _social?.groups ?? const [];
    for (final socialGroup in socialGroups) {
      if (socialGroup.id != groupId) {
        continue;
      }
      return GroupConversation(
        id: socialGroup.id,
        name: socialGroup.name,
        memberNames: {
          for (final member in socialGroup.members)
            member.userId: member.displayName,
        },
      );
    }
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

  void closeMessages(String groupId) {
    _chat.closeConversation(toType: ConversationType.group, peerId: groupId);
  }

  Future<void> sendText(String groupId, String text, {Duration? burnAfter}) {
    return _chat.sendConversationText(
      toType: ConversationType.group,
      peerId: groupId,
      text: text,
      burnAfter: burnAfter,
    );
  }

  Future<void> markBurned(String messageId) {
    return _chat.markBurned(messageId);
  }

  @override
  void dispose() {
    _chat.removeListener(notifyListeners);
    _social?.removeListener(notifyListeners);
    super.dispose();
  }
}

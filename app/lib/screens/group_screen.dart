import 'dart:async';
import 'dart:io';

import 'package:app/core/services/media_service.dart';
import 'package:app/core/services/secure_window_service.dart';
import 'package:app/core/services/api_service.dart';
import 'package:app/models/group.dart';
import 'package:app/models/message.dart';
import 'package:app/models/user.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/providers/call_provider.dart';
import 'package:app/providers/chat_provider.dart';
import 'package:app/providers/group_provider.dart';
import 'package:app/providers/social_provider.dart';
import 'package:app/screens/call_screen.dart';
import 'package:app/widgets/burn_mode_menu.dart';
import 'package:app/widgets/default_avatar.dart';
import 'package:app/widgets/chat_bubble.dart';
import 'package:app/widgets/message_composer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({required this.groupId, this.title, super.key});

  final String groupId;
  final String? title;

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  static const _secureWindowService = SecureWindowService();
  final _mediaService = MediaService();

  Duration? _burnAfter;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(groupProvider).loadMessages(widget.groupId),
    );
  }

  @override
  void dispose() {
    ref.read(groupProvider).closeMessages(widget.groupId);
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
        actions: [
          IconButton(
            tooltip: '群通话',
            onPressed: () async {
              final memberIds = group.memberNames.keys
                  .where((id) => id != currentUserId)
                  .take(CallProvider.maxParticipants - 1)
                  .toList();
              await ref
                  .read(callProvider)
                  .startGroupCall(peerIds: memberIds, groupName: group.name);
              if (context.mounted) {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CallScreen()),
                );
              }
            },
            icon: const Icon(Icons.call),
          ),
          BurnModeMenu(selected: _burnAfter, onSelected: _setBurnAfter),
          IconButton(
            tooltip: '群设置',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GroupSettingsScreen(groupId: widget.groupId),
              ),
            ),
            icon: const Icon(Icons.more_vert),
          ),
        ],
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
                      onBurnExpired: (messageId) =>
                          ref.read(groupProvider).markBurned(messageId),
                    ),
                  ),
                );
              },
            ),
          ),
          MessageComposer(
            onSend: (text) => ref
                .read(groupProvider)
                .sendText(widget.groupId, text, burnAfter: _burnAfter),
            onAttachmentSelected: (action) =>
                unawaited(_sendAttachment(action)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendAttachment(ComposerAttachmentAction action) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: switch (action) {
          ComposerAttachmentAction.image => FileType.image,
          ComposerAttachmentAction.video => FileType.video,
          ComposerAttachmentAction.file => FileType.any,
        },
        allowMultiple: false,
        withData: false,
      );
      final selectedPath = result?.files.single.path;
      if (selectedPath == null || selectedPath.isEmpty) {
        return;
      }
      final selectedName = result?.files.single.name;

      final selectedFile = File(selectedPath);
      final preparedFile = action == ComposerAttachmentAction.image
          ? (await _mediaService.prepareImage(selectedFile)).file
          : selectedFile;
      await _mediaService.validateFile(preparedFile);
      final token = ref.read(authProvider).user?.token;
      final remotePath = await _mediaService.upload(preparedFile, token: token);
      final title = selectedName != null && selectedName.isNotEmpty
          ? selectedName
          : p.basename(selectedPath);
      await ref
          .read(groupProvider)
          .sendMedia(
            groupId: widget.groupId,
            type: action == ComposerAttachmentAction.image
                ? MessageType.image
                : MessageType.file,
            payload: MediaMessagePayload(
              url: remotePath,
              localPath: preparedFile.path,
              title: title,
              sizeBytes: await preparedFile.length(),
            ),
            burnAfter: _burnAfter,
          );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('附件发送失败 $error')));
    }
  }
}

class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  bool _secureScreen = true;

  @override
  Widget build(BuildContext context) {
    final social = ref.watch(socialProvider);
    final groups = social.groups.where((group) => group.id == widget.groupId);
    final group = groups.isEmpty ? null : groups.first;
    final contacts = social.contacts;
    final members = group?.members ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('群设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.group)),
            title: Text(group?.name ?? '群聊'),
            subtitle: Text(group == null ? '' : '群ID ${group.groupCode}'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: group == null
                ? null
                : () => _renameGroup(context, group.name),
          ),
          SwitchListTile(
            title: const Text('禁止截屏'),
            subtitle: const Text('开启后当前设备聊天界面禁止截屏'),
            value: _secureScreen,
            onChanged: (value) => setState(() => _secureScreen = value),
          ),
          ListTile(
            leading: const Icon(Icons.person_add_alt_1_outlined),
            title: const Text('添加成员'),
            onTap: group == null
                ? null
                : () => _addMembers(context, contacts, members),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('成员'),
          ),
          for (final member in members)
            ListTile(
              leading: DefaultAvatar(index: member.avatarIndex),
              title: Text(member.displayName),
              subtitle: Text('${member.account} · ${_roleLabel(member.role)}'),
            ),
        ],
      ),
    );
  }

  Future<void> _renameGroup(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: currentName);
    String? errorText;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('修改群名'),
          content: TextField(
            controller: controller,
            maxLength: 50,
            decoration: InputDecoration(labelText: '群名称', errorText: errorText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  setState(() => errorText = '请输入群名称');
                  return;
                }
                try {
                  await ref
                      .read(socialProvider)
                      .renameGroup(groupId: widget.groupId, name: name);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } on ApiException catch (error) {
                  setState(() => errorText = error.message);
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _addMembers(
    BuildContext context,
    List<User> contacts,
    List<GroupMember> members,
  ) async {
    final existingIds = {for (final member in members) member.userId};
    final candidates = contacts
        .where((contact) => !existingIds.contains(contact.id))
        .toList();
    final selected = <String>{};
    String? errorText;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('添加成员'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorText != null)
                  Text(
                    errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (candidates.isEmpty)
                  const Text('没有可添加的联系人')
                else
                  for (final contact in candidates)
                    CheckboxListTile(
                      value: selected.contains(contact.id),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selected.add(contact.id);
                          } else {
                            selected.remove(contact.id);
                          }
                        });
                      },
                      title: Text(contact.displayName),
                      subtitle: Text(contact.account),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                      try {
                        await ref
                            .read(socialProvider)
                            .addGroupMembers(
                              groupId: widget.groupId,
                              memberIds: selected.toList(),
                            );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      } on ApiException catch (error) {
                        setState(() => errorText = error.message);
                      }
                    },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  static String _roleLabel(String role) {
    return switch (role) {
      'owner' => '群主',
      'admin' => '管理员',
      _ => '成员',
    };
  }
}

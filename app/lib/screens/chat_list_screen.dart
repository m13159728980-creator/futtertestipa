import 'package:app/core/services/api_service.dart';
import 'package:app/models/user.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/providers/social_provider.dart';
import 'package:app/screens/chat_screen.dart';
import 'package:app/screens/group_screen.dart';
import 'package:app/screens/settings_screen.dart';
import 'package:app/widgets/default_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final social = ref.watch(socialProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('聊天'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(socialProvider).load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
          children: [
            _AccountHeader(user: user),
            const SizedBox(height: 12),
            const SearchBar(
              leading: Icon(Icons.search),
              hintText: '搜索名字或ID',
              elevation: WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(Color(0xFFF2F4F7)),
            ),
            const SizedBox(height: 12),
            if (social.isLoading) const LinearProgressIndicator(),
            if (social.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  social.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (social.contacts.isEmpty && social.groups.isEmpty)
              const _EmptyState()
            else ...[
              if (social.contacts.isNotEmpty) const _SectionHeader('联系人'),
              for (final contact in social.contacts)
                _ConversationTile(
                  avatar: DefaultAvatar(index: contact.avatarIndex),
                  title: contact.displayName,
                  subtitle: 'ID: ${contact.account}',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(
                        peerId: contact.id,
                        title: contact.displayName,
                      ),
                    ),
                  ),
                ),
              if (social.groups.isNotEmpty) const _SectionHeader('群聊'),
              for (final group in social.groups)
                _ConversationTile(
                  avatar: const CircleAvatar(child: Icon(Icons.group)),
                  title: group.name,
                  subtitle:
                      '${group.members.length} 人 · 群ID ${group.groupCode}',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GroupScreen(groupId: group.id),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: '新建',
        onPressed: () => _showNewChatActions(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新建'),
      ),
    );
  }

  Future<void> _showNewChatActions(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: const Text('添加好友'),
              subtitle: const Text('输入对方10位数字ID'),
              onTap: () {
                Navigator.of(context).pop();
                _showAddContactDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: const Text('创建群聊'),
              subtitle: const Text('从联系人中选择成员'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateGroupScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddContactDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    String? errorText;
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('添加好友'),
          content: TextField(
            key: const ValueKey('add-contact-id-field'),
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 10,
            decoration: InputDecoration(
              labelText: '10位数字ID',
              errorText: errorText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final account = controller.text.trim();
                      if (!RegExp(r'^\d{10}$').hasMatch(account)) {
                        setState(() => errorText = '请输入10位数字ID');
                        return;
                      }
                      setState(() {
                        saving = true;
                        errorText = null;
                      });
                      try {
                        final contact = await ref
                            .read(socialProvider)
                            .addContact(account);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ChatScreen(
                                peerId: contact.id,
                                title: contact.displayName,
                              ),
                            ),
                          );
                        }
                      } on ApiException catch (error) {
                        setState(() {
                          saving = false;
                          errorText = error.message;
                        });
                      }
                    },
              child: Text(saving ? '添加中' : '添加'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final Set<String> _selectedIds = {};
  String? _errorText;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(socialProvider).contacts;

    return Scaffold(
      appBar: AppBar(title: const Text('创建群聊')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const ValueKey('group-name-field'),
              controller: _nameController,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: '群名称',
                errorText: _errorText,
              ),
            ),
          ),
          const _SectionHeader('选择成员'),
          if (contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('请先添加好友，再创建群聊。'),
            )
          else
            for (final contact in contacts)
              CheckboxListTile(
                value: _selectedIds.contains(contact.id),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedIds.add(contact.id);
                    } else {
                      _selectedIds.remove(contact.id);
                    }
                  });
                },
                secondary: DefaultAvatar(index: contact.avatarIndex),
                title: Text(contact.displayName),
                subtitle: Text(contact.account),
              ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _saving ? null : _createGroup,
          icon: const Icon(Icons.check),
          label: Text(_saving ? '创建中' : '创建群聊'),
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = '请输入群名称');
      return;
    }
    if (_selectedIds.length < 2) {
      setState(() => _errorText = '至少选择2位好友');
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      final group = await ref
          .read(socialProvider)
          .createGroup(name: name, memberIds: _selectedIds.toList());
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => GroupScreen(groupId: group.id),
          ),
        );
      }
    } on ApiException catch (error) {
      setState(() {
        _saving = false;
        _errorText = error.message;
      });
    }
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: DefaultAvatar(index: user?.avatarIndex ?? 0, radius: 24),
        title: Text(
          user?.displayName ?? '',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(user == null ? '' : 'ID: ${user!.account}'),
        trailing: IconButton(
          tooltip: '复制ID',
          onPressed: user == null
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: user!.account));
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('ID已复制')));
                  }
                },
          icon: const Icon(Icons.copy_outlined),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget avatar;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: avatar,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.forum_outlined,
            size: 52,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text('添加好友后开始聊天', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '点击右下角新建按钮添加好友或创建群聊',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

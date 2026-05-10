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
      appBar: AppBar(
        title: const Text('聊天'),
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
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            _AccountHeader(user: user),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SearchBar(
                leading: Icon(Icons.search),
                hintText: '搜索名字或ID',
              ),
            ),
            if (social.isLoading) const LinearProgressIndicator(),
            if (social.errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
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
                ListTile(
                  leading: DefaultAvatar(index: contact.avatarIndex),
                  title: Text(contact.displayName),
                  subtitle: Text('ID: ${contact.account}'),
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
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.group)),
                  title: Text(group.name),
                  subtitle: Text('${group.members.length} 人 · 群ID ${group.groupCode}'),
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
      floatingActionButton: FloatingActionButton(
        tooltip: '新建',
        onPressed: () => _showNewChatActions(context, ref),
        child: const Icon(Icons.add),
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
              onTap: () {
                Navigator.of(context).pop();
                _showAddContactDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: const Text('创建群聊'),
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

  Future<void> _showAddContactDialog(BuildContext context, WidgetRef ref) async {
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
      final group = await ref.read(socialProvider).createGroup(
            name: name,
            memberIds: _selectedIds.toList(),
          );
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
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      leading: DefaultAvatar(index: user?.avatarIndex ?? 0, radius: 24),
      title: Text(user?.displayName ?? ''),
      subtitle: Text(user == null ? '' : 'ID: ${user!.account}'),
      trailing: IconButton(
        tooltip: '复制ID',
        onPressed: user == null
            ? null
            : () async {
                await Clipboard.setData(ClipboardData(text: user!.account));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID已复制')),
                  );
                }
              },
        icon: const Icon(Icons.copy_outlined),
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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline, size: 48),
          SizedBox(height: 12),
          Text('添加好友后开始聊天'),
        ],
      ),
    );
  }
}

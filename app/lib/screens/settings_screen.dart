import 'package:app/core/constants/avatar_catalog.dart';
import 'package:app/models/settings.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/providers/chat_provider.dart';
import 'package:app/providers/settings_provider.dart';
import 'package:app/screens/app_lock_screen.dart';
import 'package:app/widgets/default_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).settings;
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _Section(
            title: '账号',
            children: [
              ListTile(
                title: Text(auth.user?.displayName ?? '未登录'),
                subtitle: Text(auth.user == null ? 'ID: -' : 'ID: ${auth.user!.account}'),
                leading: DefaultAvatar(index: auth.user?.avatarIndex ?? settings.avatarIndex),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _showRenameDialog(context, ref),
              ),
              ListTile(
                key: const ValueKey('settings-avatar'),
                leading: DefaultAvatar(index: settings.avatarIndex),
                title: const Text('更换默认头像'),
                subtitle: Text('头像 ${settings.avatarIndex + 1}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAvatarSheet(context, ref),
              ),
              ListTile(
                title: const Text('应用锁'),
                leading: const Icon(Icons.lock_outline),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppLockScreen(),
                  ),
                ),
              ),
            ],
          ),
          _Section(
            title: '语言',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'zh', label: Text('中文')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {settings.languageCode},
                  onSelectionChanged: (selected) =>
                      ref.read(settingsProvider).setLanguage(selected.single),
                ),
              ),
            ],
          ),
          _Section(
            title: '通知',
            children: [
              SwitchListTile(
                title: const Text('消息通知'),
                value: settings.messageNotifications,
                onChanged: ref.read(settingsProvider).setMessageNotifications,
              ),
              SwitchListTile(
                title: const Text('声音'),
                value: settings.soundNotifications,
                onChanged: ref.read(settingsProvider).setSoundNotifications,
              ),
              SwitchListTile(
                title: const Text('震动'),
                value: settings.vibrationNotifications,
                onChanged: ref.read(settingsProvider).setVibrationNotifications,
              ),
            ],
          ),
          _Section(
            title: '隐私',
            children: [
              SwitchListTile(
                key: const ValueKey('secure-screen-switch'),
                title: const Text('禁止截屏'),
                value: settings.disableScreenshots,
                onChanged: ref.read(settingsProvider).setDisableScreenshots,
              ),
              _DropdownTile<int>(
                title: '默认阅后即焚',
                value: settings.defaultBurnTimerSeconds,
                items: const {0: '关闭', 10: '10 秒', 60: '1 分钟', 300: '5 分钟'},
                onChanged: ref.read(settingsProvider).setDefaultBurnTimerSeconds,
              ),
              SwitchListTile(
                title: const Text('隐藏最后在线'),
                value: settings.hideLastSeen,
                onChanged: ref.read(settingsProvider).setHideLastSeen,
              ),
            ],
          ),
          _Section(
            title: '聊天',
            children: [
              ListTile(
                title: const Text('字体大小'),
                subtitle: Slider(
                  value: settings.chatFontSize,
                  min: 13,
                  max: 22,
                  divisions: 9,
                  label: settings.chatFontSize.round().toString(),
                  onChanged: ref.read(settingsProvider).setChatFontSize,
                ),
              ),
              _DropdownTile<ChatEnterKeyBehavior>(
                title: '发送键/换行键',
                value: settings.enterKeyBehavior,
                items: const {
                  ChatEnterKeyBehavior.send: 'Enter 发送',
                  ChatEnterKeyBehavior.newline: 'Enter 换行',
                },
                onChanged: ref.read(settingsProvider).setEnterKeyBehavior,
              ),
              SwitchListTile(
                title: const Text('长按录音'),
                value: settings.holdToRecord,
                onChanged: ref.read(settingsProvider).setHoldToRecord,
              ),
            ],
          ),
          _Section(
            title: '数据',
            children: [
              SwitchListTile(
                title: const Text('仅 WiFi 加载媒体'),
                value: settings.wifiOnlyMediaLoading,
                onChanged: ref.read(settingsProvider).setWifiOnlyMediaLoading,
              ),
              _DropdownTile<FileAutoDownloadLimit>(
                title: '文件自动下载限制',
                value: settings.fileAutoDownloadLimit,
                items: const {
                  FileAutoDownloadLimit.none: '不自动下载',
                  FileAutoDownloadLimit.tenMb: '10 MB',
                  FileAutoDownloadLimit.fiftyMb: '50 MB',
                  FileAutoDownloadLimit.unlimited: '不限',
                },
                onChanged: ref.read(settingsProvider).setFileAutoDownloadLimit,
              ),
              ListTile(
                title: const Text('清空缓存'),
                leading: const Icon(Icons.cleaning_services_outlined),
                onTap: () async {
                  await ref.read(settingsProvider).clearCache();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('缓存已清空')),
                    );
                  }
                },
              ),
            ],
          ),
          _Section(
            title: '安全',
            children: [
              ListTile(
                key: const ValueKey('delete-account-tile'),
                title: const Text('注销账号'),
                leading: const Icon(Icons.delete_forever_outlined),
                textColor: Theme.of(context).colorScheme.error,
                iconColor: Theme.of(context).colorScheme.error,
                onTap: () => _startDeleteAccount(context, ref),
              ),
            ],
          ),
          const _Section(
            title: '关于',
            children: [
              ListTile(title: Text('版本'), subtitle: Text('1.0.0')),
              ListTile(title: Text('隐私政策'), trailing: Icon(Icons.open_in_new)),
              ListTile(title: Text('服务器状态'), subtitle: Text('wdsj.fun:10080')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAvatarSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final avatar in avatarCatalog)
                SizedBox.square(
                  dimension: 72,
                  child: IconButton(
                    key: ValueKey('avatar-choice-${avatar.index}'),
                    tooltip: avatar.label,
                    icon: DefaultAvatar(index: avatar.index, radius: 28),
                    onPressed: () async {
                      await ref.read(settingsProvider).setAvatarIndex(avatar.index);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      return;
    }
    final controller = TextEditingController(text: user.displayName);
    String? errorText;
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('修改名字'),
          content: TextField(
            key: const ValueKey('rename-display-name-field'),
            controller: controller,
            maxLength: 24,
            decoration: InputDecoration(labelText: '名字', errorText: errorText),
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
                      final name = controller.text.trim();
                      if (name.isEmpty) {
                        setState(() => errorText = '请输入名字');
                        return;
                      }
                      setState(() {
                        saving = true;
                        errorText = null;
                      });
                      try {
                        await ref.read(authProvider).updateDisplayName(name);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      } catch (_) {
                        setState(() {
                          saving = false;
                          errorText = ref.read(authProvider).errorMessage ?? '修改失败';
                        });
                      }
                    },
              child: Text(saving ? '保存中' : '保存'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _startDeleteAccount(BuildContext context, WidgetRef ref) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('注销账号'),
        content: const Text('此操作不可逆！账号所有消息和群组将被清空。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('继续注销'),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) {
      return;
    }
    await _confirmDeleteAccount(context, ref);
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    final account = ref.read(authProvider).user?.account ?? '';
    final controller = TextEditingController();
    var errorText = '';

    return showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('确认注销'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('请输入 ID $account 确认注销。'),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('delete-account-confirmation'),
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'ID',
                  errorText: errorText.isEmpty ? null : errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final confirmation = controller.text.trim();
                if (confirmation != account) {
                  setState(() => errorText = 'ID不匹配');
                  return;
                }
                final database = await ref.read(localDatabaseServiceProvider);
                await ref.read(authProvider).deleteAccount(confirmation);
                await database.clear();
                await ref.read(settingsProvider).clearCache();
                await ref.read(settingsProvider).reset();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              child: const Text('确认注销'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String title;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        items: [
          for (final entry in items.entries)
            DropdownMenuItem<T>(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}

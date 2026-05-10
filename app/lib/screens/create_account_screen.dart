import 'package:app/core/services/api_service.dart';
import 'package:app/core/utils/account_validator.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/widgets/default_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _nameController = TextEditingController();

  bool _submitted = false;
  bool _registering = false;
  String? _remoteError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final nameError = _nameError;
    final canSubmit = _canSubmit;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const Center(child: DefaultAvatar(index: 0, radius: 36)),
                const SizedBox(height: 16),
                Text(
                  '欢迎',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: '名字',
                    errorText: _submitted || _nameController.text.isNotEmpty
                        ? nameError
                        : null,
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() => _remoteError = null),
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                Text(
                  '系统会自动生成10位数字ID，可用来添加好友。',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_remoteError != null || auth.errorMessage != null)
                  Text(
                    _remoteError ?? auth.errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: canSubmit ? _submit : null,
                  child: _registering
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('开始聊天'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? get _nameError {
    return AccountValidator.validateDisplayName(_nameController.text);
  }

  bool get _isFormValid => _nameError == null;

  bool get _canSubmit => _isFormValid && !_registering;

  Future<void> _submit() async {
    if (_registering) {
      return;
    }

    setState(() {
      _submitted = true;
      _remoteError = null;
    });

    if (!_isFormValid) {
      return;
    }

    setState(() => _registering = true);
    try {
      await ref
          .read(authProvider)
          .register(displayName: _nameController.text.trim());
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _remoteError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _remoteError = '注册失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _registering = false);
      }
    }
  }
}

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
  final _accountController = TextEditingController();

  bool _submitted = false;
  bool _registering = false;
  bool? _accountAvailable;
  String? _remoteError;
  int _accountCheckGeneration = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final nameError = _nameError;
    final accountError = _accountError;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            const Center(child: DefaultAvatar(index: 0, radius: 40)),
            const SizedBox(height: 16),
            Text(
              '欢迎',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '名字',
                errorText: _submitted || _nameController.text.isNotEmpty
                    ? nameError
                    : null,
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() => _remoteError = null),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountController,
              decoration: InputDecoration(
                labelText: '账号',
                errorText: accountError,
                prefixIcon: const Icon(Icons.alternate_email),
              ),
              textInputAction: TextInputAction.done,
              onChanged: _onAccountChanged,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            if (_remoteError != null || auth.errorMessage != null)
              Text(
                _remoteError ?? auth.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _registering ? null : _submit,
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
    );
  }

  String? get _nameError {
    return AccountValidator.validateDisplayName(_nameController.text);
  }

  String? get _accountError {
    final localError = AccountValidator.validateAccount(
      _accountController.text,
    );
    if (localError != null) {
      return _accountController.text.isEmpty ? null : localError;
    }
    if (_accountAvailable == false) {
      return '账号已被注册';
    }
    return null;
  }

  Future<void> _onAccountChanged(String value) async {
    setState(() {
      _accountAvailable = null;
      _remoteError = null;
    });

    if (AccountValidator.validateAccount(value) != null) {
      return;
    }

    final generation = ++_accountCheckGeneration;
    try {
      final available = await ref.read(apiServiceProvider).checkAccount(value);
      if (!mounted || generation != _accountCheckGeneration) {
        return;
      }
      setState(() => _accountAvailable = available);
    } catch (_) {
      if (!mounted || generation != _accountCheckGeneration) {
        return;
      }
      setState(() => _accountAvailable = null);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _remoteError = null;
    });

    if (_nameError != null || _accountError != null) {
      return;
    }

    setState(() => _registering = true);
    try {
      await ref
          .read(authProvider)
          .register(
            displayName: _nameController.text.trim(),
            account: _accountController.text.trim(),
          );
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/local/local_storage.dart';
import 'package:qinglong_flutter/data/models/models.dart';

class TwoFactorSettingsScreen extends StatefulWidget {
  final bool initiallyEnabled;
  final QingLongApi? api;

  const TwoFactorSettingsScreen({
    super.key,
    required this.initiallyEnabled,
    this.api,
  });

  @override
  State<TwoFactorSettingsScreen> createState() =>
      _TwoFactorSettingsScreenState();
}

class _TwoFactorSettingsScreenState extends State<TwoFactorSettingsScreen> {
  late final QingLongApi _api;
  final _codeController = TextEditingController();
  late bool _enabled;
  TwoFactorInitData? _setup;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? QingLongApi.auth();
    _enabled = widget.initiallyEnabled;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _generateSecret() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _api.initTwoFactor();
      if (response.code != 200 || response.data == null) {
        throw StateError(response.message ?? '生成两步验证密钥失败');
      }
      if (!mounted) return;
      setState(() {
        _setup = response.data;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _activate() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = '请输入 6 位数字验证码');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _api.activateTwoFactor(code);
      if (response.code != 200 || response.data != true) {
        throw StateError(response.message ?? '验证码错误，无法启用两步验证');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _deactivate() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SecurityConfirmSheet(
        title: '关闭两步验证',
        message: '关闭后登录将不再要求验证码，确定继续吗？',
        destructive: true,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _api.deactivateTwoFactor();
      if (response.code != 200 || response.data != true) {
        throw StateError(response.message ?? '关闭两步验证失败');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _copy(String value, String message) async {
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget _header(ColorScheme cs) {
    return _SecurityHeader(
      icon: Icons.verified_user_outlined,
      title: '两步验证',
      subtitle: _enabled ? '已启用，登录时需要验证码' : '使用验证器增加账号安全性',
      color: cs.primary,
    );
  }

  Widget _statusCard(ColorScheme cs) {
    return _SecurityCard(
      child: Row(
        children: [
          Icon(
            _enabled ? Icons.check_circle : Icons.shield_outlined,
            color: _enabled ? cs.primary : cs.onSurfaceVariant,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _enabled ? '两步验证已开启' : '两步验证未开启',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  _enabled ? '你的账号受到额外保护' : '建议使用验证器应用完成配置',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _setupCard(ColorScheme cs) {
    final setup = _setup!;
    return _SecurityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '添加到验证器',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '在 Google Authenticator、Microsoft Authenticator 等应用中手动添加以下密钥。',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          _SecretValue(
            label: '密钥',
            value: setup.secret,
            onCopy: () => _copy(setup.secret, '密钥已复制'),
          ),
          if (setup.url.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SecretValue(
              label: '验证器地址',
              value: setup.url,
              onCopy: () => _copy(setup.url, '验证器地址已复制'),
            ),
          ],
          const SizedBox(height: 16),
          _SecurityField(
            controller: _codeController,
            label: '验证码',
            hintText: '输入验证器中的 6 位数字',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _busy ? null : _activate,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined),
              label: const Text('验证并启用'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _header(cs),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              children: [
                _statusCard(cs),
                const SizedBox(height: 12),
                if (_enabled)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _deactivate,
                      icon: const Icon(Icons.lock_open_outlined),
                      label: const Text('关闭两步验证'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(
                          color: cs.error.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  )
                else if (_setup == null)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _generateSecret,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.key_outlined),
                      label: const Text('生成两步验证密钥'),
                    ),
                  )
                else
                  _setupCard(cs),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CredentialSettingsScreen extends StatefulWidget {
  final String initialUsername;
  final QingLongApi? api;
  final LocalStorage? storage;

  const CredentialSettingsScreen({
    super.key,
    required this.initialUsername,
    this.api,
    this.storage,
  });

  @override
  State<CredentialSettingsScreen> createState() =>
      _CredentialSettingsScreenState();
}

class _CredentialSettingsScreenState extends State<CredentialSettingsScreen> {
  late final QingLongApi _api;
  late final TextEditingController _usernameController;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _saving = false;
  String? _error;
  late final LocalStorage _storage;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? QingLongApi.auth();
    _storage = widget.storage ?? LocalStorage();
    _usernameController = TextEditingController(text: widget.initialUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (username.isEmpty) {
      setState(() => _error = '用户名不能为空');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = '密码不能为空');
      return;
    }
    if (password != confirm) {
      setState(() => _error = '两次输入的密码不一致');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response = await _api.updateUsernameAndPassword(username, password);
      if (response.code != 200) {
        throw StateError(response.message ?? '用户名和密码保存失败');
      }
      await _storage.updateCurrentUsername(username);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _SecurityHeader(
          icon: Icons.manage_accounts_outlined,
          title: '修改用户名和密码',
          subtitle: '更新当前青龙账号凭据',
          color: cs.primary,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              children: [
                _SecurityCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: cs.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '青龙会同时保存用户名和密码，请填写完整信息。密码不能设置为 admin。',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SecurityField(
                  controller: _usernameController,
                  label: '用户名',
                  hintText: '输入新的用户名',
                  icon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                _SecurityField(
                  controller: _passwordController,
                  label: '新密码',
                  hintText: '输入新的密码',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _SecurityField(
                  controller: _confirmController,
                  label: '确认新密码',
                  hintText: '再次输入新的密码',
                  icon: Icons.lock_reset_outlined,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saving ? null : _save(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('保存账号凭据'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SecurityHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _SecurityHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outline.withValues(alpha: 0.16)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  final Widget child;

  const _SecurityCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.primary.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _SecurityField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int? maxLength;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  const _SecurityField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLength,
    this.suffixIcon,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        obscureText: obscureText,
        maxLength: maxLength,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Icon(icon, color: cs.primary),
          suffixIcon: suffixIcon,
          counterText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class _SecretValue extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _SecretValue({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            tooltip: '复制',
            icon: Icon(Icons.copy_outlined, color: cs.primary, size: 20),
          ),
        ],
      ),
    );
  }
}

class _SecurityConfirmSheet extends StatelessWidget {
  final String title;
  final String message;
  final bool destructive;

  const _SecurityConfirmSheet({
    required this.title,
    required this.message,
    required this.destructive,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actionColor = destructive ? cs.error : cs.primary;
    return Material(
      color: cs.primary.withValues(alpha: 0.07),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Icon(
                destructive ? Icons.warning_amber_outlined : Icons.info_outline,
                color: actionColor,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close),
                      label: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: actionColor,
                        foregroundColor: destructive ? cs.onError : null,
                      ),
                      icon: Icon(
                        destructive ? Icons.lock_open_outlined : Icons.check,
                      ),
                      label: const Text('确定'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

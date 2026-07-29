import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/theme/app_visuals.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final QingLongApi? api;

  const LoginScreen({super.key, required this.onLoginSuccess, this.api});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final QingLongApi _api;
  final _serverUrlCtl = TextEditingController();
  final _usernameCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _twoFactorCtl = TextEditingController();
  bool _loading = false;
  bool _pwdVisible = false;
  bool _awaitingTwoFactor = false;
  String? _error;

  @override
  void dispose() {
    _serverUrlCtl.dispose();
    _usernameCtl.dispose();
    _passwordCtl.dispose();
    _twoFactorCtl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? QingLongApi.unauth();
  }

  bool _isValidServerUrl(String value) {
    final normalized =
        value.startsWith("http://") || value.startsWith("https://")
        ? value
        : "http://$value";
    final uri = Uri.tryParse(normalized);
    return uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == "http" || uri.scheme == "https");
  }

  String _formatLoginError(Object error, String server) {
    final uri = Uri.tryParse(
      server.startsWith('http://') || server.startsWith('https://')
          ? server
          : 'http://$server',
    );
    final isLoopback = uri?.host == '127.0.0.1' || uri?.host == 'localhost';

    if (error is SocketException && isLoopback) {
      return 'Android 中 127.0.0.1 指向设备自身。Android Studio 模拟器请使用 '
          '10.0.2.2:5700，真机请使用电脑的局域网 IP。';
    }
    if (error is SocketException) {
      return '无法连接服务器，请确认地址、端口以及设备与服务器的网络连接。';
    }
    return error.toString();
  }

  Future<void> _login() async {
    if (_awaitingTwoFactor) {
      await _verifyTwoFactor();
      return;
    }
    final srv = _serverUrlCtl.text.trim();
    final usr = _usernameCtl.text.trim();
    final pwd = _passwordCtl.text;

    if (srv.isEmpty || usr.isEmpty || pwd.isEmpty) {
      setState(() => _error = "请填写服务器地址、用户名和密码");
      return;
    }
    if (!_isValidServerUrl(srv)) {
      setState(() => _error = "服务器地址格式不正确");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.login(srv, usr, pwd);
      if (!mounted) return;
      if (r.code == 200 && r.data != null) {
        widget.onLoginSuccess();
      } else if (r.code == 420) {
        setState(() {
          _awaitingTwoFactor = true;
          _error = null;
        });
      } else {
        setState(() => _error = r.message ?? "登录失败");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _formatLoginError(e, srv));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyTwoFactor() async {
    final srv = _serverUrlCtl.text.trim();
    final usr = _usernameCtl.text.trim();
    final pwd = _passwordCtl.text;
    final code = _twoFactorCtl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = '请输入二因素验证码');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.twoFactorLogin(srv, usr, pwd, code);
      if (!mounted) return;
      if (r.code == 200 && r.data?.token?.isNotEmpty == true) {
        widget.onLoginSuccess();
      } else {
        setState(() => _error = r.message ?? '验证码错误或已过期');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _formatLoginError(e, srv));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetTwoFactor() {
    setState(() {
      _awaitingTwoFactor = false;
      _twoFactorCtl.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundStart = Color.alphaBlend(
      cs.surfaceContainer.withValues(alpha: isDark ? 0.82 : 0.92),
      cs.surface,
    );

    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomCenter,
              colors: [backgroundStart, cs.surface],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth >= 640
                  ? 32.0
                  : 20.0;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  28,
                  horizontalPadding,
                  32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBrandHeader(theme),
                        const SizedBox(height: 28),
                        AppVisuals.glassSurface(
                          context: context,
                          borderRadius: BorderRadius.circular(18),
                          blur: 10,
                          withShadow: true,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '登录账号',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '请输入青龙面板的连接信息',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _loginField(
                                  cs,
                                  enabled: !_loading && !_awaitingTwoFactor,
                                  child: TextField(
                                    controller: _serverUrlCtl,
                                    decoration: _fieldDecoration(
                                      cs,
                                      label: '服务器地址',
                                      hint: '例如 192.168.1.100:5700',
                                      icon: Icons.dns_outlined,
                                    ),
                                    keyboardType: TextInputType.url,
                                    textInputAction: TextInputAction.next,
                                    enabled: !_loading && !_awaitingTwoFactor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _loginField(
                                  cs,
                                  enabled: !_loading && !_awaitingTwoFactor,
                                  child: TextField(
                                    controller: _usernameCtl,
                                    decoration: _fieldDecoration(
                                      cs,
                                      label: '用户名',
                                      icon: Icons.person_outline,
                                    ),
                                    textInputAction: TextInputAction.next,
                                    enabled: !_loading && !_awaitingTwoFactor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _loginField(
                                  cs,
                                  enabled: !_loading && !_awaitingTwoFactor,
                                  child: TextField(
                                    controller: _passwordCtl,
                                    decoration: _fieldDecoration(
                                      cs,
                                      label: '密码',
                                      icon: Icons.lock_outline,
                                      suffixIcon: Tooltip(
                                        message: _pwdVisible ? '隐藏密码' : '显示密码',
                                        child: IconButton(
                                          icon: Icon(
                                            _pwdVisible
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                          onPressed: _loading
                                              ? null
                                              : () => setState(
                                                  () => _pwdVisible =
                                                      !_pwdVisible,
                                                ),
                                        ),
                                      ),
                                    ),
                                    obscureText: !_pwdVisible,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) =>
                                        _loading ? null : _login(),
                                    enabled: !_loading && !_awaitingTwoFactor,
                                  ),
                                ),
                                if (_awaitingTwoFactor) ...[
                                  const SizedBox(height: 12),
                                  _loginField(
                                    cs,
                                    enabled: !_loading,
                                    child: TextField(
                                      controller: _twoFactorCtl,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) =>
                                          _loading ? null : _verifyTwoFactor(),
                                      enabled: !_loading,
                                      decoration: _fieldDecoration(
                                        cs,
                                        label: '二因素验证码',
                                        hint: '输入认证器中的验证码',
                                        icon: Icons.verified_user_outlined,
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: _loading
                                          ? null
                                          : _resetTwoFactor,
                                      icon: const Icon(
                                        Icons.arrow_back,
                                        size: 16,
                                      ),
                                      label: const Text('返回修改登录信息'),
                                    ),
                                  ),
                                ],
                                if (_error != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.errorContainer,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: cs.error.withValues(alpha: 0.28),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 18,
                                          color: cs.onErrorContainer,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: cs.onErrorContainer,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                SizedBox(
                                  height: 54,
                                  child: FilledButton.icon(
                                    onPressed: _loading ? null : _login,
                                    style: ButtonStyle(
                                      minimumSize: const WidgetStatePropertyAll(
                                        Size.fromHeight(54),
                                      ),
                                      padding: const WidgetStatePropertyAll(
                                        EdgeInsets.symmetric(horizontal: 20),
                                      ),
                                      backgroundColor:
                                          WidgetStateProperty.resolveWith(
                                            (states) =>
                                                states.contains(
                                                  WidgetState.disabled,
                                                )
                                                ? cs.primary.withValues(
                                                    alpha: 0.42,
                                                  )
                                                : cs.primary,
                                          ),
                                      foregroundColor: WidgetStatePropertyAll(
                                        cs.onPrimary,
                                      ),
                                      overlayColor: WidgetStatePropertyAll(
                                        cs.onPrimary.withValues(alpha: 0.12),
                                      ),
                                      elevation:
                                          WidgetStateProperty.resolveWith(
                                            (states) =>
                                                states.contains(
                                                  WidgetState.pressed,
                                                )
                                                ? 0
                                                : 2,
                                          ),
                                      shadowColor: WidgetStatePropertyAll(
                                        cs.primary.withValues(alpha: 0.3),
                                      ),
                                      shape: WidgetStatePropertyAll(
                                        RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          side: BorderSide(
                                            color: cs.primary.withValues(
                                              alpha: 0.55,
                                            ),
                                            width: 0.8,
                                          ),
                                        ),
                                      ),
                                    ),
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      child: _loading
                                          ? SizedBox(
                                              key: const ValueKey(
                                                'login-loading',
                                              ),
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: cs.onPrimary,
                                                strokeWidth: 2.2,
                                              ),
                                            )
                                          : Icon(
                                              key: ValueKey(
                                                _awaitingTwoFactor
                                                    ? 'verify-icon'
                                                    : 'login-icon',
                                              ),
                                              _awaitingTwoFactor
                                                  ? Icons.verified_user_outlined
                                                  : Icons.login_rounded,
                                              size: 19,
                                            ),
                                    ),
                                    label: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      child: Text(
                                        key: ValueKey(
                                          _loading
                                              ? (_awaitingTwoFactor
                                                    ? '正在验证'
                                                    : '正在登录')
                                              : (_awaitingTwoFactor
                                                    ? '验证并登录'
                                                    : '登录'),
                                        ),
                                        _loading
                                            ? (_awaitingTwoFactor
                                                  ? '正在验证'
                                                  : '正在登录')
                                            : (_awaitingTwoFactor
                                                  ? '验证并登录'
                                                  : '登录'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '支持 IP:端口、域名、域名:端口、HTTPS 等格式',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _loginField(
    ColorScheme cs, {
    required Widget child,
    required bool enabled,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: enabled ? 0.055 : 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.primary.withValues(alpha: enabled ? 0.24 : 0.14),
          width: enabled ? 1 : 0.8,
        ),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: child),
    );
  }

  InputDecoration _fieldDecoration(
    ColorScheme cs, {
    required String label,
    String? hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: cs.onSurfaceVariant),
      hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
      prefixIcon: Icon(icon, color: cs.primary, size: 20),
      suffixIcon: suffixIcon,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      isDense: true,
    );
  }

  Widget _buildBrandHeader(ThemeData theme) {
    final cs = theme.colorScheme;
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
          ),
          child: Icon(
            Icons.dashboard_customize_outlined,
            size: 30,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'QL-Next',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '青龙面板管理工具',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

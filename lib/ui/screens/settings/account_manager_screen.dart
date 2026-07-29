import 'package:flutter/material.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/local/local_storage.dart';
import 'package:qinglong_flutter/data/models/models.dart';
import 'package:qinglong_flutter/theme/app_visuals.dart';

class AccountManagerScreen extends StatefulWidget {
  final LocalStorage storage;

  const AccountManagerScreen({super.key, required this.storage});

  @override
  State<AccountManagerScreen> createState() => _AccountManagerScreenState();
}

class _AccountManagerScreenState extends State<AccountManagerScreen> {
  List<AccountEntry> _accounts = const [];
  AccountEntry? _current;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final current = await widget.storage.getCurrentAccount();
      final stored = await widget.storage.getAccounts();
      final unique = <String, AccountEntry>{};
      for (final account in stored) {
        if (account.server.trim().isEmpty || account.token.trim().isEmpty) {
          continue;
        }
        unique[_accountKey(account)] = account;
      }
      if (!mounted) return;
      setState(() {
        _current = current;
        _accounts = unique.values.toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _accountKey(AccountEntry account) {
    return '${account.server.trim()}\u0000${account.username.trim()}';
  }

  bool _isCurrent(AccountEntry account) {
    final current = _current;
    return current != null && _accountKey(current) == _accountKey(account);
  }

  Future<void> _switchAccount(AccountEntry account) async {
    if (_isCurrent(account) || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.storage.switchAccount(account);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _addAccount() async {
    if (_busy) return;
    final credentials = await showModalBottomSheet<_AccountCredentials>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddAccountSheet(),
    );
    if (credentials == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final previous = _current;
      final api = QingLongApi.unauth();
      var response = await api.login(
        credentials.server,
        credentials.username,
        credentials.password,
      );
      if (response.code == 420) {
        final code = await _requestTwoFactorCode();
        if (code == null || code.trim().isEmpty) {
          throw StateError('已取消二因素验证');
        }
        response = await api.twoFactorLogin(
          credentials.server,
          credentials.username,
          credentials.password,
          code.trim(),
        );
      }
      if (response.code != 200 || response.data?.token?.isNotEmpty != true) {
        throw StateError(response.message ?? '登录失败');
      }

      // 登录接口会暂时切换到新账号。添加账号结束后恢复原账号，
      // 这样新增账号不会打断当前页面的会话。
      if (previous != null) {
        await widget.storage.switchAccount(previous);
      } else if (mounted) {
        Navigator.of(context).pop(true);
        return;
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _requestTwoFactorCode() {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TwoFactorCodeSheet(),
    );
  }

  Future<void> _removeAccount(AccountEntry account) async {
    if (_busy || _isCurrent(account)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('移除账号'),
          content: Text('确定移除「${account.username}」的保存信息吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('移除', style: TextStyle(color: cs.error)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.storage.removeAccount(account);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final savedAccounts = _accounts.where((account) => !_isCurrent(account));
    return SafeArea(
      top: false,
      child: Column(
        children: [
          _sheetHandle(cs),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: Row(
              children: [
                _headerAction(
                  cs,
                  Icons.close,
                  '关闭',
                  () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '账号管理',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '保存多个 QingLong 账号并快速切换',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Material(
              color: cs.primary.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: cs.primary.withValues(alpha: 0.28)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _busy ? null : _addAccount,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '添加账号',
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: cs.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: cs.error, fontSize: 12),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        if (_current != null) ...[
                          _sectionLabel('当前账号', cs),
                          _accountTile(_current!, cs, current: true),
                          const SizedBox(height: 16),
                        ],
                        _sectionLabel('已保存账号', cs),
                        if (savedAccounts.isEmpty)
                          _emptyState(cs)
                        else
                          ...savedAccounts.map(
                            (account) => _accountTile(account, cs),
                          ),
                      ],
                    ),
                  ),
          ),
          if (_busy)
            LinearProgressIndicator(
              minHeight: 2,
              color: cs.primary,
              backgroundColor: cs.primary.withValues(alpha: 0.1),
            ),
        ],
      ),
    );
  }

  Widget _sheetHandle(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _headerAction(
    ColorScheme cs,
    IconData icon,
    String tooltip,
    VoidCallback? onPressed,
  ) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: cs.primary.withValues(alpha: enabled ? 0.07 : 0.04),
        shape: CircleBorder(
          side: BorderSide(
            color: cs.primary.withValues(alpha: enabled ? 0.24 : 0.14),
            width: 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 22,
              color: cs.primary.withValues(alpha: enabled ? 1 : 0.42),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _accountTile(
    AccountEntry account,
    ColorScheme cs, {
    bool current = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.primary.withValues(alpha: current ? 0.14 : 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: cs.primary.withValues(alpha: current ? 0.42 : 0.24),
            width: current ? 1.2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: current ? null : () => _switchAccount(account),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    current ? Icons.check_circle_outline : Icons.account_circle,
                    size: 19,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.username.isEmpty ? '未命名账号' : account.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        account.server,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (current)
                  Text(
                    '使用中',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else ...[
                  IconButton(
                    onPressed: _busy ? null : () => _switchAccount(account),
                    tooltip: '切换账号',
                    icon: Icon(Icons.swap_horiz, color: cs.primary, size: 20),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => _removeAccount(account),
                    tooltip: '移除账号',
                    icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: cs.outline,
            size: 36,
          ),
          const SizedBox(height: 8),
          Text(
            '暂无其他已保存账号',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _AccountCredentials {
  final String server;
  final String username;
  final String password;

  const _AccountCredentials({
    required this.server,
    required this.username,
    required this.password,
  });
}

class _AddAccountSheet extends StatefulWidget {
  const _AddAccountSheet();

  @override
  State<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<_AddAccountSheet> {
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final server = _server.text.trim();
    final username = _username.text.trim();
    final password = _password.text;
    if (server.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _error = '请填写服务器地址、用户名和密码');
      return;
    }
    Navigator.of(context).pop(
      _AccountCredentials(
        server: server,
        username: username,
        password: password,
      ),
    );
  }

  InputDecoration _inputDecoration(
    ColorScheme cs,
    String hint,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 19, color: cs.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: cs.primary.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.18)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.primary, width: 1.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: AppVisuals.glassSurface(
        context: context,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        blur: 8,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '添加账号',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '登录成功后会保存账号信息，但不会切换当前账号。',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _server,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    cs,
                    '服务器地址，例如 192.168.1.10:5700',
                    Icons.dns_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(cs, '用户名', Icons.person_outline),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: _inputDecoration(
                    cs,
                    '密码',
                    Icons.lock_outline,
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
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(color: cs.error, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('保存账号'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TwoFactorCodeSheet extends StatefulWidget {
  const _TwoFactorCodeSheet();

  @override
  State<_TwoFactorCodeSheet> createState() => _TwoFactorCodeSheetState();
}

class _TwoFactorCodeSheetState extends State<_TwoFactorCodeSheet> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _code.text.trim();
    if (code.isNotEmpty) Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: AppVisuals.glassSurface(
        context: context,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        blur: 8,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '二因素验证',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '请输入认证器应用中的验证码',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _code,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: '验证码',
                    prefixIcon: Icon(
                      Icons.verified_user_outlined,
                      color: cs.primary,
                    ),
                    filled: true,
                    fillColor: cs.primary.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: cs.primary.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check),
                    label: const Text('验证'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

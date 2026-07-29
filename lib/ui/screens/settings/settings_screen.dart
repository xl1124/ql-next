import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/local/local_storage.dart';
import 'package:qinglong_flutter/data/local/theme_controller.dart';
import 'package:qinglong_flutter/ui/components/shared_components.dart'; // already there
import 'package:qinglong_flutter/ui/screens/settings/settings_view_model.dart';
import 'package:qinglong_flutter/ui/screens/settings/notify_settings_screen.dart';
import 'package:qinglong_flutter/ui/screens/settings/login_logs_screen.dart';
import 'package:qinglong_flutter/ui/screens/settings/script_screen.dart';
import 'package:qinglong_flutter/ui/screens/settings/dependency_screen.dart';
import 'package:qinglong_flutter/ui/screens/settings/subscription_screen.dart';
import 'package:qinglong_flutter/ui/screens/settings/account_manager_screen.dart';
import 'package:qinglong_flutter/ui/screens/settings/security_settings_screen.dart';
import 'package:qinglong_flutter/ui/screens/settings/app_settings_screen.dart';
import 'package:qinglong_flutter/ui/screens/settings/logs_screen.dart';
import 'package:qinglong_flutter/ui/screens/settings/system_settings_screen.dart';
import 'package:qinglong_flutter/theme/app_visuals.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeController themeController;
  final QingLongApi? api;
  final LocalStorage? storage;
  final VoidCallback? onLogout;
  final VoidCallback? onAccountChanged;
  const SettingsScreen({
    super.key,
    required this.themeController,
    this.api,
    this.storage,
    this.onLogout,
    this.onAccountChanged,
  });
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsViewModel _vm;
  String _appVersion = '读取中...';
  static final Uri _coolapkUri = Uri.parse(
    'https://www.coolapk.com/u/33119767',
  );
  static final Uri _githubUri = Uri.parse('https://github.com/xl1124/ql-next');

  @override
  void initState() {
    super.initState();
    _vm = SettingsViewModel(
      widget.api ?? QingLongApi.auth(),
      widget.storage ?? LocalStorage(),
      onLogout: () {
        if (widget.onLogout != null) widget.onLogout!();
      },
    );
    _vm.addListener(_onChange);
    _vm.loadData();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version.trim();
      final buildNumber = packageInfo.buildNumber.trim();
      final value = buildNumber.isEmpty ? version : '$version+$buildNumber';
      if (!mounted) return;
      setState(() => _appVersion = value.isEmpty ? '未知版本' : value);
    } catch (_) {
      if (mounted) setState(() => _appVersion = '未知版本');
    }
  }

  Future<void> _openCoolapkHome() async {
    final opened = await launchUrl(
      _coolapkUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开酷安主页')));
    }
  }

  Future<void> _openGithubRepository() async {
    final opened = await launchUrl(
      _githubUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开 GitHub 仓库')));
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onChange);
    _vm.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  AppVisualPalette get _p => AppVisuals.palette(context);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = _vm.state;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(MediaQuery.of(context).padding.top + 60),
        child: const QlTopBar(title: '设置'),
      ),
      body: state.isLoading
          ? const LoadingIndicator()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                _buildSectionCard(
                  title: '账号信息',
                  icon: Icons.person,
                  children: [
                    _buildInfoRow(
                      Icons.person,
                      '当前用户',
                      state.username.isEmpty ? '未登录' : state.username,
                    ),
                    _buildInfoRow(
                      Icons.dns,
                      '服务器地址',
                      state.serverUrl.isEmpty ? '未配置' : state.serverUrl,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: '外观',
                  icon: Icons.palette_outlined,
                  children: [
                    _buildThemeToggle(),
                    _buildAccentColorSelector(),
                    _buildUiStyleSelector(),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: '功能',
                  icon: Icons.widgets,
                  children: [
                    _buildActionSetting(
                      icon: Icons.notifications_outlined,
                      title: '通知设置',
                      subtitle: '配置推送通知渠道',
                      onTap: _showNotifyManager,
                    ),
                    _buildActionSetting(
                      icon: Icons.code_outlined,
                      title: '脚本管理',
                      subtitle: '查看、编辑和运行 scripts 目录中的脚本',
                      onTap: _showScriptManager,
                    ),
                    _buildActionSetting(
                      icon: Icons.inventory_2_outlined,
                      title: '依赖管理',
                      subtitle: '管理 Node.js、Python 和 Linux 依赖',
                      onTap: _showDependencyManager,
                    ),
                    _buildActionSetting(
                      icon: Icons.sync_alt_outlined,
                      title: '订阅管理',
                      subtitle: '管理仓库、文件订阅和定时同步任务',
                      onTap: _showSubscriptionManager,
                    ),
                    _buildActionSetting(
                      icon: Icons.article_outlined,
                      title: '任务日志',
                      subtitle: '查看所有任务的历史执行日志',
                      onTap: _showLogsManager,
                    ),
                    _buildActionSetting(
                      icon: Icons.dns_outlined,
                      title: '服务器设置',
                      subtitle: '配置青龙系统参数、健康状态和数据备份',
                      onTap: _showSystemSettings,
                    ),
                    _buildActionSetting(
                      icon: Icons.manage_accounts_outlined,
                      title: '账号管理',
                      subtitle: '添加账号并快速切换登录会话',
                      onTap: _showAccountManager,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: '安全',
                  icon: Icons.security,
                  children: [
                    _buildActionSetting(
                      icon: Icons.history,
                      title: '登录日志',
                      subtitle: '查看最近的登录记录',
                      onTap: _showLoginLogs,
                    ),
                    _buildActionSetting(
                      icon: Icons.verified_user_outlined,
                      title: '两步验证',
                      subtitle: state.twoFactorActivated ? '已启用' : '未启用',
                      onTap: _showTwoFactorSettings,
                    ),
                    _buildActionSetting(
                      icon: Icons.manage_accounts_outlined,
                      title: '修改用户名和密码',
                      subtitle: '更新当前青龙账号凭据',
                      onTap: _showCredentialSettings,
                    ),
                    _buildActionSetting(
                      icon: Icons.apps_outlined,
                      title: '青龙应用设置',
                      subtitle: '创建和管理 Client ID、Client Secret',
                      onTap: _showAppSettings,
                    ),
                    _buildActionSetting(
                      icon: Icons.logout,
                      title: '退出登录',
                      subtitle: '退出当前账号',
                      onTap: _showLogoutConfirm,
                      iconColor: cs.error,
                      titleColor: cs.error,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: '关于',
                  icon: Icons.info,
                  children: [
                    _buildInfoRow(Icons.info_outline, '应用版本', _appVersion),
                    _buildInfoRow(
                      Icons.code,
                      '技术栈',
                      'Flutter + Dart + Material 3 + QingLong REST API + GitHub Actions',
                    ),
                    _buildActionSetting(
                      icon: Icons.public,
                      title: '酷安主页',
                      subtitle: '打开我的酷安主页',
                      onTap: _openCoolapkHome,
                    ),
                    _buildActionSetting(
                      icon: Icons.code_outlined,
                      title: 'GitHub 仓库',
                      subtitle: 'https://github.com/xl1124/ql-next',
                      onTap: _openGithubRepository,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final cs = Theme.of(context).colorScheme;
    final cardRadius = BorderRadius.circular(16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        Material(
          color: cs.primary.withValues(alpha: 0.07),
          shape: RoundedRectangleBorder(
            borderRadius: cardRadius,
            side: BorderSide(color: cs.primary.withValues(alpha: 0.24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildActionSetting({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('settings-action-$title'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (iconColor ?? cs.tertiary).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: iconColor ?? cs.tertiary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: titleColor,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: _p.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String subtitle) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: cs.tertiary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      softWrap: true,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: _p.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 外观设置 =====

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
    }
  }

  IconData _themeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }

  Widget _buildThemeToggle() {
    return _buildActionSetting(
      icon: _themeModeIcon(widget.themeController.themeMode),
      title: '夜间模式',
      subtitle: _themeModeLabel(widget.themeController.themeMode),
      onTap: () => _showThemeModeModal(),
    );
  }

  void _showScriptManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QlSettingsSheet(child: ScriptScreen()),
    );
  }

  void _showNotifyManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QlSettingsSheet(child: NotifySettingsScreen()),
    );
  }

  void _showDependencyManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QlSettingsSheet(child: DependencyScreen()),
    );
  }

  void _showSubscriptionManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QlSettingsSheet(child: SubscriptionScreen()),
    );
  }

  void _showLogsManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QlSettingsSheet(child: LogsScreen(api: widget.api)),
    );
  }

  void _showSystemSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          QlSettingsSheet(child: SystemSettingsScreen(api: widget.api)),
    );
  }

  Future<void> _showAccountManager() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QlSettingsSheet(
        child: AccountManagerScreen(storage: widget.storage ?? LocalStorage()),
      ),
    );
    if (!mounted) return;
    _vm.loadData();
    if (changed == true) widget.onAccountChanged?.call();
  }

  void _showLoginLogs() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QlSettingsSheet(child: LoginLogsScreen()),
    );
  }

  Future<void> _showTwoFactorSettings() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QlSettingsSheet(
        child: Column(
          children: [
            const QlSheetHandle(),
            Expanded(
              child: TwoFactorSettingsScreen(
                initiallyEnabled: _vm.state.twoFactorActivated,
                api: widget.api,
              ),
            ),
          ],
        ),
      ),
    );
    if (changed == true && mounted) _vm.loadData();
  }

  Future<void> _showCredentialSettings() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QlSettingsSheet(
        child: Column(
          children: [
            const QlSheetHandle(),
            Expanded(
              child: CredentialSettingsScreen(
                initialUsername: _vm.state.username,
                api: widget.api,
                storage: widget.storage,
              ),
            ),
          ],
        ),
      ),
    );
    if (changed == true && mounted) _vm.loadData();
  }

  void _showAppSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          QlSettingsSheet(child: AppSettingsScreen(api: widget.api)),
    );
  }

  Widget _buildAccentColorSelector() {
    final accent = widget.themeController.accentColor;
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAccentColorModal(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.color_lens_rounded,
                    size: 16,
                    color: cs.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '强调色',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _hexColor(accent),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _hexColor(Color color) {
    final value = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${value.substring(2).toUpperCase()}';
  }

  Widget _buildUiStyleSelector() {
    return _buildSwitchSetting(
      title: '玻璃效果',
      subtitle: '启用半透明毛玻璃背景',
      value: widget.themeController.glassEffects,
      onChanged: (v) => widget.themeController.setGlassEffects(v),
      icon: Icons.blur_on_rounded,
    );
  }

  Widget _buildSwitchSetting({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: cs.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: (v) => onChanged(v),
                  activeTrackColor: cs.primary,
                  thumbColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected)
                        ? cs.onPrimary
                        : cs.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showThemeModeModal() {
    final tc = widget.themeController;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AppVisuals.glassSurface(
          context: ctx,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          blur: 8,
          withShadow: false,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 14),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 2, 24, 12),
                  child: Row(
                    children: [
                      Icon(
                        _themeModeIcon(tc.themeMode),
                        color: cs.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '夜间模式',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                _themeModeOption(
                  ctx,
                  tc,
                  ThemeMode.system,
                  '跟随系统',
                  '跟随系统外观',
                  Icons.brightness_auto,
                ),
                _themeModeOption(
                  ctx,
                  tc,
                  ThemeMode.light,
                  '浅色',
                  '始终使用浅色主题',
                  Icons.light_mode,
                ),
                _themeModeOption(
                  ctx,
                  tc,
                  ThemeMode.dark,
                  '深色',
                  '始终使用深色主题',
                  Icons.dark_mode,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _themeModeOption(
    BuildContext ctx,
    dynamic tc,
    ThemeMode mode,
    String label,
    String hint,
    IconData icon,
  ) {
    final cs = Theme.of(ctx).colorScheme;
    final selected = tc.themeMode == mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: cs.primary.withValues(alpha: selected ? 0.14 : 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: cs.primary.withValues(alpha: selected ? 0.42 : 0.24),
            width: selected ? 1.4 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            tc.setThemeMode(mode);
            Navigator.of(ctx).pop();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: cs.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                      Text(
                        hint,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check, size: 18, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAccentColorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final accent = widget.themeController.accentColor;
        return AppVisuals.glassSurface(
          context: ctx,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          blur: 8,
          withShadow: false,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 14),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.color_lens_rounded,
                          color: cs.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '强调色',
                              style: Theme.of(ctx).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              _hexColor(accent),
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _settingsHeaderAction(
                        ctx,
                        cs,
                        Icons.close,
                        '关闭',
                        () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      alignment: WrapAlignment.center,
                      children: presetAccentColors.map((color) {
                        final selected =
                            widget.themeController.accentColor.toARGB32() ==
                            color.toARGB32();
                        return _accentSwatch(ctx, cs, color, selected);
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _accentSwatch(
    BuildContext ctx,
    ColorScheme cs,
    Color color,
    bool selected,
  ) {
    return Tooltip(
      message: _hexColor(color),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.primary.withValues(alpha: selected ? 0.18 : 0.08),
          border: Border.all(
            color: cs.primary.withValues(alpha: selected ? 0.7 : 0.24),
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          color: color,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              widget.themeController.setAccentColor(color);
              Navigator.of(ctx).pop();
            },
            child: SizedBox(
              width: 48,
              height: 48,
              child: selected
                  ? Icon(Icons.check, color: _contrastColor(color), size: 22)
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Color _contrastColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  Widget _settingsHeaderAction(
    BuildContext ctx,
    ColorScheme cs,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: cs.primary.withValues(alpha: 0.07),
        shape: CircleBorder(
          side: BorderSide(color: cs.primary.withValues(alpha: 0.24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: cs.primary, size: 21),
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirm() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppVisuals.glassSurface(
        context: ctx,
        blur: 8,
        withShadow: false,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: _LogoutConfirmSheet(
          username: _vm.state.username,
          onCancel: () => Navigator.pop(ctx),
          onConfirm: () {
            Navigator.pop(ctx);
            _vm.logout();
          },
        ),
      ),
    );
  }
}

class _LogoutConfirmSheet extends StatelessWidget {
  final String username;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _LogoutConfirmSheet({
    required this.username,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: cs.error.withValues(alpha: 0.24)),
              ),
              child: Icon(Icons.logout_rounded, color: cs.error, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              '退出登录',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              username.isEmpty ? '确定要退出当前账号吗？' : '确定要退出账号“$username”吗？',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppVisuals.palette(context).textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '退出后需要重新输入账号信息才能登录。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppVisuals.palette(context).textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.tonalIcon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close),
                      label: const Text('取消'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('退出登录'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

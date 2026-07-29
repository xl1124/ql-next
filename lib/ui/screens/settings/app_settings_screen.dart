import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/models/models.dart';
import 'package:qinglong_flutter/theme/app_visuals.dart';
import 'package:qinglong_flutter/ui/components/shared_components.dart';

class AppSettingsScreen extends StatefulWidget {
  final QingLongApi? api;

  const AppSettingsScreen({super.key, this.api});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  late final QingLongApi _api;
  List<OpenApp> _apps = const [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  final Set<int> _visibleSecrets = <int>{};

  static const _scopeLabels = <String, String>{
    'envs': '环境变量',
    'crons': '定时任务',
    'configs': '配置文件',
    'scripts': '脚本',
    'logs': '日志',
    'system': '系统',
    'dashboard': '仪表盘',
  };

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? QingLongApi.auth();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (!mounted) return;
    setState(() {
      if (refresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _error = null;
    });
    try {
      final response = await _api.getOpenApps();
      if (!mounted) return;
      if (response.code != 200 || response.data == null) {
        throw StateError(response.message ?? '读取应用列表失败');
      }
      setState(() {
        _apps = response.data!;
        _loading = false;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = _errorText(error);
      });
    }
  }

  Future<void> _openForm({OpenApp? app}) async {
    final result = await showModalBottomSheet<_AppFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.78,
        child: AppVisuals.glassSurface(
          context: ctx,
          blur: 8,
          withShadow: false,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: _AppFormSheet(initial: app, scopeLabels: _scopeLabels),
        ),
      ),
    );
    if (!mounted || result == null) return;

    try {
      final response = app == null
          ? await _api.createOpenApp(result.name, result.scopes)
          : await _api.updateOpenApp(app.id!, result.name, result.scopes);
      if (!mounted) return;
      if (response.code != 200 || response.data == null) {
        throw StateError(response.message ?? '保存应用失败');
      }
      await _load(refresh: true);
      if (app == null && mounted) {
        await _showCredentials(response.data!, title: '应用创建成功');
      } else {
        _showMessage('应用已保存');
      }
    } catch (error) {
      if (mounted) _showMessage(_errorText(error), error: true);
    }
  }

  Future<void> _resetSecret(OpenApp app) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AppConfirmSheet(
        title: '重置 Client Secret',
        message: '重置后旧 Secret 会立即失效，使用它的客户端需要同步更新。确定继续吗？',
        confirmLabel: '重置 Secret',
        destructive: true,
      ),
    );
    if (confirmed != true || !mounted || app.id == null) return;

    try {
      final response = await _api.resetOpenAppSecret(app.id!);
      if (!mounted) return;
      if (response.code != 200 || response.data == null) {
        throw StateError(response.message ?? '重置 Secret 失败');
      }
      await _load(refresh: true);
      if (mounted) await _showCredentials(response.data!, title: 'Secret 已重置');
    } catch (error) {
      if (mounted) _showMessage(_errorText(error), error: true);
    }
  }

  Future<void> _deleteApp(OpenApp app) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AppConfirmSheet(
        title: '删除应用',
        message:
            '删除“${app.name.isEmpty ? '未命名应用' : app.name}”后，使用它的客户端将无法继续获取访问令牌。确定删除吗？',
        confirmLabel: '删除应用',
        destructive: true,
      ),
    );
    if (confirmed != true || !mounted || app.id == null) return;

    try {
      final response = await _api.deleteOpenApps([app.id!]);
      if (!mounted) return;
      if (response.code != 200) {
        throw StateError(response.message ?? '删除应用失败');
      }
      _showMessage('应用已删除');
      _load(refresh: true);
    } catch (error) {
      if (mounted) _showMessage(_errorText(error), error: true);
    }
  }

  Future<void> _copy(String value, String label) async {
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _showMessage('$label已复制');
  }

  Future<void> _showCredentials(OpenApp app, {required String title}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppVisuals.glassSurface(
        context: ctx,
        blur: 8,
        withShadow: false,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: _CredentialSheet(
          title: title,
          app: app,
          onCopy: (value, label) => _copy(value, label),
        ),
      ),
    );
  }

  String _errorText(Object error) {
    final text = error.toString();
    return text.startsWith('Bad state: ') ? text.substring(11) : text;
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildHeader(cs),
        Expanded(child: _buildBody(cs)),
      ],
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Column(
      children: [
        _sheetHandle(context),
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
                      '青龙应用设置',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '创建和管理 Client ID、Client Secret',
                      style: TextStyle(
                        color: AppVisuals.palette(context).textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _headerAction(
                cs,
                Icons.refresh,
                '刷新',
                _refreshing ? null : () => _load(refresh: true),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildBody(ColorScheme cs) {
    if (_loading) return const Center(child: LoadingIndicator());
    if (_error != null) {
      return QlErrorState(
        title: '应用设置加载失败',
        message: _error!,
        onRetry: _refreshing ? null : () => _load(refresh: true),
        retryLabel: '重新加载',
      );
    }
    if (_apps.isEmpty) {
      return _buildEmpty(cs);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _apps.length + 1,
      itemBuilder: (_, index) {
        if (index == _apps.length) return _buildAddButton(cs);
        return _buildAppCard(cs, _apps[index]);
      },
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return QlEmptyState(
      icon: Icons.key_off_outlined,
      title: '还没有应用',
      subtitle: '创建一个应用来获取 Client ID 和 Client Secret',
      action: FilledButton.icon(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('创建应用'),
      ),
    );
  }

  Widget _buildAddButton(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 12),
      child: OutlinedButton.icon(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('创建新应用'),
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }

  Widget _buildAppCard(ColorScheme cs, OpenApp app) {
    final id = app.id ?? app.clientId.hashCode;
    final visible = _visibleSecrets.contains(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cs.primary.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.primary.withValues(alpha: 0.24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.apps_outlined,
                      color: cs.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      app.name.isEmpty ? '未命名应用' : app.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '编辑',
                    onPressed: () => _openForm(app: app),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: '更多操作',
                    onPressed: () => _showAppActions(app),
                    icon: const Icon(Icons.more_horiz, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _credentialRow(
                cs,
                label: 'Client ID',
                value: app.clientId,
                onCopy: () => _copy(app.clientId, 'Client ID'),
              ),
              const SizedBox(height: 8),
              _credentialRow(
                cs,
                label: 'Client Secret',
                value: visible ? app.clientSecret : _mask(app.clientSecret),
                onCopy: () => _copy(app.clientSecret, 'Client Secret'),
                trailing: IconButton(
                  tooltip: visible ? '隐藏 Secret' : '显示 Secret',
                  onPressed: () => setState(() {
                    if (visible) {
                      _visibleSecrets.remove(id);
                    } else {
                      _visibleSecrets.add(id);
                    }
                  }),
                  icon: Icon(
                    visible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                  ),
                ),
              ),
              if (app.scopes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: app.scopes
                      .map(
                        (scope) => _scopeChip(cs, _scopeLabels[scope] ?? scope),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _credentialRow(
    ColorScheme cs, {
    required String label,
    required String value,
    required VoidCallback onCopy,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 4, 9),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '未返回' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          ?trailing,
          IconButton(
            tooltip: '复制 $label',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _scopeChip(ColorScheme cs, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: cs.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _showAppActions(OpenApp app) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppVisuals.glassSurface(
        context: ctx,
        blur: 8,
        withShadow: false,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHandle(ctx),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 2, 24, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.apps_outlined,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        app.name.isEmpty ? '未命名应用' : app.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _actionTile(ctx, Icons.edit_outlined, '编辑应用', 'edit'),
              _actionTile(
                ctx,
                Icons.vpn_key_outlined,
                '重置 Client Secret',
                'reset',
              ),
              _actionTile(
                ctx,
                Icons.delete_outline,
                '删除应用',
                'delete',
                destructive: true,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        _openForm(app: app);
      case 'reset':
        _resetSecret(app);
      case 'delete':
        _deleteApp(app);
    }
  }

  Widget _sheetHandle(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _actionTile(
    BuildContext context,
    IconData icon,
    String title,
    String value, {
    bool destructive = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final color = destructive ? cs.error : cs.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: color.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withValues(alpha: 0.22)),
        ),
        child: InkWell(
          onTap: () => Navigator.pop(context, value),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _mask(String value) {
    if (value.isEmpty) return '';
    if (value.length <= 8) return '••••••••';
    return '${value.substring(0, 4)}••••${value.substring(value.length - 4)}';
  }
}

class _AppFormResult {
  final String name;
  final List<String> scopes;

  const _AppFormResult(this.name, this.scopes);
}

class _AppFormSheet extends StatefulWidget {
  final OpenApp? initial;
  final Map<String, String> scopeLabels;

  const _AppFormSheet({required this.initial, required this.scopeLabels});

  @override
  State<_AppFormSheet> createState() => _AppFormSheetState();
}

class _AppFormSheetState extends State<_AppFormSheet> {
  late final TextEditingController _nameController;
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _selected = List<String>.from(
      widget.initial?.scopes ?? const ['envs', 'crons'],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('请输入应用名称');
      return;
    }
    if (_selected.isEmpty) {
      _showError('至少选择一项权限');
      return;
    }
    Navigator.pop(context, _AppFormResult(name, _selected));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 2, 22, 12),
            child: Row(
              children: [
                Icon(
                  widget.initial == null
                      ? Icons.add_box_outlined
                      : Icons.edit_outlined,
                  color: cs.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.initial == null ? '创建应用' : '编辑应用',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                _field(cs),
                const SizedBox(height: 16),
                Text(
                  'API 权限',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '选择此应用可以访问的青龙数据范围',
                  style: TextStyle(
                    color: AppVisuals.palette(context).textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                ...widget.scopeLabels.entries.map(
                  (entry) => _scopeOption(cs, entry.key, entry.value),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('取消'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: Icon(
                      widget.initial == null ? Icons.add : Icons.save_outlined,
                    ),
                    label: Text(widget.initial == null ? '创建' : '保存'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
      ),
      child: TextField(
        controller: _nameController,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: '应用名称',
          hintText: '例如：我的自动化工具',
          prefixIcon: Icon(Icons.label_outline, color: cs.primary),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
        ),
      ),
    );
  }

  Widget _scopeOption(ColorScheme cs, String scope, String label) {
    final selected = _selected.contains(scope);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.primary.withValues(alpha: selected ? 0.12 : 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: cs.primary.withValues(alpha: selected ? 0.28 : 0.16),
          ),
        ),
        child: InkWell(
          onTap: () => setState(() {
            if (selected) {
              _selected.remove(scope);
            } else {
              _selected.add(scope);
            }
          }),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            child: Row(
              children: [
                Icon(_scopeIcon(scope), color: cs.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Checkbox(
                  value: selected,
                  onChanged: (_) => setState(() {
                    if (selected) {
                      _selected.remove(scope);
                    } else {
                      _selected.add(scope);
                    }
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _scopeIcon(String scope) {
    switch (scope) {
      case 'envs':
        return Icons.tune_outlined;
      case 'crons':
        return Icons.schedule_outlined;
      case 'configs':
        return Icons.description_outlined;
      case 'scripts':
        return Icons.code_outlined;
      case 'logs':
        return Icons.article_outlined;
      case 'system':
        return Icons.settings_outlined;
      case 'dashboard':
        return Icons.dashboard_outlined;
      default:
        return Icons.key_outlined;
    }
  }
}

class _CredentialSheet extends StatelessWidget {
  final String title;
  final OpenApp app;
  final Future<void> Function(String value, String label) onCopy;

  const _CredentialSheet({
    required this.title,
    required this.app,
    required this.onCopy,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: cs.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '请妥善保存以下凭据，Client Secret 不应分享给他人。',
              style: TextStyle(
                color: AppVisuals.palette(context).textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            _value(
              context,
              cs,
              'Client ID',
              app.clientId,
              () => onCopy(app.clientId, 'Client ID'),
            ),
            const SizedBox(height: 10),
            _value(
              context,
              cs,
              'Client Secret',
              app.clientSecret,
              () => onCopy(app.clientSecret, 'Client Secret'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _value(
    BuildContext context,
    ColorScheme cs,
    String label,
    String value,
    VoidCallback onCopy,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 5, 10),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value.isEmpty ? '未返回' : value,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '复制 $label',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined, size: 19),
          ),
        ],
      ),
    );
  }
}

class _AppConfirmSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  const _AppConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = destructive ? cs.error : cs.primary;
    return AppVisuals.glassSurface(
      context: context,
      blur: 8,
      withShadow: false,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
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
              Icon(
                destructive ? Icons.warning_amber_rounded : Icons.help_outline,
                color: color,
                size: 30,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppVisuals.palette(context).textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(backgroundColor: color),
                      child: Text(confirmLabel),
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

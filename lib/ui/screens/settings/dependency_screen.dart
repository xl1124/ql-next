import 'package:flutter/material.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/models/models.dart';
import 'package:qinglong_flutter/theme/app_visuals.dart';
import 'package:qinglong_flutter/ui/components/shared_components.dart';

class DependencyScreen extends StatefulWidget {
  final QingLongApi? api;

  const DependencyScreen({super.key, this.api});

  @override
  State<DependencyScreen> createState() => _DependencyScreenState();
}

class _DependencyScreenState extends State<DependencyScreen> {
  late final QingLongApi _api;
  final _searchController = TextEditingController();
  List<DependencyInfo> _items = const [];
  String _type = 'nodejs';
  bool _loading = true;
  String? _error;
  final Set<int> _busyIds = <int>{};
  bool _formBusy = false;
  Future<void>? _loadInFlight;
  int _loadVersion = 0;

  static const _types = ['nodejs', 'python3', 'linux'];
  static const _typeLabels = {
    'nodejs': 'Node.js',
    'python3': 'Python 3',
    'linux': 'Linux',
  };
  static const _statusLabels = [
    '安装中',
    '已安装',
    '安装失败',
    '删除中',
    '已删除',
    '删除失败',
    '队列中',
    '已取消',
  ];

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? QingLongApi.auth();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _loadVersion++;
    final pending = _loadInFlight;
    if (pending != null) return pending;

    final request = _loadLatest();
    _loadInFlight = request;
    try {
      await request;
    } finally {
      if (identical(_loadInFlight, request)) _loadInFlight = null;
    }
  }

  Future<void> _loadLatest() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    while (mounted) {
      final version = _loadVersion;
      final searchValue = _searchController.text.trim();
      final type = _type;
      try {
        final response = await _api.getDependencies(
          searchValue: searchValue,
          type: type,
        );
        if (!mounted) return;
        if (response.code >= 400 || response.data == null) {
          throw StateError(response.message ?? '读取依赖列表失败');
        }
        if (version == _loadVersion) {
          _items = response.data!
              .whereType<Map<String, dynamic>>()
              .map(DependencyInfo.fromJson)
              .toList();
        }
      } catch (error) {
        if (!mounted) return;
        if (version == _loadVersion) {
          setState(() {
            _loading = false;
            _error = _errorText(error);
          });
          return;
        }
      }

      if (version == _loadVersion) {
        setState(() => _loading = false);
        return;
      }
    }
  }

  void _changeType(String type) {
    if (type == _type) return;
    setState(() => _type = type);
    _load();
  }

  Future<void> _openForm({DependencyInfo? dependency}) async {
    if (_formBusy) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.75,
        child: AppVisuals.glassSurface(
          context: ctx,
          blur: 8,
          withShadow: false,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: _DependencyFormSheet(
            initial: dependency,
            defaultType: dependency?.type ?? _typeIndex(_type),
            onSubmit: (result) => _submitForm(result, dependency),
          ),
        ),
      ),
    );
  }

  Future<String?> _submitForm(
    _DependencyFormResult result,
    DependencyInfo? dependency,
  ) async {
    if (_formBusy) return '已有依赖操作正在处理';
    if (mounted) setState(() => _formBusy = true);
    try {
      QingLongResponse<dynamic> response;
      if (dependency == null) {
        final names = result.autoSplit
            ? result.name.split(RegExp(r'[&\n]'))
            : [result.name];
        final payload = names
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .map(
              (name) => {
                'name': name,
                'type': result.type,
                'remark': result.remark,
              },
            )
            .toList();
        if (payload.isEmpty) throw StateError('请输入依赖名称');
        response = await _api.createDependencies(payload);
      } else {
        response = await _api.updateDependency({
          'id': dependency.id,
          'name': result.name.trim(),
          'type': result.type,
          'remark': result.remark,
        });
      }
      if (response.code >= 400) {
        throw StateError(response.message ?? '保存依赖失败');
      }
      _showMessage(dependency == null ? '依赖已创建，开始安装' : '依赖已更新，开始重新安装');
      await _load();
      return null;
    } catch (error) {
      return _errorText(error);
    } finally {
      if (mounted) setState(() => _formBusy = false);
    }
  }

  Future<void> _showActions(DependencyInfo dependency) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AppVisuals.glassSurface(
          context: ctx,
          blur: 8,
          withShadow: false,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(cs),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 2, 24, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        color: cs.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          dependency.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _actionItem(ctx, Icons.edit_outlined, '编辑', 'edit'),
                _actionItem(ctx, Icons.description_outlined, '查看日志', 'log'),
                _actionItem(ctx, Icons.sync_outlined, '重新安装', 'reinstall'),
                if (_isActive(dependency.status))
                  _actionItem(ctx, Icons.close_outlined, '取消操作', 'cancel'),
                _actionItem(
                  ctx,
                  Icons.delete_outline,
                  '删除',
                  'delete',
                  destructive: true,
                ),
                _actionItem(
                  ctx,
                  Icons.delete_forever_outlined,
                  '强制删除',
                  'forceDelete',
                  destructive: true,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _openForm(dependency: dependency);
      case 'log':
        await _showLog(dependency);
      case 'reinstall':
        await _reinstall(dependency);
      case 'cancel':
        await _cancel(dependency);
      case 'delete':
        await _delete(dependency);
      case 'forceDelete':
        await _delete(dependency, force: true);
    }
  }

  Future<void> _reinstall(DependencyInfo dependency) async {
    if (!await _confirm('重新安装依赖', '确定重新安装“${dependency.name}”吗？')) {
      return;
    }
    await _perform(
      dependency,
      () => _api.reinstallDependencies([dependency.id]),
      '已加入重新安装队列',
    );
  }

  Future<void> _cancel(DependencyInfo dependency) async {
    if (!await _confirm('取消依赖操作', '确定取消“${dependency.name}”的当前操作吗？')) {
      return;
    }
    await _perform(
      dependency,
      () => _api.cancelDependencies([dependency.id]),
      '已取消依赖操作',
    );
  }

  Future<void> _delete(DependencyInfo dependency, {bool force = false}) async {
    final title = force ? '强制删除依赖' : '删除依赖';
    final message = force
        ? '强制删除会直接移除记录，确定删除“${dependency.name}”吗？'
        : '确定删除“${dependency.name}”吗？已安装依赖会先执行卸载。';
    if (!await _confirm(title, message, destructive: true)) return;
    await _perform(
      dependency,
      () => _api.deleteDependencies([dependency.id], force: force),
      force ? '依赖记录已删除' : '已加入删除队列',
    );
  }

  Future<void> _perform(
    DependencyInfo dependency,
    Future<QingLongResponse<dynamic>> Function() action,
    String successMessage,
  ) async {
    if (_formBusy || _busyIds.contains(dependency.id)) return;
    setState(() => _busyIds.add(dependency.id));
    try {
      final response = await action();
      if (response.code >= 400) {
        throw StateError(response.message ?? '依赖操作失败');
      }
      await _load();
      if (mounted) _showMessage(successMessage);
    } catch (error) {
      if (mounted) _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(dependency.id));
    }
  }

  Future<void> _showLog(DependencyInfo dependency) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.82,
        child: AppVisuals.glassSurface(
          context: ctx,
          blur: 8,
          withShadow: false,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: _DependencyLogSheet(api: _api, dependency: dependency),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<bool> _confirm(
    String title,
    String message, {
    bool destructive = false,
  }) async {
    return await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            final cs = Theme.of(ctx).colorScheme;
            return AppVisuals.glassSurface(
              context: ctx,
              blur: 8,
              withShadow: false,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sheetHandle(cs),
                      Icon(
                        destructive
                            ? Icons.warning_amber_outlined
                            : Icons.help_outline,
                        color: destructive ? cs.error : cs.primary,
                        size: 32,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
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
                            child: SizedBox(
                              height: 48,
                              child: FilledButton.tonalIcon(
                                onPressed: () => Navigator.pop(ctx, false),
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
                                style: destructive
                                    ? FilledButton.styleFrom(
                                        backgroundColor: cs.error,
                                      )
                                    : null,
                                onPressed: () => Navigator.pop(ctx, true),
                                icon: Icon(
                                  destructive
                                      ? Icons.delete_outline
                                      : Icons.check,
                                ),
                                label: const Text('确定'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ) ??
        false;
  }

  Widget _actionItem(
    BuildContext ctx,
    IconData icon,
    String label,
    String value, {
    bool destructive = false,
  }) {
    final cs = Theme.of(ctx).colorScheme;
    final actionColor = destructive ? cs.error : cs.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: actionColor.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: actionColor.withValues(alpha: 0.24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pop(ctx, value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: actionColor),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: actionColor,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: actionColor.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(ColorScheme cs) {
    return Column(
      children: [
        _sheetHandle(cs),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
          child: Row(
            children: [
              _headerAction(
                cs: cs,
                icon: Icons.close,
                tooltip: '关闭',
                onPressed: _busyIds.isEmpty && !_formBusy
                    ? () => Navigator.pop(context)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '依赖管理',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '管理 Node.js、Python 和 Linux 依赖',
                      style: TextStyle(
                        color: AppVisuals.palette(context).textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _headerAction(
                cs: cs,
                icon: Icons.add,
                tooltip: '创建依赖',
                onPressed: _busyIds.isEmpty && !_formBusy
                    ? () => _openForm()
                    : null,
              ),
              const SizedBox(width: 8),
              _headerAction(
                cs: cs,
                icon: Icons.refresh,
                tooltip: '刷新',
                onPressed: _busyIds.isEmpty && !_formBusy ? _load : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerAction({
    required ColorScheme cs,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
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

  Widget _sheetHandle(ColorScheme cs) => Container(
    margin: const EdgeInsets.only(top: 12, bottom: 8),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: cs.onSurface.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _header(cs),
        _buildTabs(cs),
        _buildSearch(cs),
        Expanded(child: RepaintBoundary(child: _buildBody(cs))),
      ],
    );
  }

  Widget _buildTabs(ColorScheme cs) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        scrollDirection: Axis.horizontal,
        itemCount: _types.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final type = _types[index];
          final selected = type == _type;
          return Material(
            color: cs.primary.withValues(alpha: selected ? 0.14 : 0.07),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: cs.primary.withValues(alpha: selected ? 0.42 : 0.24),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _changeType(type),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    _typeLabels[type]!,
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearch(ColorScheme cs) {
    return QlSettingsSearchField(
      controller: _searchController,
      hintText: '搜索依赖名称',
      onSubmitted: (_) => _load(),
      onChanged: (_) => setState(() {}),
      onClear: () {
        setState(() {});
        _load();
      },
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) return const Center(child: LoadingIndicator());
    if (_error != null) {
      return QlErrorState(
        title: '依赖列表加载失败',
        message: _error!,
        onRetry: _load,
        retryLabel: '重新加载',
      );
    }
    if (_items.isEmpty) {
      return QlEmptyState(
        icon: Icons.inventory_2_outlined,
        title: '暂无依赖',
        subtitle: '点击右上角加号创建依赖',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _items.length,
      itemBuilder: (_, index) => _buildCard(cs, _items[index]),
    );
  }

  Widget _buildCard(ColorScheme cs, DependencyInfo dependency) {
    final busy = _busyIds.contains(dependency.id);
    final statusColor = _statusColor(cs, dependency.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.primary.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.primary.withValues(alpha: 0.24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : () => _showActions(dependency),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    _typeIcon(dependency.type),
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
                        dependency.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 7,
                        runSpacing: 4,
                        children: [
                          _statusChip(
                            statusColor,
                            _statusLabel(dependency.status),
                          ),
                          Text(
                            _typeLabel(dependency.type),
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          if (dependency.remark.isNotEmpty)
                            Text(
                              dependency.remark,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.more_vert, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(Color color, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withValues(alpha: 0.24)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
  bool _isActive(int status) => status == 0 || status == 3 || status == 6;
  int _typeIndex(String type) => _types.indexOf(type).clamp(0, 2);
  String _typeLabel(int type) => _typeLabels[_types[type.clamp(0, 2)]]!;
  IconData _typeIcon(int type) => type == 0
      ? Icons.javascript
      : type == 1
      ? Icons.code
      : Icons.terminal;
  String _statusLabel(int status) =>
      status >= 0 && status < _statusLabels.length
      ? _statusLabels[status]
      : '未知状态';
  Color _statusColor(ColorScheme cs, int status) => status == 1 || status == 4
      ? Colors.green
      : status == 2 || status == 5
      ? cs.error
      : status == 7
      ? cs.outline
      : cs.primary;
  String _errorText(Object error) {
    final text = error.toString();
    return text.startsWith('Bad state: ') ? text.substring(11) : text;
  }

  void _showMessage(String message, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
          content: Text(message),
        ),
      );
}

class _DependencyFormResult {
  final String name;
  final int type;
  final String remark;
  final bool autoSplit;
  const _DependencyFormResult(
    this.name,
    this.type,
    this.remark,
    this.autoSplit,
  );
}

class _DependencyFormSheet extends StatefulWidget {
  final DependencyInfo? initial;
  final int defaultType;
  final Future<String?> Function(_DependencyFormResult result) onSubmit;

  const _DependencyFormSheet({
    this.initial,
    required this.defaultType,
    required this.onSubmit,
  });
  @override
  State<_DependencyFormSheet> createState() => _DependencyFormSheetState();
}

class _DependencyFormSheetState extends State<_DependencyFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _remark;
  late int _type;
  bool _split = false;
  bool _submitting = false;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _remark = TextEditingController(text: widget.initial?.remark ?? '');
    _type = widget.initial?.type ?? widget.defaultType;
  }

  @override
  void dispose() {
    _name.dispose();
    _remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final edit = widget.initial != null;
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
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
            child: Row(
              children: [
                Icon(edit ? Icons.edit_outlined : Icons.add, color: cs.primary),
                const SizedBox(width: 10),
                Text(
                  edit ? '编辑依赖' : '创建依赖',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _selectField(cs),
                if (!edit) _splitSwitch(cs),
                _formField(
                  cs,
                  _name,
                  '依赖名称',
                  '支持指定版本，可使用换行或 & 分隔多个依赖',
                  Icons.inventory_2_outlined,
                  multiline: true,
                ),
                _formField(cs, _remark, '备注', '可选', Icons.notes_outlined),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.pop(context),
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
                      onPressed: _submitting
                          ? null
                          : () async {
                              if (_name.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('请输入依赖名称')),
                                );
                                return;
                              }
                              setState(() => _submitting = true);
                              final error = await widget.onSubmit(
                                _DependencyFormResult(
                                  _name.text,
                                  _type,
                                  _remark.text.trim(),
                                  _split,
                                ),
                              );
                              if (!mounted || !context.mounted) return;
                              if (error == null) {
                                Navigator.pop(context);
                              } else {
                                setState(() => _submitting = false);
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(error)));
                              }
                            },
                      icon: Icon(edit ? Icons.save_outlined : Icons.add),
                      label: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(edit ? '保存' : '创建'),
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

  Widget _selectField(ColorScheme cs) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
    decoration: BoxDecoration(
      color: cs.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
    ),
    child: DropdownButtonFormField<int>(
      value: _type,
      decoration: InputDecoration(
        labelText: '依赖类型',
        prefixIcon: Icon(Icons.category_outlined, color: cs.primary),
        border: InputBorder.none,
        isDense: true,
      ),
      items: const [
        DropdownMenuItem(value: 0, child: Text('Node.js')),
        DropdownMenuItem(value: 1, child: Text('Python 3')),
        DropdownMenuItem(value: 2, child: Text('Linux')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _type = value);
      },
    ),
  );
  Widget _splitSwitch(ColorScheme cs) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: cs.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
    ),
    child: Row(
      children: [
        Icon(Icons.call_split_outlined, color: cs.primary, size: 20),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('自动拆分', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('按换行或 & 拆分为多个依赖', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        Switch(
          value: _split,
          onChanged: (value) => setState(() => _split = value),
        ),
      ],
    ),
  );
  Widget _formField(
    ColorScheme cs,
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool multiline = false,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: cs.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
    ),
    child: TextField(
      controller: controller,
      maxLines: multiline ? 4 : 1,
      minLines: multiline ? 2 : 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: cs.primary),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    ),
  );
}

class _DependencyLogSheet extends StatefulWidget {
  final QingLongApi api;
  final DependencyInfo dependency;
  const _DependencyLogSheet({required this.api, required this.dependency});
  @override
  State<_DependencyLogSheet> createState() => _DependencyLogSheetState();
}

class _DependencyLogSheetState extends State<_DependencyLogSheet> {
  String _value = '';
  bool _loading = true;
  String? _error;
  Future<void>? _loadInFlight;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pending = _loadInFlight;
    if (pending != null) return pending;
    final request = _loadRequest();
    _loadInFlight = request;
    try {
      await request;
    } finally {
      if (identical(_loadInFlight, request)) _loadInFlight = null;
    }
  }

  Future<void> _loadRequest() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.api.getDependencyDetail(
        widget.dependency.id,
      );
      if (!mounted) return;
      if (response.code >= 400 || response.data == null) {
        throw StateError(response.message ?? '读取依赖日志失败');
      }
      _value = response.data!.log.join('\n');
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _errorText(error);
      });
    }
  }

  String _errorText(Object error) {
    final text = error.toString();
    return text.startsWith('Bad state: ') ? text.substring(11) : text;
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
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '日志 - ${widget.dependency.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '刷新',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _loading
                  ? const Center(child: LoadingIndicator())
                  : _error != null
                  ? Center(child: Text(_error!, textAlign: TextAlign.center))
                  : Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: SelectableText(
                          _value.isEmpty ? '暂无日志' : _value,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: cs.onSurface,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

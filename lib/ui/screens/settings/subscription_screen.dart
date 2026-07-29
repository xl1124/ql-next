import 'package:flutter/material.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/models/models.dart';
import 'package:qinglong_flutter/theme/app_visuals.dart';
import 'package:qinglong_flutter/ui/components/shared_components.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _api = QingLongApi.auth();
  final _searchController = TextEditingController();
  List<SubscriptionInfo> _items = const [];
  bool _loading = true;
  String? _error;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.getSubscriptions(
        searchValue: _searchController.text,
      );
      if (!mounted) return;
      if (response.code != 200 || response.data == null) {
        throw StateError(response.message ?? '读取订阅列表失败');
      }
      setState(() {
        _items = response.data!;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _errorText(error);
      });
    }
  }

  Future<void> _openForm({SubscriptionInfo? subscription}) async {
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.94,
        child: AppVisuals.glassSurface(
          context: ctx,
          blur: 8,
          withShadow: false,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: _SubscriptionFormSheet(initial: subscription),
        ),
      ),
    );
    if (!mounted || payload == null) return;

    try {
      final response = subscription == null
          ? await _api.createSubscription(payload)
          : await _api.updateSubscription({...payload, 'id': subscription.id});
      if (!mounted) return;
      if (response.code != 200) {
        throw StateError(response.message ?? '保存订阅失败');
      }
      _showMessage(subscription == null ? '订阅创建成功' : '订阅更新成功');
      await _load();
    } catch (error) {
      if (mounted) _showMessage(_errorText(error), error: true);
    }
  }

  Future<void> _showActions(SubscriptionInfo subscription) async {
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
                        Icons.sync_alt_outlined,
                        color: cs.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          subscription.name,
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
                if (subscription.isRunning)
                  _actionItem(ctx, Icons.stop_circle_outlined, '停止运行', 'stop')
                else if (subscription.isDisabled == 0)
                  _actionItem(ctx, Icons.play_arrow, '立即运行', 'run'),
                _actionItem(ctx, Icons.description_outlined, '查看日志', 'logs'),
                _actionItem(ctx, Icons.edit_outlined, '编辑', 'edit'),
                _actionItem(
                  ctx,
                  subscription.isDisabled == 1
                      ? Icons.check_circle_outline
                      : Icons.pause_circle_outline,
                  subscription.isDisabled == 1 ? '启用' : '禁用',
                  'toggle',
                ),
                _actionItem(
                  ctx,
                  Icons.delete_outline,
                  '删除',
                  'delete',
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
      case 'run':
        await _perform(
          subscription,
          () => _api.runSubscriptions([subscription.id]),
          '订阅已加入运行队列',
        );
      case 'stop':
        await _perform(
          subscription,
          () => _api.stopSubscriptions([subscription.id]),
          '订阅已停止',
        );
      case 'logs':
        await _showLogs(subscription);
      case 'edit':
        await _openForm(subscription: subscription);
      case 'toggle':
        await _perform(
          subscription,
          () => subscription.isDisabled == 1
              ? _api.enableSubscriptions([subscription.id])
              : _api.disableSubscriptions([subscription.id]),
          subscription.isDisabled == 1 ? '订阅已启用' : '订阅已禁用',
        );
      case 'delete':
        await _delete(subscription);
    }
  }

  Future<void> _perform(
    SubscriptionInfo subscription,
    Future<QingLongResponse<dynamic>> Function() action,
    String successMessage,
  ) async {
    if (_busyId != null) return;
    setState(() => _busyId = subscription.id);
    try {
      final response = await action();
      if (!mounted) return;
      if (response.code != 200) {
        throw StateError(response.message ?? '订阅操作失败');
      }
      _showMessage(successMessage);
      await _load();
    } catch (error) {
      if (mounted) _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(SubscriptionInfo subscription) async {
    var force = false;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AppVisuals.glassSurface(
          context: ctx,
          blur: 8,
          withShadow: false,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) => SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sheetHandle(cs),
                    Icon(Icons.delete_outline, color: cs.error, size: 32),
                    const SizedBox(height: 10),
                    Text(
                      '删除订阅',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '确定删除“${subscription.name}”吗？',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      value: force,
                      onChanged: (value) => setSheetState(() => force = value),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('同时删除关联任务和脚本'),
                      subtitle: const Text('删除本地仓库、脚本和关联定时任务'),
                      activeColor: cs.error,
                    ),
                    const SizedBox(height: 12),
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
                              onPressed: () => Navigator.pop(ctx, true),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('删除'),
                              style: FilledButton.styleFrom(
                                backgroundColor: cs.error,
                                foregroundColor: cs.onError,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _perform(
      subscription,
      () => _api.deleteSubscriptions([subscription.id], force: force),
      '订阅已删除',
    );
  }

  Future<void> _showLogs(SubscriptionInfo subscription) async {
    try {
      final response = await _api.getSubscriptionLogs(subscription.id);
      if (!mounted) return;
      if (response.code != 200) {
        throw StateError(response.message ?? '读取订阅日志失败');
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.84,
          child: AppVisuals.glassSurface(
            context: ctx,
            blur: 8,
            withShadow: false,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: _SubscriptionLogSheet(
              api: _api,
              subscription: subscription,
              files: response.data ?? const [],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(_errorText(error), error: true);
    }
  }

  Widget _buildHeader(ColorScheme cs) {
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
                onPressed: _busyId == null
                    ? () => Navigator.pop(context)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '订阅管理',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '管理仓库、文件订阅和定时同步任务',
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
                tooltip: '创建订阅',
                onPressed: _busyId == null ? () => _openForm() : null,
              ),
              const SizedBox(width: 8),
              _headerAction(
                cs: cs,
                icon: Icons.refresh,
                tooltip: '刷新',
                onPressed: _busyId == null ? _load : null,
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

  Widget _buildSearch(ColorScheme cs) {
    return QlSettingsSearchField(
      controller: _searchController,
      hintText: '搜索订阅名称、链接或关键词',
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
      return QlErrorState(title: '订阅列表加载失败', message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return QlEmptyState(
        icon: Icons.sync_alt_outlined,
        title: '暂无订阅',
        subtitle: '点击右上角加号创建订阅',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _items.length,
      itemBuilder: (_, index) => _buildCard(cs, _items[index]),
    );
  }

  Widget _buildCard(ColorScheme cs, SubscriptionInfo subscription) {
    final busy = _busyId == subscription.id;
    final statusColor = _statusColor(cs, subscription);
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
          onTap: busy ? null : () => _showActions(subscription),
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
                    Icons.sync_alt_outlined,
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
                        subscription.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subscription.url,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 7,
                        runSpacing: 4,
                        children: [
                          _chip(cs.primary, subscription.typeLabel),
                          _chip(statusColor, subscription.statusLabel),
                          Text(
                            subscription.scheduleLabel,
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
                    : Icon(Icons.more_horiz, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(Color color, String label) => Container(
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

  Color _statusColor(ColorScheme cs, SubscriptionInfo subscription) {
    if (subscription.isDisabled == 1) return cs.outline;
    if (subscription.status == 0 || subscription.status == 3) return cs.primary;
    return Colors.green;
  }

  String _errorText(Object error) {
    final text = error.toString();
    return text.startsWith('Bad state: ') ? text.substring(11) : text;
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildHeader(cs),
        _buildSearch(cs),
        Expanded(child: RepaintBoundary(child: _buildBody(cs))),
      ],
    );
  }
}

Widget _actionItem(
  BuildContext context,
  IconData icon,
  String label,
  String value, {
  bool destructive = false,
}) {
  final cs = Theme.of(context).colorScheme;
  final color = destructive ? cs.error : cs.primary;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    child: Material(
      color: color.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(context, value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: color.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _sheetHandle(ColorScheme cs) => Center(
  child: Container(
    margin: const EdgeInsets.only(top: 12, bottom: 8),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: cs.onSurface.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(2),
    ),
  ),
);

class _SubscriptionFormSheet extends StatefulWidget {
  final SubscriptionInfo? initial;

  const _SubscriptionFormSheet({this.initial});

  @override
  State<_SubscriptionFormSheet> createState() => _SubscriptionFormSheetState();
}

class _SubscriptionFormSheetState extends State<_SubscriptionFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _branch;
  late final TextEditingController _alias;
  late final TextEditingController _schedule;
  late final TextEditingController _intervalValue;
  late final TextEditingController _whitelist;
  late final TextEditingController _blacklist;
  late final TextEditingController _dependences;
  late final TextEditingController _extensions;
  late final TextEditingController _subBefore;
  late final TextEditingController _subAfter;
  late final TextEditingController _proxy;
  late final TextEditingController _privateKey;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late String _type;
  late String _scheduleType;
  late String _intervalType;
  late String _pullType;
  late bool _autoAddCron;
  late bool _autoDelCron;
  bool _aliasLocked = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    _name = TextEditingController(text: item?.name ?? '');
    _url = TextEditingController(text: item?.url ?? '');
    _branch = TextEditingController(text: item?.branch ?? '');
    _alias = TextEditingController(text: item?.alias ?? '');
    _schedule = TextEditingController(text: item?.schedule ?? '');
    _intervalValue = TextEditingController(
      text: item?.intervalSchedule['value']?.toString() ?? '1',
    );
    _whitelist = TextEditingController(text: item?.whitelist ?? '');
    _blacklist = TextEditingController(text: item?.blacklist ?? '');
    _dependences = TextEditingController(text: item?.dependences ?? '');
    _extensions = TextEditingController(text: item?.extensions ?? '');
    _subBefore = TextEditingController(text: item?.subBefore ?? '');
    _subAfter = TextEditingController(text: item?.subAfter ?? '');
    _proxy = TextEditingController(text: item?.proxy ?? '');
    _privateKey = TextEditingController(
      text: item?.pullOption['private_key']?.toString() ?? '',
    );
    _username = TextEditingController(
      text: item?.pullOption['username']?.toString() ?? '',
    );
    _password = TextEditingController(
      text: item?.pullOption['password']?.toString() ?? '',
    );
    _type = item?.type ?? 'public-repo';
    _scheduleType = item?.scheduleType ?? 'crontab';
    _intervalType = item?.intervalSchedule['type']?.toString() ?? 'days';
    _pullType = item?.pullType ?? 'ssh-key';
    _autoAddCron = item?.autoAddCron != 0;
    _autoDelCron = item?.autoDelCron != 0;
    _aliasLocked = item?.alias.isNotEmpty ?? false;
    if (!_aliasLocked) _updateAlias();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _url,
      _branch,
      _alias,
      _schedule,
      _intervalValue,
      _whitelist,
      _blacklist,
      _dependences,
      _extensions,
      _subBefore,
      _subAfter,
      _proxy,
      _privateKey,
      _username,
      _password,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateAlias() {
    final raw = _url.text.trim();
    if (raw.isEmpty) {
      _alias.text = '';
      return;
    }
    var value = raw.split('?').first.split('#').first;
    value = value.replaceFirst(RegExp(r'\.git$'), '');
    final parts = value.split('/').where((part) => part.isNotEmpty).toList();
    if (_type == 'file') {
      value = parts.isEmpty ? value : parts.last;
      value = value.replaceFirst(RegExp(r'\.[^.]+$'), '');
    } else if (parts.length >= 2) {
      value = '${parts[parts.length - 2]}_${parts.last}';
    } else if (parts.isNotEmpty) {
      value = parts.last;
    }
    if (_branch.text.trim().isNotEmpty) value += '_${_branch.text.trim()}';
    _alias.text = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
  }

  Map<String, dynamic> _payload() {
    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'type': _type,
      'url': _url.text.trim(),
      'branch': _branch.text.trim(),
      'alias': _alias.text.trim(),
      'schedule_type': _scheduleType,
      'schedule': _scheduleType == 'crontab' ? _schedule.text.trim() : '',
      'interval_schedule': _scheduleType == 'interval'
          ? {
              'type': _intervalType,
              'value': int.tryParse(_intervalValue.text.trim()) ?? 1,
            }
          : null,
      'proxy': _proxy.text.trim(),
      'autoAddCron': _autoAddCron,
      'autoDelCron': _autoDelCron,
    };
    if (_type != 'file') {
      payload.addAll({
        'whitelist': _whitelist.text.trim(),
        'blacklist': _blacklist.text.trim(),
        'dependences': _dependences.text.trim(),
        'extensions': _extensions.text.trim(),
        'sub_before': _subBefore.text.trim(),
        'sub_after': _subAfter.text.trim(),
      });
    }
    if (_type == 'private-repo') {
      payload['pull_type'] = _pullType;
      payload['pull_option'] = _pullType == 'ssh-key'
          ? {'private_key': _privateKey.text}
          : {'username': _username.text.trim(), 'password': _password.text};
    }
    return payload;
  }

  bool _validate() {
    if (_name.text.trim().isEmpty) return false;
    if (_url.text.trim().isEmpty || _alias.text.trim().isEmpty) return false;
    if (_scheduleType == 'crontab' && _schedule.text.trim().isEmpty) {
      return false;
    }
    if (_scheduleType == 'interval' &&
        (int.tryParse(_intervalValue.text.trim()) ?? 0) < 1) {
      return false;
    }
    if (_type == 'private-repo') {
      if (_pullType == 'ssh-key' && _privateKey.text.trim().isEmpty) {
        return false;
      }
      if (_pullType == 'user-pwd' &&
          (_username.text.trim().isEmpty || _password.text.isEmpty)) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          _sheetHandle(cs),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
            child: Row(
              children: [
                Icon(
                  widget.initial == null ? Icons.add : Icons.edit_outlined,
                  color: cs.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.initial == null ? '创建订阅' : '编辑订阅',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _sectionTitle(cs, '基础信息'),
                _input(cs, '名称', _name, hint: '例如：我的脚本订阅'),
                _select(
                  cs,
                  '类型',
                  _type,
                  const {
                    'public-repo': '公开仓库',
                    'private-repo': '私有仓库',
                    'file': '单文件',
                  },
                  (value) {
                    setState(() {
                      _type = value;
                      if (value == 'file') _pullType = 'ssh-key';
                    });
                    if (!_aliasLocked) _updateAlias();
                  },
                ),
                _input(
                  cs,
                  '链接',
                  _url,
                  hint: _type == 'file'
                      ? '输入单个脚本文件链接'
                      : '输入 Git 仓库地址，例如 https://github.com/user/repo.git',
                  maxLines: 3,
                  onChanged: (_) {
                    if (!_aliasLocked) setState(_updateAlias);
                  },
                ),
                if (_type != 'file')
                  _input(
                    cs,
                    '分支',
                    _branch,
                    hint: '留空使用默认分支',
                    onChanged: (_) {
                      if (!_aliasLocked) setState(_updateAlias);
                    },
                  ),
                _input(cs, '唯一值', _alias, hint: '根据链接自动生成', readOnly: true),
                _sectionTitle(cs, '定时规则'),
                _select(
                  cs,
                  '定时类型',
                  _scheduleType,
                  const {'crontab': 'crontab', 'interval': 'interval'},
                  (value) => setState(() => _scheduleType = value),
                ),
                if (_scheduleType == 'crontab')
                  _input(cs, 'Cron 表达式', _schedule, hint: '秒 分 时 天 月 周')
                else ...[
                  _input(
                    cs,
                    '间隔数量',
                    _intervalValue,
                    hint: '例如：1',
                    keyboardType: TextInputType.number,
                  ),
                  _select(
                    cs,
                    '间隔单位',
                    _intervalType,
                    const {
                      'days': '天',
                      'hours': '时',
                      'minutes': '分',
                      'seconds': '秒',
                    },
                    (value) => setState(() => _intervalType = value),
                  ),
                ],
                if (_type == 'private-repo') ...[
                  _sectionTitle(cs, '私有仓库认证'),
                  _select(cs, '拉取方式', _pullType, const {
                    'ssh-key': '私钥',
                    'user-pwd': '用户名 / Token',
                  }, (value) => setState(() => _pullType = value)),
                  if (_pullType == 'ssh-key')
                    _input(
                      cs,
                      '私钥',
                      _privateKey,
                      hint: '粘贴 SSH 私钥内容',
                      maxLines: 5,
                    )
                  else ...[
                    _input(cs, '用户名', _username, hint: '认证用户名'),
                    _input(
                      cs,
                      '密码 / Token',
                      _password,
                      hint: 'Github 请使用 Token',
                      obscureText: true,
                    ),
                  ],
                ],
                if (_type != 'file') ...[
                  _sectionTitle(cs, '脚本筛选和命令'),
                  _input(
                    cs,
                    '白名单',
                    _whitelist,
                    hint: '多个关键词使用竖线分隔，支持正则',
                    maxLines: 3,
                  ),
                  _input(
                    cs,
                    '黑名单',
                    _blacklist,
                    hint: '多个关键词使用竖线分隔，支持正则',
                    maxLines: 3,
                  ),
                  _input(
                    cs,
                    '依赖文件',
                    _dependences,
                    hint: '多个关键词使用竖线分隔，支持正则',
                    maxLines: 3,
                  ),
                  _input(cs, '文件后缀', _extensions, hint: '例如：.js .py .sh'),
                  _input(
                    cs,
                    '执行前',
                    _subBefore,
                    hint: '运行订阅前执行的命令',
                    maxLines: 3,
                  ),
                  _input(cs, '执行后', _subAfter, hint: '运行订阅后执行的命令', maxLines: 3),
                ],
                _sectionTitle(cs, '其他设置'),
                _input(
                  cs,
                  '代理',
                  _proxy,
                  hint: 'HTTP/SOCK5，例如 http://127.0.0.1:1080',
                ),
                _switchSetting(
                  cs,
                  '自动添加任务',
                  '订阅脚本同步后自动创建定时任务',
                  _autoAddCron,
                  (value) => setState(() => _autoAddCron = value),
                ),
                _switchSetting(
                  cs,
                  '自动删除任务',
                  '删除订阅脚本时同步删除关联任务',
                  _autoDelCron,
                  (value) => setState(() => _autoDelCron = value),
                ),
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
                      onPressed: () {
                        if (_validate()) {
                          Navigator.pop(context, _payload());
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请完善必填信息')),
                          );
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('保存'),
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

  Widget _sectionTitle(ColorScheme cs, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _input(
    ColorScheme cs,
    String label,
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    bool readOnly = false,
    bool obscureText = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        obscureText: obscureText,
        maxLines: obscureText ? 1 : maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          floatingLabelStyle: TextStyle(color: cs.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        ),
      ),
    );
  }

  Widget _select(
    ColorScheme cs,
    String label,
    String value,
    Map<String, String> values,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
        items: values.entries
            .map(
              (entry) => DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }

  Widget _switchSetting(
    ColorScheme cs,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: cs.primary,
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _SubscriptionLogSheet extends StatefulWidget {
  final QingLongApi api;
  final SubscriptionInfo subscription;
  final List<TaskLogFile> files;

  const _SubscriptionLogSheet({
    required this.api,
    required this.subscription,
    required this.files,
  });

  @override
  State<_SubscriptionLogSheet> createState() => _SubscriptionLogSheetState();
}

class _SubscriptionLogSheetState extends State<_SubscriptionLogSheet> {
  TaskLogFile? _selected;
  String _content = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.files.isNotEmpty) {
      _selected = widget.files.first;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLatest());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLatest());
    }
  }

  Future<void> _loadLatest() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final response = _selected == null
          ? await widget.api.getSubscriptionLog(widget.subscription.id)
          : await widget.api.getLogDetail(
              _selected!.filename,
              _selected!.directory,
            );
      if (!mounted) return;
      setState(() => _content = response.data ?? '');
    } catch (error) {
      if (mounted) setState(() => _content = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          _sheetHandle(cs),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.subscription.name} 日志',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '刷新日志',
                  onPressed: _loading ? null : _loadLatest,
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
          if (widget.files.isNotEmpty)
            SizedBox(
              height: 92,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                scrollDirection: Axis.horizontal,
                itemCount: widget.files.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final file = widget.files[index];
                  final selected = file.key == _selected?.key;
                  return Material(
                    color: cs.primary.withValues(alpha: selected ? 0.14 : 0.07),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: cs.primary.withValues(
                          alpha: selected ? 0.42 : 0.24,
                        ),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() => _selected = file);
                        _loadLatest();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Center(
                          child: Text(
                            file.filename,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
              ),
              child: _loading
                  ? const Center(child: LoadingIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: SelectableText(
                        _content.isEmpty ? '暂无日志内容' : _content,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.5,
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

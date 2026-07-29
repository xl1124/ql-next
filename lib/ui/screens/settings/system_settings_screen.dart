import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/local/file_transfer_service.dart';
import 'package:qinglong_flutter/data/models/models.dart';
import 'package:qinglong_flutter/theme/app_visuals.dart';
import 'package:qinglong_flutter/ui/components/shared_components.dart';

class SystemSettingsScreen extends StatefulWidget {
  final QingLongApi? api;

  const SystemSettingsScreen({super.key, this.api});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  late final QingLongApi _api;
  final _logFrequencyController = TextEditingController();
  final _concurrencyController = TextEditingController();
  final _proxyController = TextEditingController();
  final _pythonMirrorController = TextEditingController();
  final _nodeMirrorController = TextEditingController();
  final _linuxMirrorController = TextEditingController();
  final _timezoneController = TextEditingController();
  final _panelTitleController = TextEditingController();
  final _sshKeyController = TextEditingController();

  SystemHealth? _health;
  SystemUpdateInfo? _updateInfo;
  bool _loading = true;
  bool _healthLoading = false;
  bool _checkingUpdate = false;
  bool _saving = false;
  bool _updating = false;
  bool _reloading = false;
  bool _obscureSshKey = true;
  String? _error;
  String _language = 'zh';

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? QingLongApi.auth();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _logFrequencyController,
      _concurrencyController,
      _proxyController,
      _pythonMirrorController,
      _nodeMirrorController,
      _linuxMirrorController,
      _timezoneController,
      _panelTitleController,
      _sshKeyController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.getSystemConfig();
      final config = response.data;
      if (response.code >= 400 || config == null) {
        throw StateError(response.message ?? '系统配置为空');
      }
      _applyConfig(config);
      if (mounted) setState(() => _loading = false);
      await _loadHealth();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _applyConfig(SystemConfig config) {
    _language = config.lang.isEmpty ? 'zh' : config.lang;
    _logFrequencyController.text = config.logRemoveFrequency?.toString() ?? '';
    _concurrencyController.text = config.cronConcurrency?.toString() ?? '';
    _proxyController.text = config.dependenceProxy;
    _pythonMirrorController.text = config.pythonMirror;
    _nodeMirrorController.text = config.nodeMirror;
    _linuxMirrorController.text = config.linuxMirror;
    _timezoneController.text = config.timezone;
    _panelTitleController.text = config.panelTitle;
    _sshKeyController.text = config.globalSshKey;
  }

  Future<void> _loadHealth() async {
    if (!mounted) return;
    setState(() => _healthLoading = true);
    try {
      final response = await _api.getHealth();
      if (!mounted) return;
      setState(() {
        _health = response.data;
        _healthLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _healthLoading = false);
      _showMessage('健康检查失败: $e');
    }
  }

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final response = await _api.checkSystemUpdate();
      if (response.code >= 400 || response.data == null) {
        throw StateError(response.message ?? '版本检查失败');
      }
      if (!mounted) return;
      setState(() {
        _updateInfo = response.data;
        _checkingUpdate = false;
      });
      _showMessage(
        response.data!.hasNewVersion
            ? '发现新版本 ${response.data!.lastVersion}'
            : '当前已是最新版本',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingUpdate = false);
      _showMessage('检查更新失败: $e');
    }
  }

  Future<void> _updateSystem() async {
    if (_updating || _reloading) return;
    final confirmed = await _confirmDangerousAction(
      title: '确认更新青龙',
      message: '更新期间后端会暂时中断，正在运行的任务可能受到影响。确定开始更新吗？',
      confirmText: '开始更新',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _updating = true);
    try {
      final response = await _api.updateSystem();
      if (response.code >= 400) {
        throw StateError(response.message ?? '更新请求被服务器拒绝');
      }
      if (!mounted) return;
      setState(() => _updating = false);
      _showMessage('更新任务已启动，请等待后端恢复');
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
      _showMessage('启动更新失败: $e');
    }
  }

  Future<void> _reloadSystem() async {
    if (_updating || _reloading) return;
    final confirmed = await _confirmDangerousAction(
      title: '确认重载后端',
      message: '重载会立即结束当前连接，正在运行的任务可能受到影响。确定继续吗？',
      confirmText: '重载后端',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _reloading = true);
    try {
      final response = await _api.reloadSystem();
      if (response.code >= 400) {
        throw StateError(response.message ?? '重载请求被服务器拒绝');
      }
      if (!mounted) return;
      setState(() => _reloading = false);
      _showMessage('后端正在重载，连接恢复后可重新检查健康状态');
    } catch (e) {
      if (!mounted) return;
      setState(() => _reloading = false);
      _showMessage('启动重载失败: $e');
    }
  }

  Future<bool?> _confirmDangerousAction({
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _saveRequest(
        _api.updateLogRemoveFrequency(_intValue(_logFrequencyController)),
      );
      await _saveRequest(
        _api.updateCronConcurrency(_intValue(_concurrencyController)),
      );
      await _saveRequest(
        _api.updateDependenceProxy(_proxyController.text.trim()),
      );
      await _saveRequest(
        _api.updatePythonMirror(_pythonMirrorController.text.trim()),
      );
      await _saveRequest(_api.updateTimezone(_timezoneController.text.trim()));
      await _saveRequest(_api.updateLanguage(_language));
      await _saveRequest(
        _api.updatePanelTitle(_panelTitleController.text.trim()),
      );
      await _saveRequest(_api.updateGlobalSshKey(_sshKeyController.text));
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('服务器设置已保存');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('保存失败: $e');
    }
  }

  Future<void> _saveRequest(Future<QingLongResponse<dynamic>> request) async {
    final response = await request;
    if (response.code >= 400) {
      throw StateError(response.message ?? '服务器拒绝了配置更新');
    }
  }

  int? _intValue(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : int.tryParse(value);
  }

  Future<void> _exportData() async {
    try {
      final bytes = await _api.exportSystemData();
      final path = await FileTransferService.saveFile(
        fileName: 'qinglong-data.tgz',
        bytes: bytes,
      );
      if (path != null && mounted) _showMessage('数据备份已保存');
    } catch (e) {
      if (mounted) _showMessage('导出失败: $e');
    }
  }

  Future<void> _importData() async {
    try {
      final file = await FileTransferService.pickFile(
        allowedExtensions: ['tgz', 'gz'],
      );
      if (file == null || file.bytes.isEmpty) return;
      final bytes = file.bytes;
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认导入数据'),
          content: const Text('导入会覆盖服务器上的部分数据，完成后需要重载青龙后端。确定继续吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('继续导入'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _api.importSystemData(
        filename: file.name.isEmpty ? 'data.tgz' : file.name,
        bytes: bytes,
      );
      if (mounted) _showMessage('数据导入完成，请重载青龙后端使其生效');
    } catch (e) {
      if (mounted) _showMessage('导入失败: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _buildHeader(cs),
          Expanded(
            child: _loading
                ? const LoadingIndicator()
                : _error != null
                ? _buildError()
                : _buildContent(),
          ),
        ],
      ),
    );
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
                onPressed: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '服务器设置',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '系统配置与维护',
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
                icon: Icons.system_update_outlined,
                tooltip: '检查更新',
                onPressed: _loading || _checkingUpdate ? null : _checkForUpdate,
                child: _checkingUpdate
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onSurface,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              _headerAction(
                cs: cs,
                icon: Icons.refresh,
                tooltip: '刷新配置和健康状态',
                onPressed: _loading ? null : _load,
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
    Widget? child,
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
            child: Center(
              child:
                  child ??
                  Icon(
                    icon,
                    size: 22,
                    color: cs.primary.withValues(alpha: enabled ? 1 : 0.42),
                  ),
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

  Widget _buildError() {
    return QlErrorState(
      title: '系统配置加载失败',
      message: _error ?? '未知错误',
      onRetry: _load,
      retryLabel: '重新加载',
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _groupTitle('系统配置', Icons.tune),
        _fieldCard(
          controller: _panelTitleController,
          label: '面板标题',
          icon: Icons.title,
          maxLength: 100,
        ),
        _card(_dropdown()),
        _fieldCard(
          controller: _timezoneController,
          label: '时区',
          icon: Icons.schedule,
          hint: '例如 Asia/Shanghai',
        ),
        const SizedBox(height: 12),
        _groupTitle('运行参数', Icons.speed),
        _fieldCard(
          controller: _logFrequencyController,
          label: '日志保留天数',
          icon: Icons.delete_sweep_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          hint: '留空表示交由后端默认策略处理',
        ),
        _fieldCard(
          controller: _concurrencyController,
          label: '任务并发数',
          icon: Icons.dynamic_feed_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        _groupTitle('依赖源', Icons.language),
        _fieldCard(
          controller: _proxyController,
          label: '依赖代理',
          icon: Icons.http_outlined,
          hint: '可留空，例如 http://127.0.0.1:7890',
        ),
        _fieldCard(
          controller: _pythonMirrorController,
          label: 'Python 镜像',
          icon: Icons.storage_outlined,
          hint: '可留空，使用后端默认源',
        ),
        _fieldCard(
          controller: _nodeMirrorController,
          label: 'Node.js 镜像',
          icon: Icons.lock_outline,
          hint: '后端异步维护',
          readOnly: true,
        ),
        _fieldCard(
          controller: _linuxMirrorController,
          label: 'Linux 镜像',
          icon: Icons.lock_outline,
          hint: '后端异步维护',
          readOnly: true,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
          child: Text(
            'Node.js 和 Linux 镜像由后端异步任务处理，当前版本提供读取状态。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _groupTitle('安全', Icons.key_outlined),
        _card(
          _textField(
            controller: _sshKeyController,
            label: '全局 SSH Key',
            icon: Icons.vpn_key_outlined,
            maxLines: 5,
            obscureText: _obscureSshKey,
            suffixIcon: IconButton(
              tooltip: _obscureSshKey ? '显示密钥' : '隐藏密钥',
              onPressed: () => setState(() => _obscureSshKey = !_obscureSshKey),
              icon: Icon(
                _obscureSshKey ? Icons.visibility : Icons.visibility_off,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildMaintenanceSection(),
        const SizedBox(height: 12),
        _buildHealthSection(),
        const SizedBox(height: 12),
        _buildDataSection(),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? '保存中' : '保存服务器设置'),
        ),
      ],
    );
  }

  Widget _groupTitle(String title, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 9),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.primary.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.primary.withValues(alpha: 0.24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }

  Widget _fieldCard({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    int? maxLength,
    bool obscureText = false,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return _card(
      _textField(
        controller: controller,
        label: label,
        icon: icon,
        hint: hint,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        maxLength: maxLength,
        obscureText: obscureText,
        readOnly: readOnly,
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildMaintenanceSection() {
    final info = _updateInfo;
    final hasUpdate = info?.hasNewVersion == true;
    return Column(
      children: [
        _groupTitle('版本与维护', Icons.build_circle_outlined),
        _card(
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  children: [
                    Icon(
                      hasUpdate
                          ? Icons.new_releases_outlined
                          : Icons.verified_outlined,
                      size: 20,
                      color: hasUpdate
                          ? Theme.of(context).colorScheme.tertiary
                          : Colors.green,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        info == null
                            ? '尚未检查更新'
                            : hasUpdate
                            ? '发现新版本 ${info.lastVersion}'
                            : '当前已是最新版本',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: '检查更新',
                      onPressed: _checkingUpdate ? null : _checkForUpdate,
                      icon: _checkingUpdate
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              if (hasUpdate && info?.lastLog.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    info!.lastLog,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: hasUpdate && !_updating && !_reloading
                          ? _updateSystem
                          : null,
                      icon: _updating
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.system_update_outlined),
                      label: Text(_updating ? '启动更新中' : '更新青龙'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _updating || _reloading ? null : _reloadSystem,
                      icon: _reloading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restart_alt),
                      label: Text(_reloading ? '重载中' : '重载后端'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    int? maxLength,
    bool obscureText = false,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        maxLines: obscureText ? 1 : maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _dropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<String>(
        value: _language,
        decoration: InputDecoration(
          labelText: '语言',
          prefixIcon: Icon(Icons.translate, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        items: const [
          DropdownMenuItem(value: 'zh', child: Text('中文')),
          DropdownMenuItem(value: 'en', child: Text('English')),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _language = value);
        },
      ),
    );
  }

  Widget _buildHealthSection() {
    final health = _health;
    return Column(
      children: [
        _groupTitle('健康检查', Icons.monitor_heart_outlined),
        _card(
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        health == null
                            ? '尚未获取状态'
                            : health.status == 'ok'
                            ? '服务运行正常'
                            : '服务存在异常',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: '重新检查',
                      onPressed: _healthLoading ? null : _loadHealth,
                      icon: _healthLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              if (health != null) ...[
                _healthRow('HTTP 服务', health.http),
                _healthRow('gRPC 服务', health.grpc),
                _infoLine(
                  Icons.timer_outlined,
                  '运行时长',
                  _formatUptime(health.uptime),
                ),
                _infoLine(
                  Icons.memory_outlined,
                  '内存',
                  '${_formatBytes(health.memoryUsed)} / ${_formatBytes(health.memoryTotal)}',
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _healthRow(String label, bool available) {
    final cs = Theme.of(context).colorScheme;
    return _infoLine(
      available ? Icons.check_circle_outline : Icons.error_outline,
      label,
      available ? '正常' : '异常',
      valueColor: available ? Colors.green : cs.error,
    );
  }

  Widget _infoLine(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(color: valueColor ?? cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection() {
    return Column(
      children: [
        _groupTitle('数据管理', Icons.archive_outlined),
        _actionRow(
          icon: Icons.file_upload_outlined,
          title: '导出数据',
          subtitle: '保存服务器数据备份文件',
          onPressed: _exportData,
        ),
        _actionRow(
          icon: Icons.file_download_outlined,
          title: '导入数据',
          subtitle: '从 .tgz 备份恢复服务器数据',
          onPressed: _importData,
        ),
      ],
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<void> Function() onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    return _card(
      Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 19, color: cs.primary),
          ),
          title: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          onTap: onPressed,
        ),
      ),
    );
  }

  String _formatUptime(int seconds) {
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remaining = seconds % 60;
    if (days > 0) return '$days天 $hours小时';
    if (hours > 0) return '$hours小时 $minutes分钟';
    if (minutes > 0) return '$minutes分钟 $remaining秒';
    return '$remaining秒';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

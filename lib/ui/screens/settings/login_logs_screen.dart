import 'package:flutter/material.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/models/models.dart';
import 'package:qinglong_flutter/ui/components/shared_components.dart';

class LoginLogsScreen extends StatefulWidget {
  const LoginLogsScreen({super.key});
  @override
  State<LoginLogsScreen> createState() => _LoginLogsScreenState();
}

class _LoginLogsScreenState extends State<LoginLogsScreen> {
  final _api = QingLongApi.auth();
  List<LoginLog> _logs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resp = await _api.getLoginLogs();
      if (!mounted) return;
      if (resp.code != 200 || resp.data == null) {
        throw StateError(resp.message ?? '读取登录日志失败');
      }
      setState(() {
        _logs = resp.data!;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(int? ts) {
    if (ts == null || ts <= 0) return '';
    // Qinglong stores milliseconds; keep compatibility with old second values.
    final milliseconds = ts < 100000000000 ? ts * 1000 : ts;
    final dt = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  bool _isSuccess(LoginLog log) {
    return log.status == 'success' || log.status == '200' || log.status == '0';
  }

  String _statusLabel(LoginLog log) {
    if (_isSuccess(log)) return '登录成功';
    if (log.status == 'fail' || log.status == '1') return '登录失败';
    return log.status ?? '未知状态';
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
                      '登录日志',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '最近登录记录',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _headerAction(
                cs,
                Icons.refresh,
                '刷新登录日志',
                _isLoading ? null : _load,
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildBody(ColorScheme cs) {
    if (_isLoading) return const LoadingIndicator();
    if (_error != null) {
      return QlErrorState(title: '登录日志加载失败', message: _error!, onRetry: _load);
    }
    if (_logs.isEmpty) {
      return const QlEmptyState(icon: Icons.history, title: '暂无登录日志');
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _logs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, index) => _buildLogCard(cs, _logs[index]),
      ),
    );
  }

  Widget _buildLogCard(ColorScheme cs, LoginLog log) {
    final success = _isSuccess(log);
    final statusColor = success ? cs.primary : cs.error;
    final radius = BorderRadius.circular(16);
    final timestamp = _formatTimestamp(log.timestamp);

    return Material(
      color: cs.primary.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: cs.primary.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    success ? Icons.check_circle_outline : Icons.error_outline,
                    size: 18,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    log.ip?.isNotEmpty == true ? log.ip! : '未知地址',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _statusLabel(log),
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (log.address?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                log.address!,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (log.platform?.isNotEmpty == true || timestamp.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (log.platform?.isNotEmpty == true)
                    _metaItem(cs, Icons.devices, log.platform!),
                  if (timestamp.isNotEmpty)
                    _metaItem(cs, Icons.access_time, timestamp),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaItem(ColorScheme cs, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
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
}

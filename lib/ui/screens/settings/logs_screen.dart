import 'package:flutter/material.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/local/file_transfer_service.dart';
import 'package:qinglong_flutter/data/models/models.dart';
import 'package:qinglong_flutter/theme/app_visuals.dart';
import 'package:qinglong_flutter/ui/components/shared_components.dart';

class LogsScreen extends StatefulWidget {
  final QingLongApi? api;

  const LogsScreen({super.key, this.api});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  late final QingLongApi _api;
  final _searchController = TextEditingController();
  List<LogFileEntry> _entries = const [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? QingLongApi.auth();
    _searchController.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (!mounted || _refreshing) return;
    setState(() {
      _loading = true;
      _refreshing = true;
      _error = null;
    });
    try {
      final response = await _api.getLogs();
      if (response.code != 200 || response.data == null) {
        throw StateError(response.message ?? '加载任务日志失败');
      }
      if (!mounted) return;
      setState(() {
        _entries = response.data!;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  List<LogFileEntry> _files() {
    final result = <LogFileEntry>[];

    void collect(List<LogFileEntry> entries) {
      for (final entry in entries) {
        if (entry.isFile) {
          result.add(entry);
        } else {
          collect(entry.children);
        }
      }
    }

    collect(_entries);
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? result
        : result
              .where(
                (entry) =>
                    entry.title.toLowerCase().contains(query) ||
                    entry.parent.toLowerCase().contains(query) ||
                    entry.key.toLowerCase().contains(query),
              )
              .toList();
    filtered.sort(_compareEntries);
    return filtered;
  }

  int _compareEntries(LogFileEntry left, LogFileEntry right) {
    final leftTime = left.createTime;
    final rightTime = right.createTime;
    if (leftTime != null && rightTime != null) {
      return rightTime.compareTo(leftTime);
    }
    if (leftTime != null) return -1;
    if (rightTime != null) return 1;
    return right.key.compareTo(left.key);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildHeader(cs),
        _buildSearch(cs),
        Expanded(child: _buildBody(cs)),
      ],
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Column(
      children: [
        const QlSheetHandle(),
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
                      '任务日志',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '查看所有任务的历史执行日志',
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
                '刷新任务日志',
                _refreshing ? null : _load,
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
      hintText: '搜索日志文件或任务路径',
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) return const LoadingIndicator();
    if (_error != null) {
      return QlErrorState(title: '任务日志加载失败', message: _error!, onRetry: _load);
    }

    final files = _files();
    if (files.isEmpty) {
      return const QlEmptyState(icon: Icons.article_outlined, title: '暂无任务日志');
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: files.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, index) => _buildLogCard(cs, files[index]),
      ),
    );
  }

  Widget _buildLogCard(ColorScheme cs, LogFileEntry entry) {
    return Material(
      color: cs.primary.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.primary.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetail(entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.description_outlined, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.parent.isEmpty ? entry.key : entry.parent,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: '下载日志',
                child: IconButton(
                  onPressed: () => _downloadLog(entry),
                  icon: const Icon(Icons.download_outlined),
                  color: cs.primary,
                ),
              ),
              Icon(Icons.chevron_right, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetail(LogFileEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: _LogDetailSheet(api: _api, entry: entry),
      ),
    );
  }

  Future<void> _downloadLog(LogFileEntry entry) async {
    try {
      final bytes = await _api.downloadLog(entry.title, entry.parent);
      final savedPath = await FileTransferService.saveFile(
        fileName: entry.title,
        bytes: bytes,
      );
      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('日志已保存')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('下载日志失败: $e')));
      }
    }
  }
}

class _LogDetailSheet extends StatefulWidget {
  final QingLongApi api;
  final LogFileEntry entry;

  const _LogDetailSheet({required this.api, required this.entry});

  @override
  State<_LogDetailSheet> createState() => _LogDetailSheetState();
}

class _LogDetailSheetState extends State<_LogDetailSheet> {
  String _content = '';
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await widget.api.getLogDetail(
        widget.entry.title,
        widget.entry.parent,
      );
      if (response.code != 200) {
        throw StateError(response.message ?? '加载日志内容失败');
      }
      if (!mounted) return;
      setState(() {
        _content = response.data ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppVisuals.glassSurface(
      context: context,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      withShadow: true,
      child: SafeArea(
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
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.24),
                    ),
                  ),
                  child: _loading
                      ? const Center(child: LoadingIndicator())
                      : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.error),
                          ),
                        )
                      : SingleChildScrollView(
                          child: SelectableText(
                            _content.isEmpty ? '暂无日志内容' : _content,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.5,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

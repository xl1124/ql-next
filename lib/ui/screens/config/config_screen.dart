import 'package:flutter/material.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/models/models.dart';
import 'package:qinglong_flutter/theme/app_visuals.dart';
import 'package:qinglong_flutter/ui/components/shared_components.dart';

class ConfigScreen extends StatefulWidget {
  final bool embedded;
  final QingLongApi? api;

  const ConfigScreen({super.key, this.embedded = false, this.api});
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late final QingLongApi _api;
  List<ConfigFileInfo> _files = [];
  bool _isLoading = true;
  bool _isViewingFile = false;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isOpeningFile = false;
  String? _error;
  String _selectedFile = '';
  String _fileContent = '';
  late TextEditingController _editCtl;
  Future<void>? _loadFilesInFlight;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? QingLongApi.auth();
    _editCtl = TextEditingController();
    _loadFiles();
  }

  @override
  void dispose() {
    _editCtl.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    final pending = _loadFilesInFlight;
    if (pending != null) return pending;

    final request = _loadFilesRequest();
    _loadFilesInFlight = request;
    try {
      await request;
    } finally {
      _loadFilesInFlight = null;
    }
  }

  Future<void> _loadFilesRequest() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resp = await _api.getConfigFiles();
      _ensureSuccess(resp.code, resp.message, '配置文件加载失败');
      if (resp.data == null) {
        throw StateError(resp.message ?? '配置文件加载失败');
      }
      _files = resp.data!;
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _errorText(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _openFile(String path) async {
    if (!mounted || _isOpeningFile) return;
    _isOpeningFile = true;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resp = await _api.getConfigDetail(path);
      _ensureSuccess(resp.code, resp.message, '配置文件读取失败');
      if (resp.data == null) {
        throw StateError(resp.message ?? '配置文件读取失败');
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
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
            child: _ConfigFileDetailSheet(
              api: _api,
              filename: path,
              initialContent: resp.data!,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    } finally {
      _isOpeningFile = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _ensureSuccess(int code, String? message, String fallback) {
    if (code >= 400) {
      throw StateError(message ?? fallback);
    }
  }

  String _errorText(Object error) {
    final text = error.toString();
    return text.startsWith('Bad state: ') ? text.substring(11) : text;
  }

  Widget _buildErrorState(ColorScheme cs) {
    return QlErrorState(
      title: '配置文件加载失败',
      message: _error ?? '未知错误',
      onRetry: _loadFiles,
      hint: '请检查服务器连接后重试',
    );
  }

  Widget _buildViewer(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: AppVisuals.glassSurface(
        context: context,
        borderRadius: BorderRadius.circular(18),
        withShadow: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _fileContent.isEmpty ? '# 暂无配置内容' : _fileContent,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: cs.onSurface,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: AppVisuals.glassSurface(
        context: context,
        borderRadius: BorderRadius.circular(18),
        withShadow: true,
        child: TextField(
          controller: _editCtl,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: cs.onSurface,
            height: 1.5,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(16),
          ),
        ),
      ),
    );
  }

  void _startEdit() {
    _editCtl.text = _fileContent;
    setState(() => _isEditing = true);
  }

  void _cancelEdit() {
    setState(() => _isEditing = false);
    _editCtl.text = _fileContent;
  }

  void _goBack() {
    setState(() {
      _isViewingFile = false;
      _isEditing = false;
      _selectedFile = '';
      _fileContent = '';
      _error = null;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _api.saveConfig(_selectedFile, _editCtl.text);
      if (!mounted) return;
      _fileContent = _editCtl.text;
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('配置保存成功')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

  Widget _buildHeader(ColorScheme cs) {
    final title = _isViewingFile
        ? (_isEditing ? '编辑配置文件' : _selectedFile)
        : '配置文件';
    final subtitle = _isViewingFile
        ? (_isEditing ? '编辑并保存当前配置' : '查看配置文件内容')
        : '管理 config.sh 等配置文件';
    final canClose = !_isViewingFile && Navigator.canPop(context);

    return Column(
      children: [
        _sheetHandle(cs),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
          child: Row(
            children: [
              _headerAction(
                cs,
                canClose ? Icons.close : Icons.arrow_back,
                canClose ? '关闭' : '返回配置文件列表',
                canClose
                    ? () => Navigator.pop(context)
                    : (_isViewingFile ? _goBack : null),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppVisuals.palette(context).textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              if (_isViewingFile && _isEditing) ...[
                _headerAction(
                  cs,
                  Icons.close,
                  '取消编辑',
                  _isSaving ? null : _cancelEdit,
                ),
                const SizedBox(width: 8),
                _headerAction(
                  cs,
                  Icons.save_outlined,
                  '保存配置',
                  _isSaving ? null : _save,
                ),
              ] else if (_isViewingFile) ...[
                _headerAction(
                  cs,
                  Icons.refresh,
                  '重新加载文件',
                  _isLoading ? null : () => _openFile(_selectedFile),
                ),
                const SizedBox(width: 8),
                _headerAction(cs, Icons.edit_outlined, '编辑配置', _startEdit),
              ] else ...[
                _headerAction(
                  cs,
                  Icons.refresh,
                  '刷新配置文件',
                  _isLoading ? null : _loadFiles,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody(ColorScheme cs) {
    return _isLoading
        ? const LoadingIndicator()
        : _error != null && !_isViewingFile
        ? _buildErrorState(cs)
        : _isViewingFile
        ? _isEditing
              ? _buildEditor(cs)
              : _buildViewer(cs)
        : _files.isEmpty
        ? const QlEmptyState(
            icon: Icons.description_outlined,
            title: '暂无配置文件',
            subtitle: '服务器没有返回可编辑的配置文件',
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: _files.length,
            itemBuilder: (_, i) {
              final file = _files[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: cs.primary.withValues(alpha: 0.07),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.primary.withValues(alpha: 0.24)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openFile(file.value),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                Icons.description_outlined,
                                size: 18,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    file.title,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (file.value != file.title) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      file.value,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.chevron_right,
                              size: 22,
                              color: cs.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final body = _buildBody(cs);

    if (widget.embedded) {
      return Column(
        children: [
          _buildHeader(cs),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(MediaQuery.of(context).padding.top + 60),
        child: QlTopBar(
          title: _isViewingFile
              ? (_isEditing ? '编辑: $_selectedFile' : _selectedFile)
              : '配置文件',
          leading: _isViewingFile
              ? _headerAction(cs, Icons.arrow_back, '返回配置文件列表', _goBack)
              : null,
          trailing: [
            if (_isViewingFile && _isEditing) ...[
              _headerAction(
                cs,
                Icons.close,
                '取消编辑',
                _isSaving ? null : _cancelEdit,
              ),
              _headerAction(
                cs,
                Icons.save_outlined,
                '保存配置',
                _isSaving ? null : _save,
              ),
            ] else if (_isViewingFile) ...[
              _headerAction(
                cs,
                Icons.refresh,
                '重新加载文件',
                _isLoading ? null : () => _openFile(_selectedFile),
              ),
              _headerAction(cs, Icons.edit_outlined, '编辑配置', _startEdit),
            ] else ...[
              _headerAction(
                cs,
                Icons.refresh,
                '刷新配置文件',
                _isLoading ? null : _loadFiles,
              ),
            ],
          ],
        ),
      ),
      body: body,
    );
  }
}

class _ConfigFileDetailSheet extends StatefulWidget {
  final QingLongApi api;
  final String filename;
  final String initialContent;

  const _ConfigFileDetailSheet({
    required this.api,
    required this.filename,
    required this.initialContent,
  });

  @override
  State<_ConfigFileDetailSheet> createState() => _ConfigFileDetailSheetState();
}

class _ConfigFileDetailSheetState extends State<_ConfigFileDetailSheet> {
  late final TextEditingController _controller;
  late String _content;
  bool _editing = false;
  bool _saving = false;
  bool _loading = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _content = widget.initialContent;
    _controller = TextEditingController(text: _content);
    _controller.addListener(_updateDirtyState);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateDirtyState);
    _controller.dispose();
    super.dispose();
  }

  void _updateDirtyState() {
    final dirty = _editing && _controller.text != _content;
    if (dirty == _isDirty || !mounted) return;
    setState(() => _isDirty = dirty);
  }

  Future<void> _reload() async {
    if (_loading || _saving || _isDirty) return;
    setState(() => _loading = true);
    try {
      final response = await widget.api.getConfigDetail(widget.filename);
      if (response.code != 200) {
        throw StateError(response.message ?? '重新加载配置失败');
      }
      if (!mounted) return;
      setState(() {
        _content = response.data ?? '';
        _editing = false;
        _isDirty = false;
        _controller.text = _content;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(_errorText(error), error: true);
    }
  }

  Future<void> _save() async {
    if (_saving || !_editing) return;
    final contentToSave = _controller.text;
    setState(() => _saving = true);
    try {
      final response = await widget.api.saveConfig(
        widget.filename,
        contentToSave,
      );
      if (response.code != 200) {
        throw StateError(response.message ?? '保存配置失败');
      }
      if (!mounted) return;
      setState(() {
        _content = contentToSave;
        _editing = false;
        _isDirty = false;
        _controller.text = contentToSave;
        _saving = false;
      });
      _showMessage('配置保存成功');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(_errorText(error), error: true);
    }
  }

  void _startEdit() {
    _controller.text = _content;
    setState(() => _editing = true);
    _updateDirtyState();
  }

  Future<void> _cancelEdit() async {
    if (_saving) return;
    if (_isDirty && !await _confirmDiscardChanges()) return;
    if (!mounted) return;
    setState(() {
      _editing = false;
      _isDirty = false;
      _controller.text = _content;
    });
  }

  Future<bool> _requestClose() async {
    if (_saving) return false;
    if (_isDirty && !await _confirmDiscardChanges()) return false;
    if (mounted) Navigator.pop(context);
    return true;
  }

  Future<bool> _confirmDiscardChanges() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AppVisuals.glassSurface(
          context: ctx,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          withShadow: true,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _sheetHandle(cs)),
                  const SizedBox(height: 10),
                  Text(
                    '放弃未保存的修改？',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '当前配置内容尚未保存，关闭后这些修改将丢失。',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: const Icon(Icons.close),
                          label: const Text('继续编辑'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pop(ctx, true),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('放弃修改'),
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.error,
                            foregroundColor: cs.onError,
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
    );
    return result == true;
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
    return PopScope(
      canPop: !_saving && !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: SafeArea(
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
                    _saving ? null : () => _requestClose(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editing ? '编辑配置文件' : widget.filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _editing ? '编辑并保存当前配置' : '查看配置文件内容',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_editing) ...[
                    _headerAction(
                      cs,
                      Icons.close,
                      '取消编辑',
                      _saving ? null : () => _cancelEdit(),
                    ),
                    const SizedBox(width: 8),
                    _headerAction(
                      cs,
                      Icons.save_outlined,
                      '保存配置',
                      _saving ? null : _save,
                    ),
                  ] else ...[
                    _headerAction(
                      cs,
                      Icons.refresh,
                      '重新加载文件',
                      _loading ? null : _reload,
                    ),
                    const SizedBox(width: 8),
                    _headerAction(cs, Icons.edit_outlined, '编辑配置', _startEdit),
                  ],
                ],
              ),
            ),
            Expanded(child: _editing ? _buildEditor(cs) : _buildViewer(cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildViewer(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: AppVisuals.glassSurface(
        context: context,
        borderRadius: BorderRadius.circular(18),
        withShadow: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _content.isEmpty ? '# 暂无配置内容' : _content,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: cs.onSurface,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: AppVisuals.glassSurface(
        context: context,
        borderRadius: BorderRadius.circular(18),
        withShadow: true,
        child: TextField(
          controller: _controller,
          readOnly: _saving,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: cs.onSurface,
            height: 1.5,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(16),
          ),
        ),
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
}

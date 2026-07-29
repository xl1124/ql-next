import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/local/file_transfer_service.dart';
import 'package:qinglong_flutter/data/models/models.dart';
import 'package:qinglong_flutter/theme/app_visuals.dart';
import 'package:qinglong_flutter/ui/components/shared_components.dart';

class ScriptScreen extends StatefulWidget {
  const ScriptScreen({super.key});

  @override
  State<ScriptScreen> createState() => _ScriptScreenState();
}

class _ScriptScreenState extends State<ScriptScreen> {
  final _api = QingLongApi.auth();
  late final _ScriptCodeController _editor;
  late final ScrollController _codeScroll;
  late final ScrollController _lineScroll;
  List<ScriptFile> _items = [];
  String _path = '';
  String _content = '';
  ScriptFile? _currentFile;
  bool _loading = true;
  bool _viewing = false;
  bool _editing = false;
  bool _saving = false;
  bool _uploading = false;
  bool _running = false;
  int? _pid;
  String? _error;

  @override
  void initState() {
    super.initState();
    _editor = _ScriptCodeController();
    _codeScroll = ScrollController()..addListener(_syncLineScroll);
    _lineScroll = ScrollController();
    _loadDirectory();
  }

  @override
  void dispose() {
    _editor.dispose();
    _codeScroll
      ..removeListener(_syncLineScroll)
      ..dispose();
    _lineScroll.dispose();
    super.dispose();
  }

  void _syncLineScroll() {
    if (!_lineScroll.hasClients) return;
    final offset = _codeScroll.offset.clamp(
      0.0,
      _lineScroll.position.maxScrollExtent,
    );
    if ((_lineScroll.offset - offset).abs() > 0.5) {
      _lineScroll.jumpTo(offset);
    }
  }

  Future<void> _loadDirectory({bool showLoading = true}) async {
    if (!mounted) return;
    setState(() {
      if (showLoading) _loading = true;
      _error = null;
    });
    try {
      final response = await _api.getScripts(path: _path);
      if (!mounted) return;
      setState(() {
        _items = response.data ?? [];
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

  Future<void> _openFile(ScriptFile file) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.getScriptDetail(
        filename: file.title,
        path: _path,
      );
      if (!mounted) return;
      _content = response.data ?? '';
      _editor.text = _content;
      setState(() {
        _currentFile = file;
        _viewing = true;
        _editing = false;
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

  void _goBack() {
    if (_viewing) {
      setState(() {
        _viewing = false;
        _editing = false;
        _currentFile = null;
        _content = '';
        _error = null;
      });
      return;
    }

    if (_path.isNotEmpty) {
      final index = _path.lastIndexOf('/');
      setState(() {
        _path = index == -1 ? '' : _path.substring(0, index);
      });
      _loadDirectory();
      return;
    }

    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  String _joinPath(String name) => _path.isEmpty ? name : '$_path/$name';

  Future<void> _save() async {
    final file = _currentFile;
    if (file == null || _saving) return;
    setState(() => _saving = true);
    try {
      final nextContent = _editor.text;
      await _api.saveScript(
        filename: file.title,
        path: _path,
        content: nextContent,
      );
      if (!mounted) return;
      setState(() {
        _content = nextContent;
        _editing = false;
        _saving = false;
      });
      _showMessage('脚本保存成功');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('保存失败: $e');
    }
  }

  Future<void> _run() async {
    final file = _currentFile;
    if (file == null || _running) return;
    try {
      final response = await _api.runScript(
        filename: file.title,
        path: _path,
        content: _editing ? _editor.text : _content,
      );
      if (!mounted) return;
      setState(() {
        _running = true;
        _pid = int.tryParse(response.data?.toString() ?? '');
      });
      _showMessage('脚本已开始运行');
    } catch (e) {
      if (mounted) _showMessage('运行失败: $e');
    }
  }

  Future<void> _stop() async {
    final file = _currentFile;
    if (file == null) return;
    try {
      await _api.stopScript(filename: file.title, path: _path, pid: _pid);
      if (!mounted) return;
      setState(() {
        _running = false;
        _pid = null;
      });
      _showMessage('脚本已停止');
    } catch (e) {
      if (mounted) _showMessage('停止失败: $e');
    }
  }

  Future<void> _downloadScript(ScriptFile file) async {
    if (file.isDirectory) return;
    try {
      final bytes = await _api.downloadScript(
        filename: file.title,
        path: _path,
      );
      final savedPath = await FileTransferService.saveFile(
        fileName: file.title,
        bytes: bytes,
      );
      if (savedPath != null && mounted) {
        _showMessage('脚本已保存');
      }
    } catch (e) {
      if (mounted) _showMessage('下载脚本失败: $e');
    }
  }

  Future<void> _deleteItem(ScriptFile file) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScriptDeleteSheet(
        title: file.isDirectory ? '删除目录' : '删除脚本',
        message: file.isDirectory
            ? '确定删除「${file.title}」及其全部内容吗？删除后无法恢复。'
            : '确定删除「${file.title}」吗？删除后无法恢复。',
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deleteScript(
        filename: file.title,
        path: _path,
        type: file.type,
      );
      if (!mounted) return;
      _showMessage('删除成功');
      await _loadDirectory();
    } catch (e) {
      if (mounted) _showMessage('删除失败: $e');
    }
  }

  Future<void> _renameItem(ScriptFile file) async {
    final newName = await _showNameSheet(
      title: '重命名${file.isDirectory ? '目录' : '脚本'}',
      initial: file.title,
      hint: '输入新的名称',
    );
    if (newName == null || newName.trim().isEmpty || !mounted) return;
    if (newName.trim() == file.title) return;
    try {
      await _api.renameScript(
        filename: file.title,
        newFilename: newName.trim(),
        path: _path,
      );
      if (!mounted) return;
      _showMessage('重命名成功');
      await _loadDirectory();
    } catch (e) {
      if (mounted) _showMessage('重命名失败: $e');
    }
  }

  Future<void> _createItem([String? presetType]) async {
    final type =
        presetType ??
        await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => const _ScriptCreateSheet(),
        );
    if (type == null || !mounted) return;
    final name = await _showNameSheet(
      title: type == 'file' ? '新建脚本' : '新建目录',
      hint: type == 'file' ? '例如：example.js' : '输入目录名称',
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      if (type == 'file') {
        await _api.createScript(
          filename: name.trim(),
          path: _path,
          content: '',
        );
      } else {
        await _api.createScriptDirectory(directory: name.trim(), path: _path);
      }
      if (!mounted) return;
      _showMessage(type == 'file' ? '脚本创建成功' : '目录创建成功');
      await _loadDirectory();
    } catch (e) {
      if (mounted) _showMessage('创建失败: $e');
    }
  }

  Future<_PickedScript?> _pickScriptFile() async {
    try {
      final result = await FileTransferService.pickFile();
      if (result == null || !mounted) return null;
      return _PickedScript(filename: result.name, bytes: result.bytes);
    } on PlatformException catch (e) {
      if (mounted) _showMessage('选择文件失败: ${e.message ?? e.code}');
      return null;
    }
  }

  Future<void> _uploadScript() async {
    if (_uploading) return;
    final picked = await showModalBottomSheet<_PickedScript>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScriptUploadSheet(onPick: _pickScriptFile),
    );
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await _api.uploadScriptFile(
        filename: picked.filename,
        bytes: picked.bytes,
        path: _path,
      );
      if (!mounted) return;
      setState(() => _uploading = false);
      _showMessage('脚本上传成功');
      await _loadDirectory();
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _showMessage('上传失败: $e');
    }
  }

  Future<String?> _showNameSheet({
    required String title,
    required String hint,
    String initial = '',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ScriptNameSheet(title: title, hint: hint, initial: initial),
    );
  }

  Future<void> _showCreateActions() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ScriptCreateSheet(includeUpload: true),
    );
    if (type == null || !mounted) return;
    if (type == 'upload') {
      await _uploadScript();
    } else {
      await _createItem(type);
    }
  }

  Future<void> _showFileActions(ScriptFile file) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScriptFileActionsSheet(file: file),
    );
    if (action == null || !mounted) return;
    if (action == 'rename') {
      await _renameItem(file);
    } else if (action == 'delete') {
      await _deleteItem(file);
    } else if (action == 'download') {
      await _downloadScript(file);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        const QlSheetHandle(),
        _buildHeader(cs),
        Expanded(
          child: _loading
              ? const LoadingIndicator()
              : _error != null
              ? _buildError(cs)
              : _viewing
              ? _editing
                    ? _buildEditor(cs)
                    : _buildViewer(cs)
              : _items.isEmpty
              ? const QlEmptyState(
                  icon: Icons.folder_open_outlined,
                  title: '暂无脚本',
                  subtitle: '当前目录没有脚本文件，点击右上角加号新建或上传',
                )
              : _buildDirectory(cs),
        ),
      ],
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    final title = _viewing ? _currentFile?.title ?? '脚本' : '脚本管理';
    final subtitle = _viewing
        ? (_path.isEmpty ? 'scripts' : 'scripts/$_path')
        : (_path.isEmpty ? 'scripts' : 'scripts/$_path');
    final canGoBack = _viewing || _path.isNotEmpty || Navigator.canPop(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outline.withValues(alpha: 0.16)),
        ),
      ),
      child: Row(
        children: [
          if (canGoBack)
            _headerAction(
              cs: cs,
              icon: Icons.arrow_back,
              tooltip: _viewing || _path.isEmpty ? '返回' : '返回上一级目录',
              onPressed: _goBack,
            )
          else
            const SizedBox(width: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _buildActionRow(cs),
        ],
      ),
    );
  }

  Widget _buildActionRow(ColorScheme cs) {
    final actions = _buildActions(cs);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          actions[index],
        ],
      ],
    );
  }

  List<Widget> _buildActions(ColorScheme cs) {
    if (_viewing) {
      return [
        _headerAction(
          cs: cs,
          icon: _running ? Icons.stop_circle_outlined : Icons.play_arrow,
          color: _running ? cs.error : cs.primary,
          tooltip: _running ? '停止脚本' : '运行脚本',
          onPressed: _running ? _stop : _run,
        ),
        if (_editing) ...[
          _headerAction(
            cs: cs,
            icon: Icons.close,
            tooltip: '取消编辑',
            onPressed: _saving
                ? null
                : () => setState(() {
                    _editing = false;
                    _editor.text = _content;
                  }),
          ),
          _headerAction(
            cs: cs,
            icon: Icons.save_outlined,
            tooltip: '保存脚本',
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  )
                : null,
          ),
        ] else ...[
          _headerAction(
            cs: cs,
            icon: Icons.edit_outlined,
            tooltip: '编辑脚本',
            onPressed: () => setState(() {
              _editor.text = _content;
              _editing = true;
            }),
          ),
          _headerAction(
            cs: cs,
            icon: Icons.more_horiz,
            tooltip: '脚本操作',
            onPressed: _currentFile == null
                ? null
                : () => _showFileActions(_currentFile!),
          ),
        ],
      ];
    }

    return [
      _headerAction(
        cs: cs,
        icon: Icons.refresh,
        tooltip: '刷新脚本列表',
        onPressed: _loading || _uploading ? null : _loadDirectory,
      ),
      _headerAction(
        cs: cs,
        icon: Icons.add,
        tooltip: '新建或上传',
        onPressed: _loading || _uploading ? null : _showCreateActions,
        child: _uploading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            : null,
      ),
    ];
  }

  Widget _headerAction({
    required ColorScheme cs,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? color,
    Widget? child,
  }) {
    final actionColor = color ?? cs.primary;
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: actionColor.withValues(alpha: enabled ? 0.07 : 0.04),
        shape: CircleBorder(
          side: BorderSide(
            color: actionColor.withValues(alpha: enabled ? 0.24 : 0.14),
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
                    color: actionColor.withValues(alpha: enabled ? 1 : 0.42),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(ColorScheme cs) {
    return QlErrorState(
      title: '脚本管理加载失败',
      message: _error ?? '未知错误',
      onRetry: _viewing ? () => _openFile(_currentFile!) : _loadDirectory,
    );
  }

  Widget _buildDirectory(ColorScheme cs) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _items.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.folder_open_outlined, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _path.isEmpty ? 'scripts' : 'scripts/$_path',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${_items.length} 项',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        final file = _items[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ScriptListItemSurface(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () =>
                    file.isDirectory ? _enterDirectory(file) : _openFile(file),
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
                          color: (file.isDirectory ? cs.tertiary : cs.primary)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          file.isDirectory
                              ? Icons.folder_outlined
                              : _fileIcon(file.title),
                          size: 19,
                          color: file.isDirectory ? cs.tertiary : cs.primary,
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
                            const SizedBox(height: 3),
                            Text(
                              file.isDirectory ? '目录' : _formatSize(file.size),
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _headerAction(
                        cs: cs,
                        icon: Icons.more_horiz,
                        tooltip: '更多操作',
                        onPressed: () => _showFileActions(file),
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

  void _enterDirectory(ScriptFile file) {
    setState(() => _path = _joinPath(file.title));
    _loadDirectory();
  }

  Widget _buildViewer(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: AppVisuals.glassSurface(
        context: context,
        borderRadius: BorderRadius.circular(18),
        withShadow: true,
        child: Column(
          children: [
            _codeSurfaceHeader(cs, Icons.visibility_outlined, '脚本内容'),
            Divider(height: 1, color: cs.outline.withValues(alpha: 0.16)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText.rich(
                    TextSpan(
                      children: _buildHighlightedDocument(
                        _content.isEmpty ? '# 暂无脚本内容' : _content,
                        cs,
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

  Widget _codeSurfaceHeader(ColorScheme cs, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            '行号',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
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
        child: Column(
          children: [
            _codeSurfaceHeader(cs, Icons.edit_outlined, '正在编辑'),
            Divider(height: 1, color: cs.outline.withValues(alpha: 0.16)),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _editor,
                    builder: (_, value, _) =>
                        _buildLineNumberGutter(cs, value.text),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _editor,
                      scrollController: _codeScroll,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.5,
                        color: cs.onSurface,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.fromLTRB(12, 16, 16, 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineNumberGutter(ColorScheme cs, String content) {
    final lineCount = '\n'.allMatches(content).length + 1;
    final width = lineCount.toString().length;
    final numbers = List.generate(
      lineCount,
      (index) => (index + 1).toString().padLeft(width),
    ).join('\n');
    return Container(
      width: 48,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
      child: SingleChildScrollView(
        controller: _lineScroll,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          numbers,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.5,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  List<TextSpan> _buildHighlightedDocument(String content, ColorScheme cs) {
    final lines = content.split('\n');
    final width = lines.length.toString().length;
    final spans = <TextSpan>[];
    for (var index = 0; index < lines.length; index++) {
      spans.add(
        TextSpan(
          text: '${(index + 1).toString().padLeft(width)} │ ',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.5,
            color: cs.onSurfaceVariant,
          ),
        ),
      );
      spans.addAll(_highlightLine(lines[index], cs));
      if (index < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }

  List<TextSpan> _highlightLine(String line, ColorScheme cs) =>
      _highlightCodeLine(line, cs);

  IconData _fileIcon(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.py')) return Icons.code;
    if (lower.endsWith('.sh')) return Icons.terminal;
    if (lower.endsWith('.json') || lower.endsWith('.yaml')) {
      return Icons.data_object;
    }
    return Icons.description_outlined;
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '脚本文件';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _PickedScript {
  final String filename;
  final List<int> bytes;

  const _PickedScript({required this.filename, required this.bytes});
}

class _ScriptCodeController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final cs = Theme.of(context).colorScheme;
    final lines = text.split('\n');
    final spans = <TextSpan>[];
    for (var index = 0; index < lines.length; index++) {
      spans.addAll(_highlightCodeLine(lines[index], cs));
      if (index < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return TextSpan(style: style, children: spans);
  }
}

List<TextSpan> _highlightCodeLine(String line, ColorScheme cs) {
  final pattern = RegExp(
    r'''(//.*|#.*|/\*.*?\*/|"(?:\\.|[^"])*"|'(?:\\.|[^'])*'|\b\d+(?:\.\d+)?\b|\b(?:const|let|var|function|return|if|else|for|while|class|import|from|def|async|await|try|catch|true|false|null|None|export|in|new|throw|echo)\b)''',
  );
  final spans = <TextSpan>[];
  var cursor = 0;
  for (final match in pattern.allMatches(line)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: line.substring(cursor, match.start)));
    }
    final token = match.group(0)!;
    final color =
        token.startsWith('//') ||
            token.startsWith('#') ||
            token.startsWith('/*')
        ? cs.onSurfaceVariant
        : token.startsWith('"') || token.startsWith("'")
        ? cs.tertiary
        : RegExp(r'^\d').hasMatch(token)
        ? cs.secondary
        : cs.primary;
    spans.add(
      TextSpan(
        text: token,
        style: TextStyle(color: color),
      ),
    );
    cursor = match.end;
  }
  if (cursor < line.length) spans.add(TextSpan(text: line.substring(cursor)));
  return spans;
}

class _ScriptListItemSurface extends StatelessWidget {
  final Widget child;

  const _ScriptListItemSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.primary.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _ScriptUploadSheet extends StatefulWidget {
  final Future<_PickedScript?> Function() onPick;

  const _ScriptUploadSheet({required this.onPick});

  @override
  State<_ScriptUploadSheet> createState() => _ScriptUploadSheetState();
}

class _ScriptUploadSheetState extends State<_ScriptUploadSheet> {
  _PickedScript? _picked;
  bool _picking = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AppVisuals.glassSurface(
        context: context,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        withShadow: true,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetHandle(cs),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 18, 8, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.file_upload_outlined,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '上传脚本',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _pickedFilePreview(cs),
                const SizedBox(height: 16),
                Row(
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
                          onPressed: _picked == null || _picking
                              ? null
                              : () => Navigator.pop(context, _picked),
                          icon: const Icon(Icons.file_upload_outlined),
                          label: const Text('上传'),
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
  }

  Widget _pickedFilePreview(ColorScheme cs) {
    if (_picked == null) {
      return Material(
        color: cs.primary.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.primary.withValues(alpha: 0.24)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _picking ? null : _chooseFile,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 34,
                    color: cs.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _picking ? '正在打开文件选择器...' : '点击选择脚本文件',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '支持任意脚本文件格式',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.description_outlined, color: cs.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _picked!.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatBytes(_picked!.bytes.length),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '重新选择',
            onPressed: _picking ? null : _chooseFile,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseFile() async {
    setState(() => _picking = true);
    final picked = await widget.onPick();
    if (!mounted) return;
    setState(() {
      _picked = picked ?? _picked;
      _picking = false;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _ScriptCreateSheet extends StatelessWidget {
  final bool includeUpload;

  const _ScriptCreateSheet({this.includeUpload = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppVisuals.glassSurface(
      context: context,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      withShadow: true,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHandle(cs),
              const SizedBox(height: 18),
              _sheetAction(
                context,
                Icons.description_outlined,
                '新建脚本',
                'file',
                cs.primary,
              ),
              _sheetAction(
                context,
                Icons.create_new_folder_outlined,
                '新建目录',
                'directory',
                cs.primary,
              ),
              if (includeUpload)
                _sheetAction(
                  context,
                  Icons.file_upload_outlined,
                  '上传脚本',
                  'upload',
                  cs.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetAction(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: color.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withValues(alpha: 0.24)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pop(context, value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScriptFileActionsSheet extends StatelessWidget {
  final ScriptFile file;

  const _ScriptFileActionsSheet({required this.file});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppVisuals.glassSurface(
      context: context,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      withShadow: true,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(cs),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 18, 8, 14),
                child: Text(
                  file.isDirectory ? '目录操作' : '脚本操作',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _action(
                context,
                Icons.drive_file_rename_outline,
                '重命名',
                'rename',
                cs.primary,
              ),
              if (!file.isDirectory)
                _action(
                  context,
                  Icons.download_outlined,
                  '下载脚本',
                  'download',
                  cs.primary,
                ),
              _action(context, Icons.delete_outline, '删除', 'delete', cs.error),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
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
}

class _ScriptNameSheet extends StatefulWidget {
  final String title;
  final String hint;
  final String initial;

  const _ScriptNameSheet({
    required this.title,
    required this.hint,
    this.initial = '',
  });

  @override
  State<_ScriptNameSheet> createState() => _ScriptNameSheetState();
}

class _ScriptNameSheetState extends State<_ScriptNameSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AppVisuals.glassSurface(
        context: context,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        withShadow: true,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetHandle(cs),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 18, 8, 14),
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.24),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: widget.hint,
                      prefixIcon: Icon(Icons.edit_outlined, color: cs.primary),
                      floatingLabelStyle: TextStyle(color: cs.primary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                Row(
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
                          onPressed: _submit,
                          icon: const Icon(Icons.check),
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
      ),
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }
}

class _ScriptDeleteSheet extends StatelessWidget {
  final String title;
  final String message;

  const _ScriptDeleteSheet({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppVisuals.glassSurface(
      context: context,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      withShadow: true,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(cs),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: cs.error,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.tonalIcon(
                        onPressed: () => Navigator.pop(context, false),
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
                        onPressed: () => Navigator.pop(context, true),
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
    );
  }
}

Widget _sheetHandle(ColorScheme cs) {
  return Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:flutter/material.dart";
import "package:qinglong_flutter/data/api/qinglong_api.dart";
import "package:qinglong_flutter/data/local/file_transfer_service.dart";
import "package:qinglong_flutter/data/models/models.dart";
import "package:qinglong_flutter/theme/app_visuals.dart";
import "package:qinglong_flutter/ui/components/shared_components.dart";
import "package:qinglong_flutter/ui/screens/env/env_view_model.dart";

class EnvScreen extends StatefulWidget {
  final QingLongApi? api;

  const EnvScreen({super.key, this.api});

  @override
  State<EnvScreen> createState() => _EnvScreenState();
}

class _EnvScreenState extends State<EnvScreen> {
  late final EnvViewModel _vm;
  bool _frameUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _vm = EnvViewModel(widget.api ?? QingLongApi.auth());
    _vm.addListener(_onChange);
    _vm.loadEnvs();
  }

  @override
  void dispose() {
    _vm.removeListener(_onChange);
    _vm.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted || _frameUpdateScheduled) return;
    _frameUpdateScheduled = true;
    // 延迟 setState 到当前帧之后，避免与底部弹窗的关闭动画/路由过渡产生元素反激活时序冲突。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameUpdateScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext c) {
    var cs = Theme.of(c).colorScheme;
    var state = _vm.state;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(MediaQuery.of(c).padding.top + 60),
        child: QlTopBar(
          title: state.isSelectionMode
              ? "已选择 ${state.selectedIds.length} 项"
              : "环境变量",
          leading: state.isSelectionMode
              ? Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: IconButton(
                    icon: Icon(Icons.close),
                    onPressed: _vm.clearSelection,
                  ),
                )
              : null,
          trailing: state.isSelectionMode
              ? [
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case "enable":
                          unawaited(
                            _showEnvResult(_vm.enableSelected(), "选中环境变量已启用"),
                          );
                          break;
                        case "disable":
                          unawaited(
                            _showEnvResult(_vm.disableSelected(), "选中环境变量已禁用"),
                          );
                          break;
                        case "delete":
                          _showBatchDeleteConfirm();
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: "enable",
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 18),
                            SizedBox(width: 8),
                            Text("启用"),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: "disable",
                        child: Row(
                          children: [
                            Icon(Icons.cancel, size: 18),
                            SizedBox(width: 8),
                            Text("禁用"),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: "delete",
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text("删除", style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ]
              : [
                  QlTopBarActionButton(
                    icon: Icons.import_export,
                    onPressed: _showImportExportMenu,
                    tooltip: "导入导出",
                  ),
                  const SizedBox(width: 8),
                  QlTopBarActionButton(
                    icon: Icons.add,
                    onPressed: () => _showAddEnvDialog(),
                    tooltip: "新建",
                  ),
                ],
        ),
      ),
      body: _buildBody(c, cs, state),
    );
  }

  Widget _buildBody(BuildContext c, ColorScheme cs, EnvUiState state) {
    if (state.isLoading) return const LoadingIndicator();
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 8),
            Text(state.error!, style: TextStyle(color: cs.error)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _vm.loadEnvs,
              child: const Text("重试"),
            ),
          ],
        ),
      );
    }
    if (state.envs.isEmpty) {
      return const EmptyState(icon: Icons.code, title: "暂无环境变量");
    }
    return RefreshIndicator(
      onRefresh: _vm.loadEnvs,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: state.envs.length,
        itemBuilder: (_, i) {
          var env = state.envs[i];
          final eid = env.intId ?? int.tryParse(env.id ?? "");
          return Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _EnvCard(
              env: env,
              isSelected: eid != null && state.selectedIds.contains(eid),
              isSelectionMode: state.isSelectionMode,
              isBusy: eid != null && state.busyIds.contains(eid),
              onTap: () {
                if (eid == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("环境变量缺少有效 ID，无法操作")),
                  );
                  return;
                }
                if (state.busyIds.contains(eid)) return;
                if (state.isSelectionMode) {
                  _vm.toggleSelection(eid);
                } else {
                  _showEnvMenu(context, env, eid);
                }
              },
              onLongPress: eid == null || state.busyIds.contains(eid)
                  ? () {}
                  : () => _vm.toggleSelection(eid),
            ),
          );
        },
      ),
    );
  }

  // ========== Context Menu ==========

  void _showEnvMenu(BuildContext cx, Environment env, int eid) {
    final isDisabled = env.isDisabled == 1;
    showModalBottomSheet(
      context: cx,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var cs = Theme.of(ctx).colorScheme;
        return AppVisuals.glassSurface(
          context: ctx,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          withShadow: true,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: EdgeInsets.only(top: 12, bottom: 14),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 2, 24, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.code, color: cs.primary, size: 22),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              env.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                            if (env.remarks != null && env.remarks!.isNotEmpty)
                              Text(
                                env.remarks!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                _MenuTile(
                  icon: Icons.edit_outlined,
                  label: "编辑",
                  iconColor: cs.primary,
                  labelColor: cs.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditEnvDialog(env, eid);
                  },
                ),
                _MenuTile(
                  icon: isDisabled
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  label: isDisabled ? "启用" : "禁用",
                  iconColor: cs.primary,
                  labelColor: cs.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isDisabled) {
                      unawaited(_showEnvResult(_vm.enableEnv(eid), "环境变量已启用"));
                    } else {
                      unawaited(_showEnvResult(_vm.disableEnv(eid), "环境变量已禁用"));
                    }
                  },
                ),
                _MenuTile(
                  icon: Icons.delete_outline,
                  label: "删除",
                  iconColor: cs.error,
                  labelColor: cs.error,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirm(eid, env.name);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImportExportMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AppVisuals.glassSurface(
          context: ctx,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          withShadow: true,
          child: SafeArea(
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
                  padding: const EdgeInsets.fromLTRB(24, 2, 24, 10),
                  child: Row(
                    children: [
                      Icon(Icons.import_export, color: cs.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        "导入导出",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                _MenuTile(
                  icon: Icons.upload_file_outlined,
                  label: "导入环境变量",
                  iconColor: cs.primary,
                  labelColor: cs.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _importFromFile();
                  },
                ),
                _MenuTile(
                  icon: Icons.download_outlined,
                  label: "导出为 .env",
                  iconColor: cs.primary,
                  labelColor: cs.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportEnvs(asJson: false);
                  },
                ),
                _MenuTile(
                  icon: Icons.data_object_outlined,
                  label: "导出为 JSON",
                  iconColor: cs.primary,
                  labelColor: cs.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportEnvs(asJson: true);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEnvResult(
    Future<String?> operation,
    String successMessage,
  ) async {
    final error = await operation;
    if (!mounted) return;
    _showMessage(error ?? successMessage);
  }

  Future<void> _exportEnvs({required bool asJson}) async {
    final envs = _vm.state.envs;
    if (envs.isEmpty) {
      _showMessage("当前没有可导出的环境变量");
      return;
    }

    final content = asJson
        ? const JsonEncoder.withIndent("  ").convert(
            envs
                .map(
                  (env) => {
                    "name": env.name,
                    "value": env.value,
                    "remarks": env.remarks ?? "",
                    "status": env.isDisabled,
                  },
                )
                .toList(),
          )
        : envs
              .map((env) => "${env.name}=${_escapeEnvValue(env.value)}")
              .join("\n");
    final extension = asJson ? "json" : "env";
    final fileName = "qinglong-envs.$extension";

    try {
      final path = await FileTransferService.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(content)),
      );
      if (path != null && mounted) {
        _showMessage("已导出 ${envs.length} 条环境变量");
      }
    } catch (e) {
      _showMessage("导出失败: $e");
    }
  }

  String _escapeEnvValue(String value) {
    if (value.contains(RegExp(r'[\s#="]'))) {
      return '"${value.replaceAll('"', '\\"')}"';
    }
    return value;
  }

  Future<void> _importFromFile() async {
    try {
      final file = await FileTransferService.pickFile(
        allowedExtensions: ["env", "json"],
      );
      if (file == null) return;
      final bytes = file.bytes;
      final entries = _parseImportContent(
        utf8.decode(bytes),
        file.name.toLowerCase().endsWith(".json"),
      );
      if (entries.isEmpty) throw StateError("文件中没有有效的环境变量");
      if (!mounted) return;
      final decision = await showModalBottomSheet<_EnvImportDecision>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _EnvImportPreviewSheet(
          entries: entries,
          existingNames: _vm.state.envs.map((env) => env.name).toSet(),
        ),
      );
      if (decision != null && mounted) {
        await _importEntries(entries, decision.policy);
      }
    } catch (e) {
      _showMessage("导入失败: $e");
    }
  }

  List<_EnvImportEntry> _parseImportContent(String content, bool asJson) {
    if (asJson) {
      final decoded = jsonDecode(content);
      final raw = decoded is Map && decoded["data"] is List
          ? decoded["data"]
          : decoded;
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => _EnvImportEntry.fromJson(item))
            .where((entry) => entry.name.isNotEmpty && entry.value.isNotEmpty)
            .toList();
      }
      if (raw is Map) {
        return raw.entries
            .map(
              (item) =>
                  _EnvImportEntry(name: item.key, value: item.value.toString()),
            )
            .where((entry) => entry.name.isNotEmpty && entry.value.isNotEmpty)
            .toList();
      }
      throw const FormatException("JSON 格式应为数组或变量名对象");
    }

    final entries = <_EnvImportEntry>[];
    for (final rawLine in const LineSplitter().convert(content)) {
      var line = rawLine.trim();
      if (line.isEmpty || line.startsWith("#")) continue;
      if (line.startsWith("export ")) line = line.substring(7).trimLeft();
      final separator = line.indexOf("=");
      if (separator <= 0) continue;
      final name = line.substring(0, separator).trim();
      var value = line.substring(separator + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      if (RegExp(r"^[a-zA-Z_][0-9a-zA-Z_]*$").hasMatch(name) &&
          value.isNotEmpty) {
        entries.add(_EnvImportEntry(name: name, value: value));
      }
    }
    return entries;
  }

  Future<void> _importEntries(
    List<_EnvImportEntry> entries,
    _EnvDuplicatePolicy policy,
  ) async {
    var imported = 0;
    var skipped = 0;
    var failed = 0;
    final existing = <String, Environment>{
      for (final env in _vm.state.envs) env.name: env,
    };

    for (final entry in entries) {
      final old = existing[entry.name];
      if (old != null && policy == _EnvDuplicatePolicy.skip) {
        skipped++;
        continue;
      }
      try {
        final response = old != null && policy == _EnvDuplicatePolicy.overwrite
            ? (old.intId == null
                  ? null
                  : await _vm.api.updateEnvironment(
                      EnvRequest(
                        id: old.intId,
                        name: entry.name,
                        value: entry.value,
                        remarks: entry.remarks,
                      ),
                    ))
            : await _vm.api.addEnvironment(
                EnvRequest(
                  name: entry.name,
                  value: entry.value,
                  remarks: entry.remarks,
                ),
              );
        if (response == null || response.code != 200) {
          failed++;
          continue;
        }
        imported++;
        if (old == null) {
          existing[entry.name] = Environment(
            name: entry.name,
            value: entry.value,
          );
        }
      } catch (_) {
        failed++;
      }
    }

    await _vm.loadEnvs();
    if (mounted) {
      _showMessage("导入完成：成功 $imported 条，跳过 $skipped 条，失败 $failed 条");
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ========== Add Dialog ==========

  Future<void> _showAddEnvDialog() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var cs = Theme.of(ctx).colorScheme;
        return _EnvFormSheet(
          title: "新建环境变量",
          submitLabel: "创建",
          submitIcon: Icons.add,
          initialName: "",
          initialValue: "",
          initialRemarks: "",
          cs: cs,
          onSubmit: (name, value, remarks) async {
            final error = await _vm.addEnv(name, value, remarks);
            if (error != null) {
              _showMessage(error);
              return false;
            }
            return true;
          },
        );
      },
    );

    if (result == true && mounted) {
      _showMessage("环境变量已创建");
    }
  }

  // ========== Edit Dialog ==========

  Future<void> _showEditEnvDialog(Environment env, int eid) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var cs = Theme.of(ctx).colorScheme;
        return _EnvFormSheet(
          title: "编辑环境变量",
          submitLabel: "保存",
          submitIcon: Icons.edit,
          initialName: env.name,
          initialValue: env.value,
          initialRemarks: env.remarks ?? "",
          cs: cs,
          onSubmit: (name, value, remarks) async {
            final error = await _vm.updateEnv(eid, name, value, remarks);
            if (error != null) {
              _showMessage(error);
              return false;
            }
            return true;
          },
        );
      },
    );

    if (result == true && mounted) {
      _showMessage("环境变量已保存");
    }
  }

  // ========== Delete Confirms ==========

  Future<void> _showDeleteConfirm(int eid, String name) async {
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DeleteConfirmSheet(
        title: "删除环境变量",
        message: "确定要删除「$name」吗？删除后无法恢复。",
      ),
    );

    if (shouldDelete == true && mounted) {
      await _showEnvResult(_vm.deleteEnv(eid), "环境变量已删除");
    }
  }

  Future<void> _showBatchDeleteConfirm() async {
    final count = _vm.state.selectedIds.length;
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DeleteConfirmSheet(
        title: "删除选中变量",
        message: "确定要删除选中的 $count 个环境变量吗？删除后无法恢复。",
      ),
    );

    if (shouldDelete == true && mounted) {
      await _showEnvResult(_vm.deleteSelected(), "选中环境变量已删除");
    }
  }
}

class _DeleteConfirmSheet extends StatelessWidget {
  final String title;
  final String message;

  const _DeleteConfirmSheet({required this.title, required this.message});

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
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close),
                      label: const Text("取消"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("删除"),
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
  }
}

// ========== Reusable Form Sheet ==========

class _EnvFormSheet extends StatefulWidget {
  final String title;
  final String submitLabel;
  final IconData submitIcon;
  final String initialName;
  final String initialValue;
  final String initialRemarks;
  final ColorScheme cs;
  final Future<bool> Function(String name, String value, String remarks)?
  onSubmit;

  const _EnvFormSheet({
    required this.title,
    required this.submitLabel,
    required this.submitIcon,
    required this.initialName,
    required this.initialValue,
    required this.initialRemarks,
    required this.cs,
    this.onSubmit,
  });

  @override
  State<_EnvFormSheet> createState() => _EnvFormSheetState();
}

class _EnvFormSheetState extends State<_EnvFormSheet> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _valueCtl;
  late final TextEditingController _remarksCtl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.initialName);
    _valueCtl = TextEditingController(text: widget.initialValue);
    _remarksCtl = TextEditingController(text: widget.initialRemarks);
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _valueCtl.dispose();
    _remarksCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AppVisuals.glassSurface(
        context: context,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        withShadow: true,
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 12, 0, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: widget.cs.onSurface.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: widget.cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              widget.submitIcon,
                              color: widget.cs.primary,
                              size: 22,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: widget.cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    _EnvFormField(
                      controller: _nameCtl,
                      label: "变量名",
                      hintText: "例如: JD_COOKIE",
                      icon: Icons.label_outline,
                      colorScheme: widget.cs,
                    ),
                    _EnvFormField(
                      controller: _valueCtl,
                      label: "变量值",
                      hintText: "输入变量值",
                      icon: Icons.code,
                      colorScheme: widget.cs,
                      maxLines: 3,
                      minLines: 1,
                    ),
                    _EnvFormField(
                      controller: _remarksCtl,
                      label: "备注（可选）",
                      hintText: "变量说明",
                      icon: Icons.notes,
                      colorScheme: widget.cs,
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: FilledButton.tonalIcon(
                                onPressed: () => Navigator.pop(context, false),
                                icon: const Icon(Icons.close),
                                label: const Text("取消"),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () async {
                                        final name = _nameCtl.text.trim();
                                        final value = _valueCtl.text.trim();
                                        final remarks = _remarksCtl.text.trim();
                                        if (name.isEmpty || value.isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text("变量名和变量值不能为空"),
                                            ),
                                          );
                                          return;
                                        }
                                        if (!RegExp(
                                          r"^[a-zA-Z_][0-9a-zA-Z_]*$",
                                        ).hasMatch(name)) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "变量名只能包含字母、数字和下划线，且不能以数字开头",
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        if (widget.onSubmit != null) {
                                          setState(() => _isSubmitting = true);
                                          final submitted = await widget
                                              .onSubmit!(name, value, remarks);
                                          if (submitted && context.mounted) {
                                            Navigator.pop(context, true);
                                          } else if (context.mounted) {
                                            setState(
                                              () => _isSubmitting = false,
                                            );
                                          }
                                          return;
                                        }
                                        Navigator.pop(context, true);
                                      },
                                icon: Icon(
                                  widget.submitLabel == "创建"
                                      ? Icons.add
                                      : Icons.save_outlined,
                                ),
                                label: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(widget.submitLabel),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EnvFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final ColorScheme colorScheme;
  final int? maxLines;
  final int? minLines;

  const _EnvFormField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    required this.colorScheme,
    this.maxLines = 1,
    this.minLines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.24)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: minLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Icon(icon, size: 20, color: colorScheme.primary),
          floatingLabelStyle: TextStyle(color: colorScheme.primary),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}

// ========== Card Widget ==========

class _EnvCard extends StatelessWidget {
  final Environment env;
  final bool isSelected;
  final bool isSelectionMode;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _EnvCard({
    required this.env,
    required this.isSelected,
    required this.isSelectionMode,
    required this.isBusy,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDisabled = env.isDisabled == 1;
    final statusColor = isDisabled ? cs.outline : cs.primary;
    final cardRadius = BorderRadius.circular(16);

    return Material(
      color: cs.primary.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: cardRadius,
        side: BorderSide(color: cs.primary.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: cardRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              if (isSelectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  visualDensity: VisualDensity.compact,
                ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isDisabled ? Icons.cancel : Icons.check_circle,
                  size: 16,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            env.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (env.remarks != null && env.remarks!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              env.remarks!,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      env.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: "monospace",
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              isBusy
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isDisabled ? "已禁用" : "已启用",
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== Menu Tile ==========

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  final Color? labelColor;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    this.iconColor,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actionColor = labelColor ?? cs.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: actionColor.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: actionColor.withValues(alpha: 0.24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 19, color: iconColor ?? actionColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: actionColor,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: actionColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _EnvDuplicatePolicy { overwrite, skip, keep }

class _EnvImportEntry {
  final String name;
  final String value;
  final String? remarks;

  const _EnvImportEntry({
    required this.name,
    required this.value,
    this.remarks,
  });

  factory _EnvImportEntry.fromJson(Map json) {
    return _EnvImportEntry(
      name: json["name"]?.toString().trim() ?? "",
      value: json["value"]?.toString() ?? "",
      remarks: json["remarks"]?.toString(),
    );
  }
}

class _EnvImportDecision {
  final _EnvDuplicatePolicy policy;

  const _EnvImportDecision(this.policy);
}

class _EnvImportPreviewSheet extends StatefulWidget {
  final List<_EnvImportEntry> entries;
  final Set<String> existingNames;

  const _EnvImportPreviewSheet({
    required this.entries,
    required this.existingNames,
  });

  @override
  State<_EnvImportPreviewSheet> createState() => _EnvImportPreviewSheetState();
}

class _EnvImportPreviewSheetState extends State<_EnvImportPreviewSheet> {
  _EnvDuplicatePolicy _policy = _EnvDuplicatePolicy.skip;

  int get _duplicateCount => widget.entries
      .where((entry) => widget.existingNames.contains(entry.name))
      .length;

  String _policyLabel(_EnvDuplicatePolicy policy) {
    switch (policy) {
      case _EnvDuplicatePolicy.overwrite:
        return "覆盖已有变量";
      case _EnvDuplicatePolicy.skip:
        return "跳过重复变量";
      case _EnvDuplicatePolicy.keep:
        return "保留两条变量";
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: AppVisuals.glassSurface(
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
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                child: Row(
                  children: [
                    Icon(Icons.preview_outlined, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "导入预览",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      "${widget.entries.length} 条",
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: DropdownButtonFormField<_EnvDuplicatePolicy>(
                  value: _policy,
                  decoration: InputDecoration(
                    labelText: "重复变量处理",
                    prefixIcon: Icon(
                      Icons.copy_all_outlined,
                      color: cs.primary,
                    ),
                    filled: true,
                    fillColor: cs.primary.withValues(alpha: 0.07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: cs.primary.withValues(alpha: 0.24),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: cs.primary.withValues(alpha: 0.24),
                      ),
                    ),
                  ),
                  items: _EnvDuplicatePolicy.values
                      .map(
                        (policy) => DropdownMenuItem(
                          value: policy,
                          child: Text(_policyLabel(policy)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _policy = value);
                  },
                ),
              ),
              if (_duplicateCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: cs.tertiary),
                      const SizedBox(width: 7),
                      Text(
                        "检测到 $_duplicateCount 条同名变量",
                        style: TextStyle(color: cs.tertiary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  itemCount: widget.entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, index) {
                    final entry = widget.entries[index];
                    final duplicate = widget.existingNames.contains(entry.name);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (duplicate ? cs.tertiary : cs.primary)
                              .withValues(alpha: 0.24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            duplicate
                                ? Icons.warning_amber_outlined
                                : Icons.code_outlined,
                            size: 18,
                            color: duplicate ? cs.tertiary : cs.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  entry.value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: "monospace",
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        label: const Text("取消"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            Navigator.pop(context, _EnvImportDecision(_policy)),
                        icon: const Icon(Icons.file_download_done_outlined),
                        label: const Text("开始导入"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

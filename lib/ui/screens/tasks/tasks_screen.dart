import "package:flutter/material.dart";
import "package:qinglong_flutter/data/models/models.dart";
import "package:qinglong_flutter/data/api/qinglong_api.dart";
import "package:qinglong_flutter/theme/app_visuals.dart";
import "package:qinglong_flutter/ui/components/shared_components.dart";
import "package:qinglong_flutter/ui/screens/tasks/tasks_view_model.dart";
import "task_time_formatter.dart";
import "dart:async";

class TasksScreen extends StatefulWidget {
  final QingLongApi? api;

  const TasksScreen({super.key, this.api});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late final TasksViewModel _vm;
  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  bool _formBusy = false;

  @override
  void initState() {
    super.initState();
    _vm = TasksViewModel(widget.api ?? QingLongApi.auth());
    _searchController = TextEditingController(text: _vm.state.searchQuery);
    _vm.loadTasks();
    _vm.addListener(_onStateChange);
  }

  void _onStateChange() {
    final query = _vm.state.searchQuery;
    if (_searchController.text != query) {
      _searchController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    if (_vm.state.showEditDialog != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showEditTaskDialog(_vm.state.showEditDialog!),
      );
    }
    if (_vm.state.showAddDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showAddTaskDialog());
    }
    setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onStateChange);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      _vm.setSearchQuery("");
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 140), () {
      if (mounted) _vm.setSearchQuery(query);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _vm.setSearchQuery("");
  }

  @override
  Widget build(BuildContext c) {
    final cs = Theme.of(c).colorScheme;
    var state = _vm.state;
    var filtered = state.filteredTasks;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(MediaQuery.of(c).padding.top + 60),
        child: QlTopBar(
          title: state.isSelectionMode
              ? "已选择 ${state.selectedIds.length} 项"
              : "定时任务",
          leading: state.isSelectionMode
              ? Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _vm.clearSelection,
                    visualDensity: VisualDensity.compact,
                  ),
                )
              : null,
          trailing: state.isSelectionMode
              ? [
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == "run") {
                        unawaited(
                          _showTaskResult(_vm.runSelected(), '选中任务已提交运行'),
                        );
                      } else if (v == "stop") {
                        _showStopSelectedConfirm();
                      } else {
                        _showDeleteConfirm();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: "run", child: Text("运行")),
                      const PopupMenuItem(value: "stop", child: Text("停止运行")),
                      const PopupMenuItem(value: "delete", child: Text("删除")),
                    ],
                  ),
                ]
              : [
                  QlTopBarActionButton(
                    icon: Icons.filter_list,
                    onPressed: _showFilterMenu,
                    tooltip: "筛选",
                  ),
                  const SizedBox(width: 8),
                  QlTopBarActionButton(
                    icon: Icons.add,
                    onPressed: _vm.showAddDialog,
                    tooltip: "新建",
                  ),
                ],
        ),
      ),
      body: _buildBody(c, cs, state, filtered),
    );
  }

  Widget _buildBody(
    BuildContext c,
    ColorScheme cs,
    TasksUiState state,
    List<CronTask> filtered,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: AppVisuals.glassSurface(
            context: c,
            borderRadius: BorderRadius.circular(16),
            blur: 10,
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.search,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: "搜索任务名称或命令",
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.78),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: state.searchQuery.isNotEmpty
                          ? IconButton(
                              key: const ValueKey("clear-search"),
                              onPressed: _clearSearch,
                              tooltip: "清除搜索",
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: cs.onSurfaceVariant,
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                            )
                          : const SizedBox(
                              key: ValueKey("empty-search-action"),
                              width: 34,
                              height: 34,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: state.isLoading && filtered.isEmpty
              ? const LoadingIndicator()
              : filtered.isEmpty
              ? state.error != null
                    ? _buildErrorState(cs, state)
                    : _buildEmptyState(cs)
              : RefreshIndicator(
                  onRefresh: () async => _vm.loadTasks(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TaskCard(
                        task: filtered[i],
                        isSelected: state.selectedIds.contains(
                          (filtered[i].intId?.toString() ?? filtered[i].id) ??
                              "",
                        ),
                        isSelectionMode: state.isSelectionMode,
                        onTap: () {
                          var tid =
                              (filtered[i].intId?.toString() ??
                                  filtered[i].id) ??
                              "";
                          if (state.isSelectionMode) {
                            _vm.toggleSelection(tid);
                          } else {
                            _showTaskMenu(context, filtered[i]);
                          }
                        },
                        onLongPress: () {
                          var tid =
                              (filtered[i].intId?.toString() ??
                                  filtered[i].id) ??
                              "";
                          _vm.toggleSelection(tid);
                        },
                        onPlayTap: () {
                          _runTask(filtered[i]);
                        },
                        onStopTap: filtered[i].stateCode == 0
                            ? () => _stopTask(filtered[i])
                            : null,
                        isStopping: state.busyTaskIds.contains(
                          (filtered[i].intId?.toString() ?? filtered[i].id) ??
                              '',
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildErrorState(ColorScheme cs, TasksUiState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: cs.error),
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: TextStyle(color: cs.error, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _vm.loadTasks,
              icon: const Icon(Icons.refresh),
              label: const Text("重试"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule,
              size: 64,
              color: cs.onSurfaceVariant.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              "暂无定时任务",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "点击右上角按钮创建新任务",
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var cs = Theme.of(ctx).colorScheme;
        var cur = _vm.state.statusFilter;
        var items = [
          ["all", "全部", Icons.filter_alt_off],
          ["enabled", "已启用", Icons.check_circle_outline],
          ["disabled", "已禁用", Icons.cancel_outlined],
        ];
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
                  padding: const EdgeInsets.fromLTRB(24, 2, 24, 12),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list, color: cs.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        "筛选",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                ...items.map((item) {
                  var sel = cur == item[0];
                  final optionColor = cs.primary;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          _vm.setStatusFilter(item[0] as String);
                          Navigator.of(ctx).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: optionColor.withValues(
                                alpha: sel ? 0.34 : 0.24,
                              ),
                              width: sel ? 1.6 : 1,
                            ),
                            color: optionColor.withValues(
                              alpha: sel ? 0.11 : 0.07,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item[2] as IconData,
                                color: optionColor,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                item[1] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: optionColor,
                                ),
                              ),
                              const Spacer(),
                              if (sel)
                                Icon(Icons.check, size: 18, color: optionColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTaskMenu(BuildContext cx, CronTask task) {
    String tid = (task.intId?.toString() ?? task.id) ?? "";
    showModalBottomSheet(
      context: cx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        ColorScheme cs = Theme.of(ctx).colorScheme;
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
                  padding: const EdgeInsets.fromLTRB(24, 2, 24, 12),
                  child: Row(
                    children: [
                      Icon(Icons.touch_app, color: cs.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        task.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _menuItem(ctx, Icons.edit, cs.primary, "编辑", () {
                  Navigator.pop(ctx);
                  _vm.showEditDialog(task);
                }),
                _menuItem(
                  ctx,
                  task.isPinned == 1 ? Icons.push_pin : Icons.push_pin_outlined,
                  cs.primary,
                  task.isPinned == 1 ? "取消置顶" : "置顶",
                  () {
                    Navigator.pop(ctx);
                    if (task.isPinned == 1) {
                      unawaited(_showTaskResult(_vm.unpinTask(tid), '任务已取消置顶'));
                    } else {
                      unawaited(_showTaskResult(_vm.pinTask(tid), '任务已置顶'));
                    }
                  },
                ),
                _menuItem(
                  ctx,
                  task.isDisabled == 1 ? Icons.check_circle : Icons.cancel,
                  cs.primary,
                  task.isDisabled == 1 ? "启用" : "禁用",
                  () {
                    Navigator.pop(ctx);
                    if (task.isDisabled == 1) {
                      unawaited(_showTaskResult(_vm.enableTask(tid), '任务已启用'));
                    } else {
                      unawaited(_showTaskResult(_vm.disableTask(tid), '任务已禁用'));
                    }
                  },
                ),
                if (task.stateCode == 0)
                  _menuItem(
                    ctx,
                    Icons.stop_circle_outlined,
                    cs.primary,
                    "停止运行",
                    () {
                      Navigator.pop(ctx);
                      _stopTask(task);
                    },
                  ),
                _menuItem(ctx, Icons.close, cs.error, "删除", () {
                  Navigator.pop(ctx);
                  _showTaskDeleteConfirm(tid, task.name);
                }, isDestructive: true),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuItem(
    BuildContext ctx,
    IconData ic,
    Color col,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final cs = Theme.of(ctx).colorScheme;
    final actionColor = isDestructive ? cs.error : col;
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
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(ic, size: 16, color: col),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDestructive ? cs.error : col,
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

  void _showLogViewer(
    BuildContext cx,
    String taskName,
    String taskId, {
    bool live = false,
  }) {
    showModalBottomSheet(
      context: cx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogViewer(
        api: _vm.api,
        taskName: taskName,
        taskId: taskId,
        live: live,
      ),
    );
  }

  void _showAddTaskDialog() {
    var nCtl = TextEditingController();
    var cCtl = TextEditingController();
    var sCtl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var mcs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: AppVisuals.glassSurface(
            context: ctx,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            withShadow: true,
            child: SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 14),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: mcs.onSurface.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 2, 24, 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.add_task,
                                color: mcs.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "新建任务",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: mcs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _TaskFormField(
                          controller: nCtl,
                          label: "任务名",
                          hintText: "例如：每日签到",
                          icon: Icons.label_outline,
                          colorScheme: mcs,
                        ),
                        _TaskFormField(
                          controller: cCtl,
                          label: "命令",
                          hintText: "输入要执行的命令",
                          icon: Icons.terminal,
                          colorScheme: mcs,
                        ),
                        _TaskFormField(
                          controller: sCtl,
                          label: "定时规则",
                          hintText: "0 0 * * *",
                          icon: Icons.schedule,
                          colorScheme: mcs,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: FilledButton.tonalIcon(
                                    onPressed: () {
                                      _vm.hideAddDialog();
                                      Navigator.pop(ctx);
                                    },
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
                                    onPressed: _formBusy
                                        ? null
                                        : () async {
                                            if (nCtl.text.trim().isEmpty ||
                                                cCtl.text.trim().isEmpty ||
                                                sCtl.text.trim().isEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    '请完整填写任务名、命令和定时规则',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }
                                            setState(() => _formBusy = true);
                                            final error = await _vm.addTask(
                                              nCtl.text.trim(),
                                              cCtl.text.trim(),
                                              sCtl.text.trim(),
                                            );
                                            if (!mounted) return;
                                            setState(() => _formBusy = false);
                                            if (error != null) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(content: Text(error)),
                                              );
                                            } else {
                                              if (!ctx.mounted) return;
                                              Navigator.pop(ctx);
                                            }
                                          },
                                    icon: const Icon(Icons.add_task),
                                    label: Text(_formBusy ? '创建中' : '创建'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditTaskDialog(CronTask task) {
    var nCtl = TextEditingController(text: task.name);
    var cCtl = TextEditingController(text: task.command);
    var sCtl = TextEditingController(text: task.schedule);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var mcs = Theme.of(ctx).colorScheme;
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
                    color: mcs.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 2, 24, 12),
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: mcs.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        "编辑任务",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: mcs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                _TaskFormField(
                  controller: nCtl,
                  label: "任务名",
                  hintText: "例如：每日签到",
                  icon: Icons.label_outline,
                  colorScheme: mcs,
                ),
                _TaskFormField(
                  controller: cCtl,
                  label: "命令",
                  hintText: "输入要执行的命令",
                  icon: Icons.terminal,
                  colorScheme: mcs,
                ),
                _TaskFormField(
                  controller: sCtl,
                  label: "定时规则",
                  hintText: "0 0 * * *",
                  icon: Icons.schedule,
                  colorScheme: mcs,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.tonalIcon(
                            onPressed: () {
                              _vm.hideEditDialog();
                              Navigator.pop(ctx);
                            },
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
                            onPressed: _formBusy
                                ? null
                                : () async {
                                    if (nCtl.text.trim().isEmpty ||
                                        cCtl.text.trim().isEmpty ||
                                        sCtl.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('请完整填写任务名、命令和定时规则'),
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() => _formBusy = true);
                                    final error = await _vm.updateTask(
                                      task.intId?.toString() ?? '',
                                      nCtl.text.trim(),
                                      cCtl.text.trim(),
                                      sCtl.text.trim(),
                                    );
                                    if (!mounted) return;
                                    setState(() => _formBusy = false);
                                    if (error != null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(error)),
                                      );
                                    } else {
                                      if (!ctx.mounted) return;
                                      Navigator.pop(ctx);
                                    }
                                  },
                            icon: const Icon(Icons.save_outlined),
                            label: Text(_formBusy ? '保存中' : '保存'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTaskResult(
    Future<String?> operation,
    String successMessage,
  ) async {
    final error = await operation;
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? successMessage)));
  }

  Future<void> _runTask(CronTask task) async {
    final taskId = (task.intId?.toString() ?? task.id) ?? '';
    if (taskId.isEmpty || _vm.isTaskBusy(taskId)) return;

    final error = await _vm.runTask(taskId);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _showLogViewer(context, task.name, taskId, live: true);
  }

  Future<void> _showTaskDeleteConfirm(String taskId, String taskName) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskDeleteSheet(
        title: "删除定时任务",
        message: "确定要删除「$taskName」吗？删除后无法恢复。",
      ),
    );

    if (confirmed == true && mounted) {
      await _showTaskResult(_vm.deleteTask(taskId), '任务已删除');
    }
  }

  Future<void> _showDeleteConfirm() async {
    final count = _vm.state.selectedIds.length;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskDeleteSheet(
        title: "删除选中任务",
        message: "确定要删除选中的 $count 个任务吗？删除后无法恢复。",
      ),
    );

    if (confirmed == true && mounted) {
      await _showTaskResult(_vm.deleteSelected(), '选中任务已删除');
    }
  }

  Future<void> _stopTask(CronTask task) async {
    final taskId = (task.intId?.toString() ?? task.id) ?? '';
    if (taskId.isEmpty || _vm.isTaskBusy(taskId)) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskStopSheet(
        title: '停止定时任务',
        message: '确定要停止「${task.name}」的当前运行吗？',
      ),
    );
    if (confirmed != true || !mounted) return;

    final error = await _vm.stopTask(taskId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? '任务已停止')));
  }

  Future<void> _showStopSelectedConfirm() async {
    final count = _vm.state.tasks.where((task) {
      final id = (task.intId?.toString() ?? task.id) ?? '';
      return _vm.state.selectedIds.contains(id) && task.stateCode == 0;
    }).length;
    if (count == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('选中的任务中没有正在运行的任务')));
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _TaskStopSheet(title: '停止选中任务', message: '确定要停止选中的 $count 个运行中任务吗？'),
    );
    if (confirmed != true || !mounted) return;

    await _showTaskResult(_vm.stopSelected(), '选中任务已停止');
  }
}

class _TaskStopSheet extends StatelessWidget {
  final String title;
  final String message;

  const _TaskStopSheet({required this.title, required this.message});

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
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.stop_circle_outlined,
                      color: cs.primary,
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
                      label: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('停止'),
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

class _TaskDeleteSheet extends StatelessWidget {
  final String title;
  final String message;

  const _TaskDeleteSheet({required this.title, required this.message});

  @override
  @override
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

class _TaskFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final ColorScheme colorScheme;

  const _TaskFormField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    required this.colorScheme,
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

class _TaskCard extends StatelessWidget {
  final CronTask task;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onPlayTap;
  final VoidCallback? onStopTap;
  final bool isStopping;
  const _TaskCard({
    required this.task,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    this.onPlayTap,
    this.onStopTap,
    this.isStopping = false,
  });
  ({IconData icon, Color color, String label}) _statusInfo(ColorScheme cs) {
    switch (task.stateCode) {
      case 0:
        return (icon: Icons.play_arrow, color: cs.primary, label: "运行中");
      case 1:
        return (icon: Icons.schedule, color: cs.primary, label: "空闲");
      case 2:
        return (icon: Icons.cancel, color: cs.outline, label: "已禁用");
      case 3:
        return (icon: Icons.access_time, color: cs.primary, label: "队列中");
      default:
        return (icon: Icons.help_outline, color: cs.outline, label: "未知");
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = _statusInfo(cs);
    final lastRun = formatTaskLastRun(task.lastExecuteTime);
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: status.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (task.isPinned == 1)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: cs.tertiary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.push_pin,
                              size: 14,
                              color: cs.tertiary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      task.schedule,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: "monospace",
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (lastRun.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        lastRun,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  if (task.stateCode == 0) {
                    onStopTap?.call();
                  } else if (onPlayTap != null) {
                    onPlayTap!();
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: isStopping
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        )
                      : Icon(
                          task.stateCode == 0
                              ? Icons.stop_circle_outlined
                              : Icons.play_arrow,
                          color: cs.primary,
                          size: 22,
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

class _LogViewer extends StatefulWidget {
  final QingLongApi api;
  final String taskName;
  final String taskId;
  final bool live;

  const _LogViewer({
    required this.api,
    required this.taskName,
    required this.taskId,
    this.live = false,
  });
  @override
  State<_LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<_LogViewer> {
  String _log = "";
  bool _isLoading = true;
  String? _error;
  Timer? _timer;
  bool _refreshing = false;
  final _sc = ScrollController();

  @override
  void initState() {
    super.initState();
    _refreshLogs();
    if (widget.live) {
      _timer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _refreshLogs(),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sc.dispose();
    super.dispose();
  }

  Future<void> _refreshLogs({bool showLoading = false}) async {
    final taskId = int.tryParse(widget.taskId);
    if (taskId == null) return;
    if (_refreshing) return;

    _refreshing = true;
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await widget.api.getTaskLog(taskId);
      if (response.code != 200) {
        throw StateError(response.message ?? '加载实时日志失败');
      }
      if (mounted) {
        setState(() {
          _log = response.data ?? '';
          _isLoading = false;
          _error = null;
        });
        _scrollToLatest();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      } else {
        _refreshing = false;
      }
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sc.hasClients) return;
      final maxExtent = _sc.position.maxScrollExtent;
      if (maxExtent > 0) {
        _sc.jumpTo(maxExtent);
      }
    });
  }

  @override
  Widget build(BuildContext c) {
    var cs = Theme.of(c).colorScheme;
    return AppVisuals.glassSurface(
      context: c,
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
              padding: const EdgeInsets.fromLTRB(24, 2, 24, 12),
              child: Row(
                children: [
                  Icon(Icons.article, color: cs.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    widget.taskName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.live) ...[
                    const Spacer(),
                    IconButton(
                      tooltip: '刷新实时日志',
                      onPressed: _refreshing
                          ? null
                          : () => _refreshLogs(showLoading: true),
                      icon: _refreshing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 360),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
              ),
              child: SingleChildScrollView(
                controller: _sc,
                child: SelectableText(
                  _error != null
                      ? _error!
                      : _isLoading && _log.isEmpty
                      ? "加载日志中..."
                      : _log.isEmpty
                      ? "暂无日志内容"
                      : _log,
                  style: TextStyle(
                    fontFamily: "monospace",
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 48,
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.pop(c),
                      icon: const Icon(Icons.close),
                      label: const Text("关闭"),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

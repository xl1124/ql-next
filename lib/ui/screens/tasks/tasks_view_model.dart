import 'package:flutter/foundation.dart';
import 'package:qinglong_flutter/data/models/models.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';

class TasksUiState {
  final List<CronTask> tasks;
  final bool isLoading;
  final String? error;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final bool showAddDialog;
  final CronTask? showEditDialog;
  final String? logTaskId;
  final String logTaskName;
  final String logContent;
  final int selectedLogIndex;
  final String? logStatus;
  final bool isLogLoading;
  final String? logError;
  final Set<String> busyTaskIds;
  final bool isBatchBusy;
  final String statusFilter; // "all", "enabled", "disabled"
  final String searchQuery;

  TasksUiState({
    this.tasks = const [],
    this.isLoading = true,
    this.error,
    this.selectedIds = const {},
    this.isSelectionMode = false,
    this.showAddDialog = false,
    this.showEditDialog,
    this.logTaskId,
    this.logTaskName = '',
    this.logContent = '',
    this.selectedLogIndex = -1,
    this.logStatus,
    this.isLogLoading = false,
    this.logError,
    this.busyTaskIds = const {},
    this.isBatchBusy = false,
    this.statusFilter = 'all',
    this.searchQuery = '',
  });

  TasksUiState copyWith({
    List<CronTask>? tasks,
    bool? isLoading,
    String? error,
    bool clearError = false,
    Set<String>? selectedIds,
    bool? isSelectionMode,
    bool? showAddDialog,
    CronTask? showEditDialog,
    bool clearEditDialog = false,
    String? logTaskId,
    String? logTaskName,
    String? logContent,
    int? selectedLogIndex,
    String? logStatus,
    bool? isLogLoading,
    String? logError,
    bool clearLogError = false,
    Set<String>? busyTaskIds,
    bool? isBatchBusy,
    String? statusFilter,
    String? searchQuery,
  }) {
    return TasksUiState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedIds: selectedIds ?? this.selectedIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      showAddDialog: showAddDialog ?? this.showAddDialog,
      showEditDialog: clearEditDialog
          ? null
          : (showEditDialog ?? this.showEditDialog),
      logTaskId: logTaskId ?? this.logTaskId,
      logTaskName: logTaskName ?? this.logTaskName,
      logContent: logContent ?? this.logContent,
      selectedLogIndex: selectedLogIndex ?? this.selectedLogIndex,
      logStatus: logStatus ?? this.logStatus,
      isLogLoading: isLogLoading ?? this.isLogLoading,
      logError: clearLogError ? null : (logError ?? this.logError),
      busyTaskIds: busyTaskIds ?? this.busyTaskIds,
      isBatchBusy: isBatchBusy ?? this.isBatchBusy,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<CronTask> get filteredTasks {
    var result = tasks;
    // Filter by status
    if (statusFilter == 'enabled') {
      result = result.where((t) => t.isDisabled == 0).toList();
    } else if (statusFilter == 'disabled') {
      result = result.where((t) => t.isDisabled == 1).toList();
    }
    // Search
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result
          .where(
            (t) =>
                t.name.toLowerCase().contains(q) ||
                t.command.toLowerCase().contains(q),
          )
          .toList();
    }
    return result;
  }
}

class TasksViewModel extends ChangeNotifier {
  final QingLongApi _api;
  TasksUiState _state = TasksUiState();
  Future<void>? _loadInFlight;

  TasksViewModel(this._api);

  TasksUiState get state => _state;

  QingLongApi get api => _api;

  Future<void> loadTasks() async {
    final pending = _loadInFlight;
    if (pending != null) return pending;

    final request = _loadTasks();
    _loadInFlight = request;
    try {
      await request;
    } finally {
      _loadInFlight = null;
    }
  }

  Future<void> _loadTasks() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    try {
      final resp = await _api.getTasks();
      if (resp.code < 400 && resp.data != null) {
        _state = _state.copyWith(tasks: resp.data!.data, isLoading: false);
      } else {
        _state = _state.copyWith(
          isLoading: false,
          error: resp.message ?? '加载失败',
        );
      }
    } catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.toString());
    }
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _state = _state.copyWith(searchQuery: q);
    notifyListeners();
  }

  void setStatusFilter(String f) {
    _state = _state.copyWith(statusFilter: f);
    notifyListeners();
  }

  void toggleSelection(String id) {
    final ids = Set<String>.from(_state.selectedIds);
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    _state = _state.copyWith(selectedIds: ids, isSelectionMode: ids.isNotEmpty);
    notifyListeners();
  }

  void clearSelection() {
    _state = _state.copyWith(selectedIds: {}, isSelectionMode: false);
    notifyListeners();
  }

  void showAddDialog() {
    _state = _state.copyWith(showAddDialog: true);
    notifyListeners();
  }

  void hideAddDialog() {
    _state = _state.copyWith(showAddDialog: false);
    notifyListeners();
  }

  void showEditDialog(CronTask task) {
    _state = _state.copyWith(showEditDialog: task);
    notifyListeners();
  }

  void hideEditDialog() {
    _state = _state.copyWith(clearEditDialog: true);
    notifyListeners();
  }

  bool isTaskBusy(String id) => _state.busyTaskIds.contains(id);

  void _setTaskBusy(String id, bool busy) {
    final ids = Set<String>.from(_state.busyTaskIds);
    if (busy) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    _state = _state.copyWith(busyTaskIds: ids);
    notifyListeners();
  }

  void _setBatchBusy(bool busy) {
    _state = _state.copyWith(isBatchBusy: busy);
    notifyListeners();
  }

  void _ensureSuccess(QingLongResponse<dynamic> response, String fallback) {
    if (response.code >= 400) {
      throw StateError(response.message ?? fallback);
    }
  }

  String _errorText(Object error) {
    final text = error.toString();
    return text.startsWith('Bad state: ') ? text.substring(11) : text;
  }

  Future<String?> _executeSingle(
    String id,
    Future<QingLongResponse<dynamic>> Function(int id) request,
    String failureMessage,
  ) async {
    final numericId = int.tryParse(id);
    if (numericId == null) return '任务编号无效';
    if (_state.isBatchBusy || isTaskBusy(id)) return '任务正在处理中';

    _setTaskBusy(id, true);
    try {
      final response = await request(numericId);
      _ensureSuccess(response, failureMessage);
      await loadTasks();
      return null;
    } catch (error) {
      final message = _errorText(error);
      _state = _state.copyWith(error: message);
      notifyListeners();
      return message;
    } finally {
      _setTaskBusy(id, false);
    }
  }

  Future<String?> _executeBatch(
    Iterable<int> ids,
    Future<QingLongResponse<dynamic>> Function(List<int> ids) request,
    String emptyMessage,
    String failureMessage,
  ) async {
    if (_state.isBatchBusy) return '已有批量操作正在处理';
    final numericIds = ids.toSet().toList();
    if (numericIds.isEmpty) return emptyMessage;
    if (numericIds.any((id) => isTaskBusy(id.toString()))) {
      return '选中的任务正在处理中';
    }

    _setBatchBusy(true);
    clearSelection();
    try {
      final response = await request(numericIds);
      _ensureSuccess(response, failureMessage);
      await loadTasks();
      return null;
    } catch (error) {
      final message = _errorText(error);
      _state = _state.copyWith(error: message);
      notifyListeners();
      return message;
    } finally {
      _setBatchBusy(false);
    }
  }

  Future<String?> addTask(String name, String command, String schedule) async {
    try {
      final response = await _api.addTask(
        TaskRequest(name: name, command: command, schedule: schedule),
      );
      _ensureSuccess(response, '创建任务失败');
      hideAddDialog();
      await loadTasks();
      return null;
    } catch (e) {
      final message = _errorText(e);
      _state = _state.copyWith(error: message);
      notifyListeners();
      return message;
    }
  }

  Future<String?> updateTask(
    String id,
    String name,
    String command,
    String schedule,
  ) async {
    try {
      final response = await _api.updateTask(
        TaskRequest(name: name, command: command, schedule: schedule, id: id),
      );
      _ensureSuccess(response, '保存任务失败');
      hideEditDialog();
      await loadTasks();
      return null;
    } catch (e) {
      final message = _errorText(e);
      _state = _state.copyWith(error: message);
      notifyListeners();
      return message;
    }
  }

  Future<String?> deleteTask(String id) => _executeSingle(
    id,
    (numericId) => _api.deleteTasks([numericId]),
    '删除任务失败',
  );

  Future<String?> deleteSelected() => _executeBatch(
    _state.selectedIds.map(int.tryParse).whereType<int>(),
    _api.deleteTasks,
    '没有可删除的任务',
    '删除任务失败',
  );

  Future<String?> pinTask(String id) =>
      _executeSingle(id, (numericId) => _api.pinTasks([numericId]), '置顶任务失败');

  Future<String?> unpinTask(String id) =>
      _executeSingle(id, (numericId) => _api.unpinTasks([numericId]), '取消置顶失败');

  Future<String?> enableTask(String id) => _executeSingle(
    id,
    (numericId) => _api.enableTasks([numericId]),
    '启用任务失败',
  );

  Future<String?> disableTask(String id) => _executeSingle(
    id,
    (numericId) => _api.disableTasks([numericId]),
    '禁用任务失败',
  );

  Future<String?> runTask(String id) =>
      _executeSingle(id, (numericId) => _api.runTasks([numericId]), '运行任务失败');

  Future<String?> stopTask(String id) async {
    return _executeSingle(
      id,
      (numericId) => _api.stopTasks([numericId]),
      '停止任务失败',
    );
  }

  Future<String?> stopSelected() async {
    final selected = _state.selectedIds;
    final ids = _state.tasks
        .where((task) {
          final id = (task.intId?.toString() ?? task.id) ?? '';
          return selected.contains(id) && task.stateCode == 0;
        })
        .map((task) => task.intId ?? int.tryParse(task.id ?? ''))
        .whereType<int>()
        .toList();
    return _executeBatch(ids, _api.stopTasks, '选中的任务中没有正在运行的任务', '停止任务失败');
  }

  Future<String?> runSelected() => _executeBatch(
    _state.selectedIds.map(int.tryParse).whereType<int>(),
    _api.runTasks,
    '没有选中的任务',
    '运行任务失败',
  );
}

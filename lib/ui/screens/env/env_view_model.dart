import "package:flutter/foundation.dart";
import "package:qinglong_flutter/data/api/qinglong_api.dart";
import "package:qinglong_flutter/data/models/models.dart";

class EnvUiState {
  final List<Environment> envs;
  final bool isLoading;
  final String? error;
  final Set<int> selectedIds;
  final bool isSelectionMode;
  final Set<int> busyIds;
  final bool isBatchBusy;

  EnvUiState({
    this.envs = const [],
    this.isLoading = true,
    this.error,
    this.selectedIds = const {},
    this.isSelectionMode = false,
    this.busyIds = const {},
    this.isBatchBusy = false,
  });

  EnvUiState copyWith({
    List<Environment>? envs,
    bool? isLoading,
    String? error,
    bool clearError = false,
    Set<int>? selectedIds,
    bool? isSelectionMode,
    Set<int>? busyIds,
    bool? isBatchBusy,
  }) {
    return EnvUiState(
      envs: envs ?? this.envs,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedIds: selectedIds ?? this.selectedIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      busyIds: busyIds ?? this.busyIds,
      isBatchBusy: isBatchBusy ?? this.isBatchBusy,
    );
  }
}

class EnvViewModel extends ChangeNotifier {
  final QingLongApi _api;
  EnvUiState _state = EnvUiState();
  Future<void>? _loadInFlight;
  bool _formBusy = false;

  EnvViewModel(this._api);

  EnvUiState get state => _state;

  QingLongApi get api => _api;

  Future<void> loadEnvs() async {
    final pending = _loadInFlight;
    if (pending != null) return pending;
    final request = _loadEnvs();
    _loadInFlight = request;
    try {
      await request;
    } finally {
      _loadInFlight = null;
    }
  }

  Future<void> _loadEnvs() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    try {
      final resp = await _api.getEnvironments();
      if (resp.code < 400 && resp.data != null) {
        _state = _state.copyWith(envs: resp.data!, isLoading: false);
      } else {
        _state = _state.copyWith(
          isLoading: false,
          error: resp.message ?? "加载失败",
        );
      }
    } catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.toString());
    }
    notifyListeners();
  }

  void toggleSelection(int id) {
    final ids = Set<int>.from(_state.selectedIds);
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

  bool isBusy(int id) => _state.busyIds.contains(id);

  void _setBusy(int id, bool busy) {
    final ids = Set<int>.from(_state.busyIds);
    if (busy) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    _state = _state.copyWith(busyIds: ids);
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
    int id,
    Future<QingLongResponse<dynamic>> Function() request,
    String failureMessage,
  ) async {
    if (_state.isBatchBusy || isBusy(id)) return '环境变量正在处理中';
    _setBusy(id, true);
    try {
      final response = await request();
      _ensureSuccess(response, failureMessage);
      await loadEnvs();
      return null;
    } catch (error) {
      final message = _errorText(error);
      _state = _state.copyWith(error: message);
      notifyListeners();
      return message;
    } finally {
      _setBusy(id, false);
    }
  }

  Future<String?> _executeBatch(
    Iterable<int> ids,
    Future<QingLongResponse<dynamic>> Function(List<int>) request,
    String emptyMessage,
    String failureMessage,
  ) async {
    if (_state.isBatchBusy) return '已有批量操作正在处理';
    final selected = ids.toSet().toList();
    if (selected.isEmpty) return emptyMessage;
    if (selected.any(isBusy)) return '选中的环境变量正在处理中';

    _setBatchBusy(true);
    clearSelection();
    try {
      final response = await request(selected);
      _ensureSuccess(response, failureMessage);
      await loadEnvs();
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

  Future<String?> addEnv(String name, String value, String remarks) async {
    if (_formBusy) return '环境变量正在处理中';
    _formBusy = true;
    try {
      final response = await _api.addEnvironment(
        EnvRequest(
          name: name,
          value: value,
          remarks: remarks.isEmpty ? null : remarks,
        ),
      );
      _ensureSuccess(response, '创建环境变量失败');
      await loadEnvs();
      return null;
    } catch (error) {
      final message = _errorText(error);
      _state = _state.copyWith(error: message);
      notifyListeners();
      return message;
    } finally {
      _formBusy = false;
    }
  }

  Future<String?> updateEnv(
    int id,
    String name,
    String value,
    String remarks,
  ) async {
    return _executeSingle(
      id,
      () => _api.updateEnvironment(
        EnvRequest(
          name: name,
          value: value,
          remarks: remarks.isEmpty ? null : remarks,
          id: id,
        ),
      ),
      '保存环境变量失败',
    );
  }

  Future<String?> deleteEnv(int id) =>
      _executeSingle(id, () => _api.deleteEnvironments([id]), '删除环境变量失败');

  Future<String?> deleteSelected() => _executeBatch(
    _state.selectedIds,
    _api.deleteEnvironments,
    '没有选中的环境变量',
    '删除环境变量失败',
  );

  Future<String?> enableEnv(int id) =>
      _executeSingle(id, () => _api.enableEnvironments([id]), '启用环境变量失败');

  Future<String?> disableEnv(int id) =>
      _executeSingle(id, () => _api.disableEnvironments([id]), '禁用环境变量失败');

  Future<String?> enableSelected() => _executeBatch(
    _state.selectedIds,
    _api.enableEnvironments,
    '没有选中的环境变量',
    '启用环境变量失败',
  );

  Future<String?> disableSelected() => _executeBatch(
    _state.selectedIds,
    _api.disableEnvironments,
    '没有选中的环境变量',
    '禁用环境变量失败',
  );
}

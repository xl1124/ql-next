import 'package:flutter/foundation.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/local/local_storage.dart';
import 'package:qinglong_flutter/data/models/models.dart';

class SettingsUiState {
  final String username;
  final String serverUrl;
  final String version;
  final List<AccountEntry> accounts;
  final bool twoFactorActivated;
  final bool isLoading;
  final bool isLoggingOut;
  final String? error;

  SettingsUiState({
    this.username = '',
    this.serverUrl = '',
    this.version = '',
    this.accounts = const [],
    this.twoFactorActivated = false,
    this.isLoading = true,
    this.isLoggingOut = false,
    this.error,
  });

  SettingsUiState copyWith({
    String? username,
    String? serverUrl,
    String? version,
    List<AccountEntry>? accounts,
    bool? twoFactorActivated,
    bool? isLoading,
    bool? isLoggingOut,
    bool clearError = false,
    String? error,
  }) {
    return SettingsUiState(
      username: username ?? this.username,
      serverUrl: serverUrl ?? this.serverUrl,
      version: version ?? this.version,
      accounts: accounts ?? this.accounts,
      twoFactorActivated: twoFactorActivated ?? this.twoFactorActivated,
      isLoading: isLoading ?? this.isLoading,
      isLoggingOut: isLoggingOut ?? this.isLoggingOut,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SettingsViewModel extends ChangeNotifier {
  final QingLongApi _api;
  final LocalStorage _storage;
  final VoidCallback onLogout;
  SettingsUiState _state = SettingsUiState();

  SettingsViewModel(this._api, this._storage, {required this.onLogout});

  SettingsUiState get state => _state;

  void loadData() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    try {
      final srv = await _storage.getServerUrl() ?? '';
      final user = await _storage.getUsername() ?? '';
      final accounts = await _storage.getAccounts();
      String version = '';
      var twoFactorActivated = false;

      try {
        final sysResp = await _api.getSystemInfo();
        if (sysResp.data != null) {
          version = sysResp.data!.version ?? '';
        }
      } catch (_) {}

      try {
        final userResp = await _api.getUserInfo();
        twoFactorActivated = userResp.data?.twoFactorActivated ?? false;
      } catch (_) {}

      _state = _state.copyWith(
        username: user,
        serverUrl: srv,
        version: version,
        accounts: accounts,
        twoFactorActivated: twoFactorActivated,
        isLoading: false,
      );
    } catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.toString());
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _state = _state.copyWith(isLoggingOut: true);
    notifyListeners();
    try {
      await _api.logout();
    } catch (_) {}
    onLogout();
  }

  Future<void> switchAccount(AccountEntry entry) async {
    try {
      await _storage.switchAccount(entry);
      loadData();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  Future<void> removeAccount(AccountEntry entry) async {
    try {
      await _storage.removeAccount(entry);
      final accounts = await _storage.getAccounts();
      _state = _state.copyWith(accounts: accounts);
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }
}

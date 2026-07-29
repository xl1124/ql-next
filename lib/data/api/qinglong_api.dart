import 'dart:typed_data';

import '../models/models.dart';
import 'api_client.dart';
import '../local/local_storage.dart';

class QingLongApi {
  final ApiClient client;
  final LocalStorage _st;

  QingLongApi({ApiClient? client, LocalStorage? storage})
    : client = client ?? ApiClient(storage: storage),
      _st = storage ?? LocalStorage();

  QingLongApi._(this.client, this._st);

  factory QingLongApi.unauth() {
    final s = LocalStorage();
    return QingLongApi._(ApiClient(storage: s), s);
  }

  factory QingLongApi.auth() {
    final s = LocalStorage();
    return QingLongApi._(ApiClient(storage: s), s);
  }

  QingLongResponse<String> _stringResponse(Map<String, dynamic> response) {
    return QingLongResponse.fromJson(
      response,
      (data) => data?.toString() ?? '',
    );
  }

  // ==== Auth ====

  Future<QingLongResponse<LoginData>> login(
    String srv,
    String user,
    String pwd,
  ) async {
    final resp = await client.postTo(
      srv,
      'api/user/login',
      body: LoginRequest(username: user, password: pwd).toJson(),
    );
    final r = QingLongResponse.fromJson(
      resp,
      (d) => LoginData.fromJson(d as Map<String, dynamic>),
    );
    final token = r.data?.token;
    if (token != null && token.isNotEmpty) {
      await _st.saveLoginInfo(srv, token, user);
    }
    return r;
  }

  Future<void> logout() async {
    try {
      await client.post('api/user/logout');
    } catch (_) {}
    await _st.clearLoginInfo();
  }

  Future<QingLongResponse<LoginData>> twoFactorLogin(
    String srv,
    String user,
    String pwd,
    String code,
  ) async {
    final resp = await client.putTo(
      srv,
      'api/user/two-factor/login',
      body: TwoFactorRequest(
        username: user,
        password: pwd,
        code: code,
      ).toJson(),
    );
    final result = QingLongResponse.fromJson(
      resp,
      (d) => LoginData.fromJson(d as Map<String, dynamic>),
    );
    final token = result.data?.token;
    if (token != null && token.isNotEmpty) {
      await _st.saveLoginInfo(srv, token, user);
    }
    return result;
  }

  Future<QingLongResponse<dynamic>> initAccount(String user, String pwd) async {
    final resp = await client.put(
      'api/user/init',
      body: {'username': user, 'password': pwd},
    );
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<UserInfo>> getUserInfo() async {
    final resp = await client.get('api/user');
    return QingLongResponse.fromJson(
      resp,
      (d) => UserInfo.fromJson(d as Map<String, dynamic>),
    );
  }

  // ==== System ====

  Future<QingLongResponse<SystemInfo>> getSystemInfo() async {
    final resp = await client.get('api/system');
    return QingLongResponse.fromJson(
      resp,
      (d) => SystemInfo.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<QingLongResponse<SystemUpdateInfo>> checkSystemUpdate() async {
    final resp = await client.put('api/system/update-check');
    return QingLongResponse.fromJson(
      resp,
      (d) => SystemUpdateInfo.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<QingLongResponse<dynamic>> updateSystem() async {
    final resp = await client.put('api/system/update');
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> reloadSystem({String? type}) async {
    final resp = await client.put(
      'api/system/reload',
      body: type == null ? null : {'type': type},
    );
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<SystemConfig>> getSystemConfig() async {
    final resp = await client.get('api/system/config');
    return QingLongResponse.fromJson(
      resp,
      (d) => SystemConfig.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<QingLongResponse<dynamic>> _updateSystemConfig(
    String name,
    dynamic value,
  ) async {
    final resp = await client.put('api/system/config/$name', body: value);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> updateLogRemoveFrequency(int? value) =>
      _updateSystemConfig('log-remove-frequency', {
        'logRemoveFrequency': value,
      });

  Future<QingLongResponse<dynamic>> updateCronConcurrency(int? value) =>
      _updateSystemConfig('cron-concurrency', {'cronConcurrency': value});

  Future<QingLongResponse<dynamic>> updateDependenceProxy(String value) =>
      _updateSystemConfig('dependence-proxy', {'dependenceProxy': value});

  Future<QingLongResponse<dynamic>> updatePythonMirror(String value) =>
      _updateSystemConfig('python-mirror', {'pythonMirror': value});

  Future<QingLongResponse<dynamic>> updateTimezone(String value) =>
      _updateSystemConfig('timezone', {'timezone': value});

  Future<QingLongResponse<dynamic>> updateLanguage(String value) =>
      _updateSystemConfig('lang', {'lang': value});

  Future<QingLongResponse<dynamic>> updatePanelTitle(String value) =>
      _updateSystemConfig('panel-title', {'panelTitle': value});

  Future<QingLongResponse<dynamic>> updateGlobalSshKey(String value) =>
      _updateSystemConfig('global-ssh-key', {'globalSshKey': value});

  Future<QingLongResponse<SystemHealth>> getHealth() async {
    final resp = await client.get('api/health');
    return QingLongResponse.fromJson(
      resp,
      (d) => SystemHealth.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<Uint8List> exportSystemData({List<String>? type}) async {
    final bytes = await client.download(
      'api/system/data/export',
      method: 'PUT',
      body: {'type': type ?? const <String>[]},
    );
    return Uint8List.fromList(bytes);
  }

  Future<QingLongResponse<dynamic>> importSystemData({
    required String filename,
    required List<int> bytes,
  }) async {
    final resp = await client.uploadMultipart(
      'api/system/data/import',
      method: 'PUT',
      fieldName: 'data',
      filename: filename,
      bytes: bytes,
    );
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<TwoFactorInitData>> initTwoFactor() async {
    final resp = await client.get('api/user/two-factor/init');
    return QingLongResponse.fromJson(
      resp,
      (d) => TwoFactorInitData.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<QingLongResponse<bool>> activateTwoFactor(String code) async {
    final resp = await client.put(
      'api/user/two-factor/active',
      body: {'code': code},
    );
    return QingLongResponse.fromJson(resp, (d) => d == true);
  }

  Future<QingLongResponse<bool>> deactivateTwoFactor() async {
    final resp = await client.put('api/user/two-factor/deactivate');
    return QingLongResponse.fromJson(resp, (d) => d == true);
  }

  Future<QingLongResponse<dynamic>> updateUsernameAndPassword(
    String username,
    String password,
  ) async {
    final resp = await client.put(
      'api/user/init',
      body: {'username': username, 'password': password},
    );
    return QingLongResponse.fromJson(resp, null);
  }

  // ==== Open API Applications ====

  Future<QingLongResponse<List<OpenApp>>> getOpenApps() async {
    final resp = await client.get('api/apps');
    return QingLongResponse.fromJson(
      resp,
      (d) => (d as List)
          .whereType<Map<String, dynamic>>()
          .map(OpenApp.fromJson)
          .toList(),
    );
  }

  Future<QingLongResponse<OpenApp>> createOpenApp(
    String name,
    List<String> scopes,
  ) async {
    final resp = await client.post(
      'api/apps',
      body: {'name': name, 'scopes': scopes},
    );
    return QingLongResponse.fromJson(
      resp,
      (d) => OpenApp.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<QingLongResponse<OpenApp>> updateOpenApp(
    int id,
    String name,
    List<String> scopes,
  ) async {
    final resp = await client.put(
      'api/apps',
      body: {'id': id, 'name': name, 'scopes': scopes},
    );
    return QingLongResponse.fromJson(
      resp,
      (d) => OpenApp.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<QingLongResponse<dynamic>> deleteOpenApps(List<int> ids) async {
    final resp = await client.delete('api/apps', body: ids);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<OpenApp>> resetOpenAppSecret(int id) async {
    final resp = await client.put('api/apps/$id/reset-secret');
    return QingLongResponse.fromJson(
      resp,
      (d) => OpenApp.fromJson(d as Map<String, dynamic>),
    );
  }

  // ==== Login Logs ====

  Future<QingLongResponse<List<LoginLog>>> getLoginLogs() async {
    final resp = await client.get('api/user/login-log');
    return QingLongResponse.fromJson(
      resp,
      (d) => (d as List)
          .map((e) => LoginLog.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // ==== Notification Config ====

  Future<QingLongResponse<NotificationConfig>> getNotificationConfig() async {
    final resp = await client.get('api/user/notification');
    return QingLongResponse.fromJson(
      resp,
      (d) => NotificationConfig.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<QingLongResponse<dynamic>> updateNotificationConfig(
    NotificationConfig cfg,
  ) async {
    final resp = await client.put('api/user/notification', body: cfg.toJson());
    return QingLongResponse.fromJson(resp, null);
  }

  // ==== Config Files ====

  Future<QingLongResponse<List<ConfigFileInfo>>> getConfigFiles() async {
    final resp = await client.get('api/configs/files');
    return QingLongResponse.fromJson(
      resp,
      (d) => (d as List)
          .map((e) => ConfigFileInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<QingLongResponse<String>> getConfigDetail(String path) async {
    final resp = await client.get(
      'api/configs/detail',
      queryParams: {'path': path},
    );
    return _stringResponse(resp);
  }

  Future<QingLongResponse<dynamic>> saveConfig(
    String name,
    String content,
  ) async {
    final resp = await client.post(
      'api/configs/save',
      body: {'name': name, 'content': content},
    );
    return QingLongResponse.fromJson(resp, null);
  }

  // ==== Tasks ====

  Future<QingLongResponse<String>> getTaskLog(int id) async {
    final resp = await client.get("api/crons/$id/log");
    return _stringResponse(resp);
  }

  Future<QingLongResponse<List<TaskLogFile>>> getTaskLogFiles(int id) async {
    final resp = await client.get("api/crons/$id/logs");
    return QingLongResponse.fromJson(
      resp,
      (d) => (d as List)
          .map((e) => TaskLogFile.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<QingLongResponse<String>> getTaskLogDetail(
    String filename,
    String directory,
  ) async {
    final resp = await client.get(
      'api/logs/detail',
      queryParams: {'file': filename, 'path': directory},
    );
    return _stringResponse(resp);
  }

  Future<QingLongResponse<String>> getLogDetail(
    String filename,
    String directory,
  ) async {
    final resp = await client.get(
      'api/logs/detail',
      queryParams: {'file': filename, 'path': directory},
    );
    return _stringResponse(resp);
  }

  Future<QingLongResponse<List<LogFileEntry>>> getLogs() async {
    final resp = await client.get('api/logs');
    return QingLongResponse.fromJson(
      resp,
      (d) => (d as List)
          .whereType<Map>()
          .map((item) => LogFileEntry.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  Future<Uint8List> downloadLog(String filename, String directory) async {
    final bytes = await client.download(
      'api/logs/download',
      method: 'POST',
      body: {'filename': filename, 'path': directory},
    );
    return Uint8List.fromList(bytes);
  }

  Future<QingLongResponse<CronListData>> getTasks() async {
    final resp = await client.get('api/crons');
    return QingLongResponse.fromJson(
      resp,
      (d) => CronListData.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<QingLongResponse<CronTask>> addTask(TaskRequest req) async {
    final resp = await client.post('api/crons', body: req.toJson());
    return QingLongResponse.fromJson(
      resp,
      (d) => CronTask.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<QingLongResponse<CronTask>> updateTask(TaskRequest req) async {
    final resp = await client.put('api/crons', body: req.toJson());
    return QingLongResponse.fromJson(
      resp,
      (d) => CronTask.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<QingLongResponse<dynamic>> deleteTasks(List<int> ids) async {
    final resp = await client.delete('api/crons', body: ids);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> runTasks(List<int> ids) async {
    final resp = await client.put('api/crons/run', body: ids);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> stopTasks(List<int> ids) async {
    final resp = await client.put('api/crons/stop', body: ids);
    return QingLongResponse.fromJson(resp, null);
  }

  // ==== Task Actions ====

  Future<QingLongResponse<dynamic>> enableTasks(List<int> ids) async {
    final resp = await client.put("api/crons/enable", body: ids);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> disableTasks(List<int> ids) async {
    final resp = await client.put("api/crons/disable", body: ids);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> pinTasks(List<int> ids) async {
    final resp = await client.put("api/crons/pin", body: ids);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> unpinTasks(List<int> ids) async {
    final resp = await client.put("api/crons/unpin", body: ids);
    return QingLongResponse.fromJson(resp, null);
  }

  // ==== Env ====
  // ==== Subscriptions ====
  Future<QingLongResponse<List<SubscriptionInfo>>> getSubscriptions({
    String searchValue = '',
  }) async {
    final resp = await client.get(
      'api/subscriptions',
      queryParams: searchValue.trim().isEmpty
          ? null
          : {'searchValue': searchValue.trim()},
    );
    return QingLongResponse.fromJson(
      resp,
      (d) => (d as List)
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionInfo.fromJson)
          .toList(),
    );
  }

  Future<QingLongResponse<SubscriptionInfo>> createSubscription(
    Map<String, dynamic> payload,
  ) async {
    final resp = await client.post('api/subscriptions', body: payload);
    return QingLongResponse.fromJson(
      resp,
      (d) => SubscriptionInfo.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<QingLongResponse<SubscriptionInfo>> updateSubscription(
    Map<String, dynamic> payload,
  ) async {
    final resp = await client.put('api/subscriptions', body: payload);
    return QingLongResponse.fromJson(
      resp,
      (d) => SubscriptionInfo.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<QingLongResponse<dynamic>> runSubscriptions(List<int> ids) async {
    final resp = await client.put('api/subscriptions/run', body: ids);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> stopSubscriptions(List<int> ids) async {
    final resp = await client.put('api/subscriptions/stop', body: ids);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> enableSubscriptions(List<int> ids) async {
    final resp = await client.put('api/subscriptions/enable', body: ids);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> disableSubscriptions(List<int> ids) async {
    final resp = await client.put('api/subscriptions/disable', body: ids);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> deleteSubscriptions(
    List<int> ids, {
    bool force = false,
  }) async {
    final resp = await client.delete(
      'api/subscriptions',
      body: ids,
      queryParams: force ? {'force': 'true'} : null,
    );
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<String>> getSubscriptionLog(int id) async {
    final resp = await client.get('api/subscriptions/$id/log');
    return _stringResponse(resp);
  }

  Future<QingLongResponse<List<TaskLogFile>>> getSubscriptionLogs(
    int id,
  ) async {
    final resp = await client.get('api/subscriptions/$id/logs');
    return QingLongResponse.fromJson(
      resp,
      (d) => (d as List)
          .whereType<Map<String, dynamic>>()
          .map(TaskLogFile.fromJson)
          .toList(),
    );
  }

  // ==== Dependencies ====
  Future<QingLongResponse<List<dynamic>>> getDependencies({
    String searchValue = '',
    String? type,
    List<int>? status,
  }) async {
    final resp = await client.get(
      'api/dependencies',
      queryParams: {
        if (searchValue.trim().isNotEmpty) 'searchValue': searchValue.trim(),
        if (type != null && type.isNotEmpty) 'type': type,
        if (status != null && status.isNotEmpty) 'status': status.join(','),
      },
    );
    return QingLongResponse.fromJson(
      resp,
      (d) => (d as List).map((e) => e).toList(),
    );
  }

  Future<QingLongResponse<dynamic>> createDependencies(
    List<Map<String, dynamic>> dependencies,
  ) async {
    final resp = await client.post('api/dependencies', body: dependencies);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> updateDependency(
    Map<String, dynamic> dependency,
  ) async {
    final resp = await client.put('api/dependencies', body: dependency);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> deleteDependencies(
    List<int> ids, {
    bool force = false,
  }) async {
    final resp = await client.delete(
      'api/dependencies${force ? '/force' : ''}',
      body: ids,
    );
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> reinstallDependencies(List<int> ids) async {
    final resp = await client.put('api/dependencies/reinstall', body: ids);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> cancelDependencies(List<int> ids) async {
    final resp = await client.put('api/dependencies/cancel', body: ids);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<DependencyInfo>> getDependencyDetail(int id) async {
    final resp = await client.get('api/dependencies/$id');
    return QingLongResponse.fromJson(
      resp,
      (d) => DependencyInfo.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<QingLongResponse<List<Environment>>> getEnvironments() async {
    final resp = await client.get("api/envs");
    return QingLongResponse.fromJson(
      resp,
      (d) => (d as List)
          .map((e) => Environment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<QingLongResponse<dynamic>> addEnvironment(EnvRequest req) async {
    final resp = await client.post("api/envs", body: [req.toJson()]);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> updateEnvironment(EnvRequest req) async {
    final resp = await client.put("api/envs", body: req.toJson());
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> deleteEnvironments(dynamic ids) async {
    final resp = await client.delete("api/envs", body: ids);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> enableEnvironments(dynamic ids) async {
    final resp = await client.put("api/envs/enable", body: ids);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> disableEnvironments(dynamic ids) async {
    final resp = await client.put("api/envs/disable", body: ids);
    return QingLongResponse.fromJson(resp, null);
  }
  // ==== Scripts ====

  Future<QingLongResponse<List<ScriptFile>>> getScripts({
    String path = '',
  }) async {
    final resp = await client.get(
      'api/scripts',
      queryParams: path.isEmpty ? null : {'path': path},
    );
    return QingLongResponse.fromJson(
      resp,
      (d) => (d as List)
          .map((e) => ScriptFile.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<QingLongResponse<String>> getScriptDetail({
    required String filename,
    String path = '',
  }) async {
    final resp = await client.get(
      'api/scripts/detail',
      queryParams: {'file': filename, 'path': path},
    );
    return QingLongResponse.fromJson(resp, (d) => d?.toString() ?? '');
  }

  Future<QingLongResponse<dynamic>> saveScript({
    required String filename,
    required String content,
    String path = '',
  }) async {
    final resp = await client.put(
      'api/scripts',
      body: {'filename': filename, 'path': path, 'content': content},
    );
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> createScript({
    required String filename,
    required String content,
    String path = '',
  }) async {
    final resp = await client.post(
      'api/scripts',
      body: {
        'filename': filename,
        'path': path,
        'content': content,
        'originFilename': filename,
      },
    );
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> createScriptDirectory({
    required String directory,
    String path = '',
  }) async {
    final resp = await client.post(
      'api/scripts',
      body: {'filename': directory, 'directory': directory, 'path': path},
    );
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> uploadScriptFile({
    required String filename,
    required List<int> bytes,
    String path = '',
  }) async {
    final resp = await client.uploadMultipart(
      'api/scripts',
      fieldName: 'file',
      filename: filename,
      bytes: bytes,
      fields: {'filename': filename, 'path': path},
    );
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> deleteScript({
    required String filename,
    String path = '',
    String type = 'file',
  }) async {
    final resp = await client.delete(
      'api/scripts',
      body: {'filename': filename, 'path': path, 'type': type},
    );
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> renameScript({
    required String filename,
    required String newFilename,
    String path = '',
  }) async {
    final resp = await client.put(
      'api/scripts/rename',
      body: {'filename': filename, 'newFilename': newFilename, 'path': path},
    );
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> runScript({
    required String filename,
    required String content,
    String path = '',
  }) async {
    final resp = await client.put(
      'api/scripts/run',
      body: {'filename': filename, 'path': path, 'content': content},
    );
    return QingLongResponse.fromJson(resp, null);
  }

  Future<QingLongResponse<dynamic>> stopScript({
    required String filename,
    String path = '',
    int? pid,
  }) async {
    final body = <String, dynamic>{'filename': filename, 'path': path};
    if (pid != null) body['pid'] = pid;
    final resp = await client.put('api/scripts/stop', body: body);
    return QingLongResponse.fromJson(resp, null);
  }

  Future<Uint8List> downloadScript({
    required String filename,
    String path = '',
  }) async {
    final bytes = await client.download(
      'api/scripts/download',
      method: 'POST',
      body: {'filename': filename, 'path': path},
    );
    return Uint8List.fromList(bytes);
  }

  // ==== Dashboard ====

  Future<QingLongResponse<DashboardOverview>> getDashboardOverview() async {
    final resp = await client.get('api/dashboard/overview');
    return QingLongResponse.fromJson(
      resp,
      (d) => DashboardOverview.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<QingLongResponse<List<dynamic>>> getDashboardTrend() async {
    final resp = await client.get(
      'api/dashboard/trend',
      queryParams: {'days': '7'},
    );
    return QingLongResponse.fromJson(resp, (d) => (d as List));
  }

  Future<QingLongResponse<List<dynamic>>> getDashboardTopTime() async {
    final resp = await client.get('api/dashboard/top-time');
    return QingLongResponse.fromJson(resp, (d) => (d as List));
  }

  Future<QingLongResponse<List<dynamic>>> getDashboardTopCount() async {
    final resp = await client.get('api/dashboard/top-count');
    return QingLongResponse.fromJson(resp, (d) => (d as List));
  }

  Future<QingLongResponse<DashboardRuntime>> getDashboardRuntime() async {
    final resp = await client.get('api/dashboard/runtime');
    return QingLongResponse.fromJson(
      resp,
      (d) => DashboardRuntime.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<QingLongResponse<Map<String, dynamic>>> getDashboardSystem() async {
    final resp = await client.get('api/dashboard/system');
    return QingLongResponse.fromJson(resp, (d) => d as Map<String, dynamic>);
  }
}

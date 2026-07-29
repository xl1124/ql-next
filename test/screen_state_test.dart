import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/local/local_storage.dart';
import 'package:qinglong_flutter/data/models/models.dart';
import 'package:qinglong_flutter/data/local/theme_controller.dart';
import 'package:qinglong_flutter/app.dart';
import 'package:qinglong_flutter/ui/screens/config/config_screen.dart';
import 'package:qinglong_flutter/ui/screens/dashboard/dashboard_screen.dart';
import 'package:qinglong_flutter/ui/screens/env/env_screen.dart';
import 'package:qinglong_flutter/ui/screens/settings/dependency_screen.dart';
import 'package:qinglong_flutter/ui/screens/settings/settings_screen.dart';
import 'package:qinglong_flutter/ui/screens/tasks/tasks_screen.dart';
import 'package:qinglong_flutter/ui/screens/tasks/tasks_view_model.dart';
import 'package:qinglong_flutter/ui/screens/login/login_screen.dart';
import 'package:qinglong_flutter/ui/components/floating_nav_bar.dart';

class FakeQingLongApi extends QingLongApi {
  FakeQingLongApi({
    this.dashboardError,
    this.dashboardOverviewResponse,
    this.dashboardTrendResponse,
    this.dashboardTopTimeResponse,
    this.dashboardTopCountResponse,
    this.dashboardSystemResponse,
    this.systemInfoResponse,
    this.userInfoResponse,
    this.openAppsResponse,
    this.updateUsernameResponse,
    this.loginResponse,
    this.loginPending,
    this.loginError,
    this.twoFactorResponse,
    this.twoFactorError,
    this.logoutStorage,
    this.environmentResponse,
    this.environmentPending,
    this.taskResponse,
    this.taskPending,
    this.runTaskPending,
    this.configResponse,
    this.configPending,
    this.configDetailResponse,
    this.configDetailPending,
    this.saveConfigResponse,
    this.saveConfigError,
    this.dependencyResponse,
    this.dependencyPending,
    this.dependencyDetailResponse,
    this.createDependencyResponse,
    this.updateDependencyResponse,
    this.dependencyOperationResponse,
  }) : super();

  final Object? dashboardError;
  final QingLongResponse<DashboardOverview>? dashboardOverviewResponse;
  final QingLongResponse<List<dynamic>>? dashboardTrendResponse;
  final QingLongResponse<List<dynamic>>? dashboardTopTimeResponse;
  final QingLongResponse<List<dynamic>>? dashboardTopCountResponse;
  final QingLongResponse<Map<String, dynamic>>? dashboardSystemResponse;
  final QingLongResponse<SystemInfo>? systemInfoResponse;
  final QingLongResponse<UserInfo>? userInfoResponse;
  final QingLongResponse<List<OpenApp>>? openAppsResponse;
  final QingLongResponse<dynamic>? updateUsernameResponse;
  final QingLongResponse<LoginData>? loginResponse;
  final Future<QingLongResponse<LoginData>>? loginPending;
  final Object? loginError;
  final QingLongResponse<LoginData>? twoFactorResponse;
  final Object? twoFactorError;
  LocalStorage? logoutStorage;
  final QingLongResponse<List<Environment>>? environmentResponse;
  final Future<QingLongResponse<List<Environment>>>? environmentPending;
  final QingLongResponse<CronListData>? taskResponse;
  final Future<QingLongResponse<CronListData>>? taskPending;
  final Future<QingLongResponse<dynamic>>? runTaskPending;
  final QingLongResponse<List<ConfigFileInfo>>? configResponse;
  final Future<QingLongResponse<List<ConfigFileInfo>>>? configPending;
  final QingLongResponse<String>? configDetailResponse;
  final Future<QingLongResponse<String>>? configDetailPending;
  final QingLongResponse<dynamic>? saveConfigResponse;
  final Object? saveConfigError;
  final QingLongResponse<List<dynamic>>? dependencyResponse;
  final Future<QingLongResponse<List<dynamic>>>? dependencyPending;
  final QingLongResponse<DependencyInfo>? dependencyDetailResponse;
  final QingLongResponse<dynamic>? createDependencyResponse;
  final QingLongResponse<dynamic>? updateDependencyResponse;
  final QingLongResponse<dynamic>? dependencyOperationResponse;
  final runTaskCalls = <List<int>>[];
  final enableTaskCalls = <List<int>>[];
  final disableTaskCalls = <List<int>>[];
  final deleteTaskCalls = <List<int>>[];
  final updateEnvironmentCalls = <EnvRequest>[];
  final enableEnvironmentCalls = <List<int>>[];
  final disableEnvironmentCalls = <List<int>>[];
  final deleteEnvironmentCalls = <List<int>>[];
  final configDetailCalls = <String>[];
  final saveConfigCalls = <({String filename, String content})>[];
  final dependencyCalls = <({String searchValue, String? type})>[];
  final createDependencyCalls = <List<Map<String, dynamic>>>[];
  final updateDependencyCalls = <Map<String, dynamic>>[];
  final dependencyOperationCalls = <String>[];
  final updateUsernameCalls = <({String username, String password})>[];
  final loginCalls = <({String server, String username, String password})>[];
  final twoFactorCalls =
      <({String server, String username, String password, String code})>[];
  var logoutCalls = 0;
  var dashboardOverviewCalls = 0;

  @override
  Future<QingLongResponse<DashboardOverview>> getDashboardOverview() async {
    dashboardOverviewCalls++;
    if (dashboardError != null) throw dashboardError!;
    return dashboardOverviewResponse ??
        QingLongResponse<DashboardOverview>(
          code: 200,
          data: DashboardOverview(),
        );
  }

  @override
  Future<QingLongResponse<List<dynamic>>> getDashboardTrend() async {
    return dashboardTrendResponse ??
        QingLongResponse<List<dynamic>>(code: 200, data: const []);
  }

  @override
  Future<QingLongResponse<List<dynamic>>> getDashboardTopTime() async {
    return dashboardTopTimeResponse ??
        QingLongResponse<List<dynamic>>(code: 200, data: const []);
  }

  @override
  Future<QingLongResponse<List<dynamic>>> getDashboardTopCount() async {
    return dashboardTopCountResponse ??
        QingLongResponse<List<dynamic>>(code: 200, data: const []);
  }

  @override
  Future<QingLongResponse<Map<String, dynamic>>> getDashboardSystem() async {
    return dashboardSystemResponse ??
        QingLongResponse<Map<String, dynamic>>(code: 200, data: const {});
  }

  @override
  Future<QingLongResponse<SystemInfo>> getSystemInfo() async {
    return systemInfoResponse ??
        QingLongResponse<SystemInfo>(
          code: 200,
          data: SystemInfo(version: '2.18.0'),
        );
  }

  @override
  Future<QingLongResponse<UserInfo>> getUserInfo() async {
    return userInfoResponse ??
        QingLongResponse<UserInfo>(
          code: 200,
          data: UserInfo(username: 'admin'),
        );
  }

  @override
  Future<QingLongResponse<List<Environment>>> getEnvironments() {
    if (environmentPending != null) return environmentPending!;
    return Future.value(
      environmentResponse ??
          QingLongResponse<List<Environment>>(code: 200, data: const []),
    );
  }

  @override
  Future<QingLongResponse<CronListData>> getTasks() {
    if (taskPending != null) return taskPending!;
    return Future.value(
      taskResponse ?? QingLongResponse<CronListData>(data: CronListData()),
    );
  }

  @override
  Future<QingLongResponse<List<ConfigFileInfo>>> getConfigFiles() {
    if (configPending != null) return configPending!;
    return Future.value(
      configResponse ?? QingLongResponse<List<ConfigFileInfo>>(data: const []),
    );
  }

  @override
  Future<QingLongResponse<String>> getConfigDetail(String path) {
    configDetailCalls.add(path);
    if (configDetailPending != null) return configDetailPending!;
    return Future.value(
      configDetailResponse ??
          QingLongResponse<String>(code: 200, data: 'initial config'),
    );
  }

  @override
  Future<QingLongResponse<dynamic>> saveConfig(
    String name,
    String content,
  ) async {
    saveConfigCalls.add((filename: name, content: content));
    if (saveConfigError != null) throw saveConfigError!;
    return saveConfigResponse ??
        QingLongResponse<dynamic>(code: 200, data: true);
  }

  @override
  Future<QingLongResponse<dynamic>> updateUsernameAndPassword(
    String username,
    String password,
  ) async {
    updateUsernameCalls.add((username: username, password: password));
    return updateUsernameResponse ??
        QingLongResponse<dynamic>(code: 200, data: true);
  }

  @override
  Future<QingLongResponse<LoginData>> login(
    String server,
    String username,
    String password,
  ) async {
    loginCalls.add((server: server, username: username, password: password));
    if (loginError != null) throw loginError!;
    if (loginPending != null) return loginPending!;
    return loginResponse ??
        QingLongResponse<LoginData>(
          code: 200,
          data: LoginData(token: 'test-token'),
        );
  }

  @override
  Future<QingLongResponse<LoginData>> twoFactorLogin(
    String server,
    String username,
    String password,
    String code,
  ) async {
    twoFactorCalls.add((
      server: server,
      username: username,
      password: password,
      code: code,
    ));
    if (twoFactorError != null) throw twoFactorError!;
    return twoFactorResponse ??
        QingLongResponse<LoginData>(
          code: 200,
          data: LoginData(token: 'two-factor-token'),
        );
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    await logoutStorage?.clearLoginInfo();
  }

  @override
  Future<QingLongResponse<List<OpenApp>>> getOpenApps() async {
    return openAppsResponse ??
        QingLongResponse<List<OpenApp>>(code: 200, data: const []);
  }

  @override
  Future<QingLongResponse<List<SubscriptionInfo>>> getSubscriptions({
    String searchValue = '',
  }) async {
    return QingLongResponse<List<SubscriptionInfo>>(code: 200, data: const []);
  }

  @override
  Future<QingLongResponse<List<dynamic>>> getDependencies({
    String searchValue = '',
    String? type,
    List<int>? status,
  }) async {
    dependencyCalls.add((searchValue: searchValue, type: type));
    if (dependencyPending != null) return dependencyPending!;
    return dependencyResponse ??
        QingLongResponse<List<dynamic>>(code: 200, data: const []);
  }

  @override
  Future<QingLongResponse<dynamic>> createDependencies(
    List<Map<String, dynamic>> dependencies,
  ) async {
    createDependencyCalls.add(
      dependencies.map((item) => Map<String, dynamic>.from(item)).toList(),
    );
    return createDependencyResponse ??
        QingLongResponse<dynamic>(code: 200, data: true);
  }

  @override
  Future<QingLongResponse<dynamic>> updateDependency(
    Map<String, dynamic> dependency,
  ) async {
    updateDependencyCalls.add(Map<String, dynamic>.from(dependency));
    return updateDependencyResponse ??
        QingLongResponse<dynamic>(code: 200, data: true);
  }

  @override
  Future<QingLongResponse<dynamic>> deleteDependencies(
    List<int> ids, {
    bool force = false,
  }) async {
    dependencyOperationCalls.add(force ? 'forceDelete' : 'delete');
    return dependencyOperationResponse ??
        QingLongResponse<dynamic>(code: 200, data: true);
  }

  @override
  Future<QingLongResponse<dynamic>> reinstallDependencies(List<int> ids) async {
    dependencyOperationCalls.add('reinstall');
    return dependencyOperationResponse ??
        QingLongResponse<dynamic>(code: 200, data: true);
  }

  @override
  Future<QingLongResponse<dynamic>> cancelDependencies(List<int> ids) async {
    dependencyOperationCalls.add('cancel');
    return dependencyOperationResponse ??
        QingLongResponse<dynamic>(code: 200, data: true);
  }

  @override
  Future<QingLongResponse<DependencyInfo>> getDependencyDetail(int id) async {
    return dependencyDetailResponse ??
        QingLongResponse<DependencyInfo>(
          code: 200,
          data: const DependencyInfo(log: ['dependency log']),
        );
  }

  @override
  Future<QingLongResponse<dynamic>> runTasks(List<int> ids) async {
    runTaskCalls.add(List<int>.from(ids));
    if (runTaskPending != null) return runTaskPending!;
    return QingLongResponse<dynamic>(data: true);
  }

  @override
  Future<QingLongResponse<dynamic>> enableTasks(List<int> ids) async {
    enableTaskCalls.add(List<int>.from(ids));
    return QingLongResponse<dynamic>(data: true);
  }

  @override
  Future<QingLongResponse<dynamic>> disableTasks(List<int> ids) async {
    disableTaskCalls.add(List<int>.from(ids));
    return QingLongResponse<dynamic>(data: true);
  }

  @override
  Future<QingLongResponse<dynamic>> deleteTasks(List<int> ids) async {
    deleteTaskCalls.add(List<int>.from(ids));
    return QingLongResponse<dynamic>(data: true);
  }

  @override
  Future<QingLongResponse<dynamic>> updateEnvironment(
    EnvRequest request,
  ) async {
    updateEnvironmentCalls.add(request);
    return QingLongResponse<dynamic>(data: true);
  }

  @override
  Future<QingLongResponse<dynamic>> enableEnvironments(dynamic ids) async {
    enableEnvironmentCalls.add(List<int>.from(ids as List));
    return QingLongResponse<dynamic>(data: true);
  }

  @override
  Future<QingLongResponse<dynamic>> disableEnvironments(dynamic ids) async {
    disableEnvironmentCalls.add(List<int>.from(ids as List));
    return QingLongResponse<dynamic>(data: true);
  }

  @override
  Future<QingLongResponse<dynamic>> deleteEnvironments(dynamic ids) async {
    deleteEnvironmentCalls.add(List<int>.from(ids as List));
    return QingLongResponse<dynamic>(data: true);
  }
}

Widget _testApp(Widget child) {
  return MaterialApp(theme: ThemeData.light(), home: child);
}

List<CronTask> _sampleTasks() {
  return [
    CronTask(
      id: '1',
      intId: 1,
      name: 'Nightly backup',
      command: 'bash backup.sh',
      schedule: '0 0 * * *',
      status: 1,
    ),
    CronTask(
      id: '2',
      intId: 2,
      name: 'Cleanup',
      command: 'cleanup.sh',
      schedule: '0 3 * * *',
      status: 1,
      isDisabled: 1,
    ),
  ];
}

Future<void> _pumpTasks(WidgetTester tester, FakeQingLongApi api) async {
  await tester.pumpWidget(_testApp(TasksScreen(api: api)));
  await tester.pumpAndSettle();
}

List<Environment> _sampleEnvironments({bool disabled = false}) {
  return [
    Environment(
      id: '1',
      intId: 1,
      name: 'JD_COOKIE',
      value: 'cookie-value',
      remarks: '主账号',
      isDisabled: disabled ? 1 : 0,
    ),
  ];
}

Future<void> _pumpEnvironments(WidgetTester tester, FakeQingLongApi api) async {
  await tester.pumpWidget(_testApp(EnvScreen(api: api)));
  await tester.pumpAndSettle();
}

List<ConfigFileInfo> _sampleConfigFiles() {
  return [ConfigFileInfo(title: 'config.sh', value: 'config.sh')];
}

List<dynamic> _sampleDependencies() {
  return [
    {'id': 1, 'name': 'axios', 'type': 0, 'status': 1, 'remark': 'HTTP client'},
  ];
}

Future<void> _pumpConfig(WidgetTester tester, FakeQingLongApi api) async {
  await tester.pumpWidget(_testApp(ConfigScreen(api: api)));
  await tester.pumpAndSettle();
}

Future<void> _pumpDependencies(WidgetTester tester, FakeQingLongApi api) async {
  await tester.pumpWidget(_testApp(Scaffold(body: DependencyScreen(api: api))));
  await tester.pumpAndSettle();
}

Future<void> _openSampleConfig(
  WidgetTester tester,
  FakeQingLongApi api, {
  String content = 'export API_URL="http://example"',
}) async {
  await _pumpConfig(tester, api);
  await tester.tap(find.text('config.sh'));
  await tester.pumpAndSettle();
  expect(find.text(content), findsOneWidget);
}

Future<LocalStorage> _pumpSettings(
  WidgetTester tester,
  FakeQingLongApi api,
) async {
  SharedPreferences.setMockInitialValues({
    'server_url': 'http://127.0.0.1:5700',
    'username': 'admin',
  });
  FlutterSecureStorage.setMockInitialValues({});
  final storage = LocalStorage();
  await tester.pumpWidget(
    _testApp(
      SettingsScreen(
        themeController: ThemeController(storage),
        api: api,
        storage: storage,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return storage;
}

Future<void> _scrollSettingsTo(WidgetTester tester, String label) async {
  final target = find.text(label);
  for (var i = 0; i < 8 && target.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _pumpLogin(
  WidgetTester tester,
  FakeQingLongApi api, {
  required VoidCallback onLoginSuccess,
}) async {
  await tester.pumpWidget(
    _testApp(LoginScreen(api: api, onLoginSuccess: onLoginSuccess)),
  );
  await tester.pumpAndSettle();
}

Future<LocalStorage> _pumpQingLongApp(
  WidgetTester tester,
  FakeQingLongApi api, {
  String? token,
}) async {
  SharedPreferences.setMockInitialValues({
    'server_url': 'http://127.0.0.1:5700',
    'username': 'admin',
  });
  FlutterSecureStorage.setMockInitialValues(
    token == null ? {} : {'auth_token': token},
  );
  final storage = LocalStorage();
  await tester.pumpWidget(QingLongApp(storage: storage, api: api));
  await tester.pumpAndSettle();
  return storage;
}

void main() {
  group('key page states', () {
    testWidgets('environment page shows loading and then its empty state', (
      tester,
    ) async {
      final pending = Completer<QingLongResponse<List<Environment>>>();
      final api = FakeQingLongApi(environmentPending: pending.future);

      await tester.pumpWidget(_testApp(EnvScreen(api: api)));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(QingLongResponse<List<Environment>>(data: const []));
      await tester.pumpAndSettle();
      expect(find.text('暂无环境变量'), findsOneWidget);
    });

    testWidgets('environment page shows a retryable error state', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        environmentResponse: QingLongResponse<List<Environment>>(
          code: 500,
          message: '环境变量加载失败',
        ),
      );

      await tester.pumpWidget(_testApp(EnvScreen(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('环境变量加载失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('tasks page shows loading and then its empty state', (
      tester,
    ) async {
      final pending = Completer<QingLongResponse<CronListData>>();
      final api = FakeQingLongApi(taskPending: pending.future);

      await tester.pumpWidget(_testApp(TasksScreen(api: api)));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(QingLongResponse<CronListData>(data: CronListData()));
      await tester.pumpAndSettle();
      expect(find.text('暂无定时任务'), findsOneWidget);
    });

    testWidgets('tasks page shows a retryable error state', (tester) async {
      final api = FakeQingLongApi(
        taskResponse: QingLongResponse<CronListData>(
          code: 503,
          message: '定时任务加载失败',
        ),
      );

      await tester.pumpWidget(_testApp(TasksScreen(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('定时任务加载失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('config page shows loading and then its empty state', (
      tester,
    ) async {
      final pending = Completer<QingLongResponse<List<ConfigFileInfo>>>();
      final api = FakeQingLongApi(configPending: pending.future);

      await tester.pumpWidget(_testApp(ConfigScreen(api: api)));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(QingLongResponse<List<ConfigFileInfo>>(data: const []));
      await tester.pumpAndSettle();
      expect(find.text('暂无配置文件'), findsOneWidget);
    });

    testWidgets('config page shows a retryable error state', (tester) async {
      final api = FakeQingLongApi(
        configResponse: QingLongResponse<List<ConfigFileInfo>>(
          code: 404,
          message: '配置文件不存在',
        ),
      );

      await tester.pumpWidget(_testApp(ConfigScreen(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('配置文件加载失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('config list rejects a failed response even when data exists', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        configResponse: QingLongResponse<List<ConfigFileInfo>>(
          code: 500,
          data: _sampleConfigFiles(),
          message: '配置文件接口失败',
        ),
      );

      await _pumpConfig(tester, api);

      expect(find.text('配置文件加载失败'), findsOneWidget);
      expect(find.text('config.sh'), findsNothing);
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('dashboard page shows a retryable error state', (tester) async {
      final api = FakeQingLongApi(dashboardError: StateError('服务器连接失败'));

      await tester.pumpWidget(_testApp(DashboardScreen(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('仪表盘数据加载失败'), findsOneWidget);
      expect(find.text('请检查服务器连接后重试'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
    });
  });

  group('app session interactions', () {
    testWidgets('shows the login page when no token is stored', (tester) async {
      await _pumpQingLongApp(tester, FakeQingLongApi());

      expect(find.text('QL-Next'), findsOneWidget);
      expect(find.text('青龙面板管理工具'), findsOneWidget);
      expect(find.text('服务器地址'), findsOneWidget);
      expect(find.byType(FloatingNavBar), findsNothing);
    });

    testWidgets('restores the main page when a token is stored', (
      tester,
    ) async {
      await _pumpQingLongApp(tester, FakeQingLongApi(), token: 'stored-token');

      expect(find.text('仪表盘'), findsOneWidget);
      expect(find.text('仪表'), findsOneWidget);
      expect(find.byType(FloatingNavBar), findsOneWidget);
      expect(find.text('QL-Next'), findsNothing);
    });

    testWidgets('logout clears the session and returns to the login page', (
      tester,
    ) async {
      final api = FakeQingLongApi();
      final storage = await _pumpQingLongApp(
        tester,
        api,
        token: 'stored-token',
      );
      api.logoutStorage = storage;

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.text('设置'), findsNWidgets(2));

      final logoutAction = find.byKey(const ValueKey('settings-action-退出登录'));
      final settingsLists = find.byType(ListView);
      for (var i = 0; i < 8 && logoutAction.evaluate().isEmpty; i++) {
        await tester.drag(settingsLists.last, const Offset(0, -180));
        await tester.pumpAndSettle();
      }
      expect(logoutAction, findsOneWidget);
      final logoutScrollable = find
          .ancestor(of: logoutAction, matching: find.byType(Scrollable))
          .first;
      for (var i = 0; i < 6; i++) {
        final rect = tester.getRect(logoutAction);
        if (rect.top >= 0 && rect.bottom <= 520) break;
        await tester.drag(logoutScrollable, const Offset(0, -120));
        await tester.pumpAndSettle();
      }
      await tester.tap(logoutAction);
      await tester.pumpAndSettle();

      expect(find.text('确定要退出账号“admin”吗？'), findsOneWidget);
      await tester.tap(find.text('退出登录').last);
      await tester.pumpAndSettle();

      expect(api.logoutCalls, 1);
      expect(await storage.getToken(), isNull);
      expect(await storage.getServerUrl(), isNull);
      expect(await storage.getUsername(), isNull);
      expect(find.text('服务器地址'), findsOneWidget);
      expect(find.byType(FloatingNavBar), findsNothing);
    });
  });

  group('settings interactions', () {
    testWidgets('settings page shows key sections and opens account manager', (
      tester,
    ) async {
      final api = FakeQingLongApi();

      await _pumpSettings(tester, api);

      expect(find.text('设置'), findsOneWidget);
      expect(find.text('账号管理'), findsOneWidget);
      await _scrollSettingsTo(tester, '账号管理');
      await tester.tap(find.text('账号管理'));
      await tester.pumpAndSettle();

      final sheet = find.byType(FractionallySizedBox);
      expect(sheet, findsOneWidget);
      expect(tester.widget<FractionallySizedBox>(sheet).heightFactor, 0.75);
      expect(find.text('暂无其他已保存账号'), findsOneWidget);
      expect(find.byTooltip('关闭'), findsOneWidget);
    });

    testWidgets('settings opens two-factor sheet with its initial state', (
      tester,
    ) async {
      await _pumpSettings(tester, FakeQingLongApi());

      await _scrollSettingsTo(tester, '两步验证');
      await tester.tap(find.text('两步验证'));
      await tester.pumpAndSettle();

      expect(find.text('两步验证未开启'), findsOneWidget);
      expect(find.text('生成两步验证密钥'), findsOneWidget);
      final sheet = find.byType(FractionallySizedBox);
      expect(sheet, findsOneWidget);
      expect(tester.widget<FractionallySizedBox>(sheet).heightFactor, 0.75);
    });

    testWidgets('settings opens QingLong app settings and handles empty data', (
      tester,
    ) async {
      await _pumpSettings(tester, FakeQingLongApi());

      await _scrollSettingsTo(tester, '青龙应用设置');
      await tester.tap(find.text('青龙应用设置'));
      await tester.pumpAndSettle();

      expect(find.text('还没有应用'), findsOneWidget);
      expect(find.text('创建一个应用来获取 Client ID 和 Client Secret'), findsOneWidget);
      final sheet = find.byType(FractionallySizedBox);
      expect(sheet, findsOneWidget);
      expect(tester.widget<FractionallySizedBox>(sheet).heightFactor, 0.75);
    });

    testWidgets('credential settings saves the updated username and password', (
      tester,
    ) async {
      final api = FakeQingLongApi();
      await _pumpSettings(tester, api);

      await _scrollSettingsTo(tester, '修改用户名和密码');
      await tester.tap(find.text('修改用户名和密码'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'new-admin');
      await tester.enterText(fields.at(1), 'new-password');
      await tester.enterText(fields.at(2), 'new-password');
      await tester.tap(find.text('保存账号凭据'));
      await tester.pumpAndSettle();

      expect(api.updateUsernameCalls, [
        (username: 'new-admin', password: 'new-password'),
      ]);
      expect(find.text('保存账号凭据'), findsNothing);
    });

    testWidgets('credential settings keeps the form open on save failure', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        updateUsernameResponse: QingLongResponse<dynamic>(
          code: 400,
          message: '凭据保存失败',
        ),
      );
      await _pumpSettings(tester, api);

      await _scrollSettingsTo(tester, '修改用户名和密码');
      await tester.tap(find.text('修改用户名和密码'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'new-admin');
      await tester.enterText(fields.at(1), 'new-password');
      await tester.enterText(fields.at(2), 'new-password');
      await tester.tap(find.text('保存账号凭据'));
      await tester.pumpAndSettle();

      expect(find.textContaining('凭据保存失败'), findsOneWidget);
      expect(find.text('保存账号凭据'), findsOneWidget);
    });

    testWidgets('QingLong app settings shows an API error state', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        openAppsResponse: QingLongResponse<List<OpenApp>>(
          code: 500,
          message: '应用列表读取失败',
        ),
      );
      await _pumpSettings(tester, api);

      await _scrollSettingsTo(tester, '青龙应用设置');
      await tester.tap(find.text('青龙应用设置'));
      await tester.pumpAndSettle();

      expect(find.text('应用列表读取失败'), findsOneWidget);
      expect(find.text('重新加载'), findsOneWidget);
    });
  });

  group('dependency interactions', () {
    testWidgets('dependency list rejects a failed response with data', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        dependencyResponse: QingLongResponse<List<dynamic>>(
          code: 500,
          data: _sampleDependencies(),
          message: '依赖列表读取失败',
        ),
      );

      await _pumpDependencies(tester, api);

      expect(find.text('依赖列表读取失败'), findsOneWidget);
      expect(find.text('axios'), findsNothing);
      expect(find.text('重新加载'), findsOneWidget);
    });

    testWidgets('dependency type changes reload with the latest filter', (
      tester,
    ) async {
      final pending = Completer<QingLongResponse<List<dynamic>>>();
      final api = FakeQingLongApi(dependencyPending: pending.future);

      await tester.pumpWidget(
        _testApp(Scaffold(body: DependencyScreen(api: api))),
      );
      await tester.pump();
      await tester.tap(find.text('Python 3'));
      await tester.pump();

      pending.complete(
        QingLongResponse<List<dynamic>>(code: 200, data: const []),
      );
      await tester.pumpAndSettle();

      expect(api.dependencyCalls, [
        (searchValue: '', type: 'nodejs'),
        (searchValue: '', type: 'python3'),
      ]);
    });

    testWidgets('dependency form stays open when create fails', (tester) async {
      final api = FakeQingLongApi(
        dependencyResponse: QingLongResponse<List<dynamic>>(
          code: 200,
          data: const [],
        ),
        createDependencyResponse: QingLongResponse<dynamic>(
          code: 400,
          message: '创建依赖失败',
        ),
      );

      await _pumpDependencies(tester, api);
      await tester.tap(find.byTooltip('创建依赖'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'axios');
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(api.createDependencyCalls, hasLength(1));
      expect(find.text('创建依赖失败'), findsOneWidget);
      expect(find.text('创建依赖'), findsOneWidget);
    });

    testWidgets('dependency operation failure releases the item lock', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        dependencyResponse: QingLongResponse<List<dynamic>>(
          code: 200,
          data: _sampleDependencies(),
        ),
        dependencyOperationResponse: QingLongResponse<dynamic>(
          code: 500,
          message: '重新安装失败',
        ),
      );

      await _pumpDependencies(tester, api);
      await tester.tap(find.text('axios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重新安装'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(api.dependencyOperationCalls, ['reinstall']);
      expect(find.text('重新安装失败'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });

  group('login interactions', () {
    testWidgets('requires all login fields', (tester) async {
      await _pumpLogin(tester, FakeQingLongApi(), onLoginSuccess: () {});

      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      expect(find.text('请填写服务器地址、用户名和密码'), findsOneWidget);
    });

    testWidgets('rejects an invalid server address before requesting login', (
      tester,
    ) async {
      final api = FakeQingLongApi();
      await _pumpLogin(tester, api, onLoginSuccess: () {});

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '://bad');
      await tester.enterText(fields.at(1), 'admin');
      await tester.enterText(fields.at(2), 'password');
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      expect(find.text('服务器地址格式不正确'), findsOneWidget);
      expect(api.loginCalls, isEmpty);
    });

    testWidgets('successful login calls the API and invokes the callback', (
      tester,
    ) async {
      var loggedIn = false;
      final api = FakeQingLongApi(
        loginResponse: QingLongResponse<LoginData>(
          code: 200,
          data: LoginData(token: 'token-123'),
        ),
      );
      await _pumpLogin(tester, api, onLoginSuccess: () => loggedIn = true);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '192.168.1.10:5700');
      await tester.enterText(fields.at(1), 'admin');
      await tester.enterText(fields.at(2), 'password');
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      expect(loggedIn, isTrue);
      expect(api.loginCalls, [
        (server: '192.168.1.10:5700', username: 'admin', password: 'password'),
      ]);
      expect(find.text('登录失败'), findsNothing);
    });

    testWidgets('shows the server error returned by a failed login', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        loginResponse: QingLongResponse<LoginData>(
          code: 401,
          message: '账号或密码错误',
        ),
      );
      await _pumpLogin(tester, api, onLoginSuccess: () {});

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'http://127.0.0.1:5700');
      await tester.enterText(fields.at(1), 'admin');
      await tester.enterText(fields.at(2), 'password');
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      expect(find.text('账号或密码错误'), findsOneWidget);
    });

    testWidgets('explains the Android loopback address connection failure', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        loginError: const SocketException('Connection refused'),
      );
      await _pumpLogin(tester, api, onLoginSuccess: () {});

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '127.0.0.1:5700');
      await tester.enterText(fields.at(1), 'admin');
      await tester.enterText(fields.at(2), 'password');
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Android 中 127.0.0.1 指向设备自身'), findsOneWidget);
      expect(find.textContaining('10.0.2.2:5700'), findsOneWidget);
    });

    testWidgets('handles two-factor login and submits the verification code', (
      tester,
    ) async {
      var loggedIn = false;
      final api = FakeQingLongApi(
        loginResponse: QingLongResponse<LoginData>(
          code: 420,
          message: '需要二因素验证',
        ),
      );
      await _pumpLogin(tester, api, onLoginSuccess: () => loggedIn = true);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '10.0.2.2:5700');
      await tester.enterText(fields.at(1), 'admin');
      await tester.enterText(fields.at(2), 'password');
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      expect(find.text('二因素验证码'), findsOneWidget);
      expect(find.text('验证并登录'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4));

      await tester.ensureVisible(find.byType(TextField).at(3));
      await tester.enterText(find.byType(TextField).at(3), '123456');
      await tester.ensureVisible(find.text('验证并登录'));
      await tester.tap(find.text('验证并登录'));
      await tester.pumpAndSettle();

      expect(loggedIn, isTrue);
      expect(api.twoFactorCalls, [
        (
          server: '10.0.2.2:5700',
          username: 'admin',
          password: 'password',
          code: '123456',
        ),
      ]);
    });

    testWidgets('disables duplicate login requests while loading', (
      tester,
    ) async {
      final pending = Completer<QingLongResponse<LoginData>>();
      final api = FakeQingLongApi(loginPending: pending.future);
      await _pumpLogin(tester, api, onLoginSuccess: () {});

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '10.0.2.2:5700');
      await tester.enterText(fields.at(1), 'admin');
      await tester.enterText(fields.at(2), 'password');
      await tester.tap(find.text('登录'));
      await tester.pump();
      expect(find.text('正在登录'), findsOneWidget);

      await tester.tap(find.text('正在登录'));
      await tester.pump();
      expect(api.loginCalls, hasLength(1));

      pending.complete(
        QingLongResponse<LoginData>(
          code: 200,
          data: LoginData(token: 'token-123'),
        ),
      );
      await tester.pumpAndSettle();
    });
  });

  group('dashboard interactions', () {
    testWidgets('renders overview, trend and system data', (tester) async {
      final api = FakeQingLongApi(
        dashboardOverviewResponse: QingLongResponse<DashboardOverview>(
          code: 200,
          data: DashboardOverview(
            total: 12,
            enabled: 10,
            disabled: 2,
            todayRuns: 4,
            todaySuccess: 3,
            todayFail: 1,
            successRate: '75',
            avgTime: 1250,
          ),
        ),
        dashboardTrendResponse: QingLongResponse<List<dynamic>>(
          code: 200,
          data: [
            {'date': '2026-07-28', 'total': 4, 'success': 3, 'fail': 1},
          ],
        ),
        dashboardSystemResponse: QingLongResponse<Map<String, dynamic>>(
          code: 200,
          data: {
            'platform': 'linux',
            'memUsagePercent': 42,
            'cpus': 8,
            'uptime': 3600,
          },
        ),
      );

      await tester.pumpWidget(_testApp(DashboardScreen(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('任务概览'), findsOneWidget);
      expect(find.text('全局概览'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('1.3s'), findsOneWidget);

      final dashboardScrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('运行趋势'),
        500,
        scrollable: dashboardScrollable,
      );
      expect(find.text('运行趋势'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('系统信息'),
        500,
        scrollable: dashboardScrollable,
      );
      expect(find.text('系统信息'), findsOneWidget);
      expect(find.text('linux'), findsOneWidget);
      expect(find.text('暂无趋势数据'), findsNothing);
    });

    testWidgets('refresh button reloads dashboard data', (tester) async {
      final api = FakeQingLongApi();

      await tester.pumpWidget(_testApp(DashboardScreen(api: api)));
      await tester.pumpAndSettle();
      expect(api.dashboardOverviewCalls, 1);

      await tester.tap(find.byTooltip('刷新仪表盘'));
      await tester.pumpAndSettle();

      expect(api.dashboardOverviewCalls, 2);
    });

    testWidgets('shows empty states when trend and top data are empty', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        dashboardTrendResponse: QingLongResponse<List<dynamic>>(
          code: 200,
          data: const [],
        ),
        dashboardTopTimeResponse: QingLongResponse<List<dynamic>>(
          code: 200,
          data: const [],
        ),
        dashboardTopCountResponse: QingLongResponse<List<dynamic>>(
          code: 200,
          data: const [],
        ),
      );

      await tester.pumpWidget(_testApp(DashboardScreen(api: api)));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('运行趋势'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('暂无趋势数据'), findsOneWidget);
      expect(find.text('暂无数据'), findsOneWidget);
    });

    testWidgets('shows a retryable error for a failed dashboard response', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        dashboardOverviewResponse: QingLongResponse<DashboardOverview>(
          code: 500,
          message: '仪表盘接口失败',
        ),
      );

      await tester.pumpWidget(_testApp(DashboardScreen(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('仪表盘数据加载失败'), findsOneWidget);
      expect(find.text('请检查服务器连接后重试'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('任务总数'), findsNothing);

      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(api.dashboardOverviewCalls, 2);
    });
  });

  group('task interactions', () {
    test('task operation ignores duplicate requests while busy', () async {
      final pending = Completer<QingLongResponse<dynamic>>();
      final api = FakeQingLongApi(
        taskResponse: QingLongResponse<CronListData>(
          data: CronListData(data: _sampleTasks(), total: 2),
        ),
        runTaskPending: pending.future,
      );
      final vm = TasksViewModel(api);

      await vm.loadTasks();
      final first = vm.runTask('1');
      await Future<void>.delayed(Duration.zero);

      expect(await vm.runTask('1'), '任务正在处理中');
      expect(api.runTaskCalls, [
        [1],
      ]);
      expect(vm.state.busyTaskIds, contains('1'));

      pending.complete(QingLongResponse<dynamic>(data: true));
      expect(await first, isNull);
      expect(vm.state.busyTaskIds, isEmpty);
    });

    testWidgets('search filters tasks and can be cleared', (tester) async {
      final api = FakeQingLongApi(
        taskResponse: QingLongResponse<CronListData>(
          data: CronListData(data: _sampleTasks(), total: 2),
        ),
      );

      await _pumpTasks(tester, api);
      expect(find.text('Nightly backup'), findsOneWidget);
      expect(find.text('Cleanup'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'cleanup');
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pumpAndSettle();
      expect(find.text('Nightly backup'), findsNothing);
      expect(find.text('Cleanup'), findsOneWidget);
      expect(find.byKey(const ValueKey('clear-search')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('clear-search')));
      await tester.pumpAndSettle();
      expect(find.text('Nightly backup'), findsOneWidget);
      expect(find.text('Cleanup'), findsOneWidget);
    });

    testWidgets('new task form remains scrollable for keyboard input', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        taskResponse: QingLongResponse<CronListData>(
          data: CronListData(data: _sampleTasks(), total: 2),
        ),
      );

      await _pumpTasks(tester, api);
      await tester.tap(find.byTooltip('新建'));
      await tester.pumpAndSettle();

      expect(find.text('新建任务'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('status filter shows only disabled tasks', (tester) async {
      final api = FakeQingLongApi(
        taskResponse: QingLongResponse<CronListData>(
          data: CronListData(data: _sampleTasks(), total: 2),
        ),
      );

      await _pumpTasks(tester, api);
      await tester.tap(find.byTooltip('筛选'));
      await tester.pumpAndSettle();
      expect(find.text('已启用'), findsOneWidget);
      expect(find.text('已禁用'), findsAtLeastNWidgets(1));

      await tester.tap(find.text('已禁用').last);
      await tester.pumpAndSettle();
      expect(find.text('Nightly backup'), findsNothing);
      expect(find.text('Cleanup'), findsOneWidget);
    });

    testWidgets('long press selects a task and batch run calls the API', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        taskResponse: QingLongResponse<CronListData>(
          data: CronListData(data: _sampleTasks(), total: 2),
        ),
      );

      await _pumpTasks(tester, api);
      await tester.longPress(find.text('Nightly backup'));
      await tester.pumpAndSettle();
      expect(find.text('已选择 1 项'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('运行'));
      await tester.pumpAndSettle();
      expect(api.runTaskCalls, [
        [1],
      ]);
    });

    testWidgets('task menu enables a disabled task', (tester) async {
      final api = FakeQingLongApi(
        taskResponse: QingLongResponse<CronListData>(
          data: CronListData(data: _sampleTasks(), total: 2),
        ),
      );

      await _pumpTasks(tester, api);
      await tester.tap(find.text('Cleanup'));
      await tester.pumpAndSettle();
      expect(find.text('启用'), findsOneWidget);

      await tester.tap(find.text('启用'));
      await tester.pumpAndSettle();
      expect(api.enableTaskCalls, [
        [2],
      ]);
    });

    testWidgets('task menu confirms deletion and calls the API', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        taskResponse: QingLongResponse<CronListData>(
          data: CronListData(data: _sampleTasks(), total: 2),
        ),
      );

      await _pumpTasks(tester, api);
      await tester.tap(find.text('Nightly backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.text('删除定时任务'), findsOneWidget);

      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      expect(api.deleteTaskCalls, [
        [1],
      ]);
    });
  });

  group('environment interactions', () {
    testWidgets('editing an environment submits the updated request', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        environmentResponse: QingLongResponse<List<Environment>>(
          data: _sampleEnvironments(),
        ),
      );

      await _pumpEnvironments(tester, api);
      await tester.tap(find.text('JD_COOKIE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      expect(find.text('编辑环境变量'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'UPDATED_COOKIE');
      await tester.enterText(fields.at(1), 'updated-value');
      await tester.enterText(fields.at(2), '更新后的备注');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(api.updateEnvironmentCalls, hasLength(1));
      final request = api.updateEnvironmentCalls.single;
      expect(request.id, 1);
      expect(request.name, 'UPDATED_COOKIE');
      expect(request.value, 'updated-value');
      expect(request.remarks, '更新后的备注');
    });

    testWidgets('disabled environment can be enabled from its menu', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        environmentResponse: QingLongResponse<List<Environment>>(
          data: _sampleEnvironments(disabled: true),
        ),
      );

      await _pumpEnvironments(tester, api);
      await tester.tap(find.text('JD_COOKIE'));
      await tester.pumpAndSettle();
      expect(find.text('启用'), findsOneWidget);

      await tester.tap(find.text('启用'));
      await tester.pumpAndSettle();
      expect(api.enableEnvironmentCalls, [
        [1],
      ]);
    });

    testWidgets('enabled environment can be disabled from its menu', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        environmentResponse: QingLongResponse<List<Environment>>(
          data: _sampleEnvironments(),
        ),
      );

      await _pumpEnvironments(tester, api);
      await tester.tap(find.text('JD_COOKIE'));
      await tester.pumpAndSettle();
      expect(find.text('禁用'), findsOneWidget);

      await tester.tap(find.text('禁用'));
      await tester.pumpAndSettle();
      expect(api.disableEnvironmentCalls, [
        [1],
      ]);
    });

    testWidgets('environment deletion requires confirmation', (tester) async {
      final api = FakeQingLongApi(
        environmentResponse: QingLongResponse<List<Environment>>(
          data: _sampleEnvironments(),
        ),
      );

      await _pumpEnvironments(tester, api);
      await tester.tap(find.text('JD_COOKIE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.text('删除环境变量'), findsOneWidget);
      expect(api.deleteEnvironmentCalls, isEmpty);

      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      expect(api.deleteEnvironmentCalls, [
        [1],
      ]);
    });

    testWidgets('long press enables batch selection and deletion', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        environmentResponse: QingLongResponse<List<Environment>>(
          data: _sampleEnvironments(),
        ),
      );

      await _pumpEnvironments(tester, api);
      await tester.longPress(find.text('JD_COOKIE'));
      await tester.pumpAndSettle();
      expect(find.text('已选择 1 项'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.text('删除选中变量'), findsOneWidget);

      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      expect(api.deleteEnvironmentCalls, [
        [1],
      ]);
    });
  });

  group('config interactions', () {
    testWidgets('opens a configuration file in a 75 percent bottom sheet', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        configResponse: QingLongResponse<List<ConfigFileInfo>>(
          data: _sampleConfigFiles(),
        ),
        configDetailResponse: QingLongResponse<String>(
          code: 200,
          data: 'export API_URL="http://example"',
        ),
      );

      await _openSampleConfig(tester, api);

      final sheet = find.byType(FractionallySizedBox);
      expect(sheet, findsOneWidget);
      expect(tester.widget<FractionallySizedBox>(sheet).heightFactor, 0.75);
      expect(api.configDetailCalls, ['config.sh']);
    });

    testWidgets('edits and saves configuration content', (tester) async {
      final api = FakeQingLongApi(
        configResponse: QingLongResponse<List<ConfigFileInfo>>(
          data: _sampleConfigFiles(),
        ),
        configDetailResponse: QingLongResponse<String>(
          code: 200,
          data: 'export API_URL="http://example"',
        ),
      );

      await _openSampleConfig(tester, api);
      await tester.tap(find.byTooltip('编辑配置'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('保存配置'), findsOneWidget);

      final updatedContent = 'export API_URL="http://updated"';
      await tester.enterText(find.byType(TextField), updatedContent);
      await tester.tap(find.byTooltip('保存配置'));
      await tester.pumpAndSettle();

      expect(api.saveConfigCalls, [
        (filename: 'config.sh', content: updatedContent),
      ]);
      expect(find.text('配置保存成功'), findsOneWidget);
      expect(find.byTooltip('编辑配置'), findsOneWidget);
      expect(find.byTooltip('保存配置'), findsNothing);
    });

    testWidgets('cancels editing without saving changes', (tester) async {
      const initialContent = 'export API_URL="http://example"';
      final api = FakeQingLongApi(
        configResponse: QingLongResponse<List<ConfigFileInfo>>(
          data: _sampleConfigFiles(),
        ),
        configDetailResponse: QingLongResponse<String>(
          code: 200,
          data: initialContent,
        ),
      );

      await _openSampleConfig(tester, api, content: initialContent);
      await tester.tap(find.byTooltip('编辑配置'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'changed but cancelled');
      await tester.tap(find.byTooltip('取消编辑'));
      await tester.pumpAndSettle();
      expect(find.text('放弃未保存的修改？'), findsOneWidget);

      await tester.tap(find.text('放弃修改'));
      await tester.pumpAndSettle();

      expect(find.text(initialContent), findsOneWidget);
      expect(find.text('changed but cancelled'), findsNothing);
      expect(api.saveConfigCalls, isEmpty);
      expect(find.byTooltip('编辑配置'), findsOneWidget);
    });

    testWidgets('keeps editing when discard confirmation is cancelled', (
      tester,
    ) async {
      const initialContent = 'export API_URL="http://example"';
      final api = FakeQingLongApi(
        configResponse: QingLongResponse<List<ConfigFileInfo>>(
          data: _sampleConfigFiles(),
        ),
        configDetailResponse: QingLongResponse<String>(
          code: 200,
          data: initialContent,
        ),
      );

      await _openSampleConfig(tester, api, content: initialContent);
      await tester.tap(find.byTooltip('编辑配置'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'changed but retained');
      await tester.tap(find.byTooltip('取消编辑'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('保存配置'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('放弃未保存的修改？'), findsNothing);
    });

    testWidgets(
      'config detail rejects a failed response even when content exists',
      (tester) async {
        final api = FakeQingLongApi(
          configResponse: QingLongResponse<List<ConfigFileInfo>>(
            data: _sampleConfigFiles(),
          ),
          configDetailResponse: QingLongResponse<String>(
            code: 500,
            data: 'content from failed response',
            message: '读取配置失败',
          ),
        );

        await _pumpConfig(tester, api);
        await tester.tap(find.text('config.sh'));
        await tester.pumpAndSettle();

        expect(find.text('配置文件加载失败'), findsOneWidget);
        expect(find.text('content from failed response'), findsNothing);
        expect(api.configDetailCalls, ['config.sh']);
      },
    );

    testWidgets('shows an error when configuration detail cannot be read', (
      tester,
    ) async {
      final api = FakeQingLongApi(
        configResponse: QingLongResponse<List<ConfigFileInfo>>(
          data: _sampleConfigFiles(),
        ),
        configDetailResponse: QingLongResponse<String>(
          code: 404,
          message: '配置文件不存在',
        ),
      );

      await _pumpConfig(tester, api);
      await tester.tap(find.text('config.sh'));
      await tester.pumpAndSettle();

      expect(find.text('配置文件加载失败'), findsOneWidget);
      expect(find.text('请检查服务器连接后重试'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(api.configDetailCalls, ['config.sh']);
    });

    testWidgets('shows save error and keeps the editor open', (tester) async {
      final api = FakeQingLongApi(
        configResponse: QingLongResponse<List<ConfigFileInfo>>(
          data: _sampleConfigFiles(),
        ),
        configDetailResponse: QingLongResponse<String>(
          code: 200,
          data: 'export API_URL="http://example"',
        ),
        saveConfigResponse: QingLongResponse<dynamic>(
          code: 400,
          message: '保存失败',
        ),
      );

      await _openSampleConfig(tester, api);
      await tester.tap(find.byTooltip('编辑配置'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'invalid content');
      await tester.tap(find.byTooltip('保存配置'));
      await tester.pumpAndSettle();

      expect(api.saveConfigCalls, hasLength(1));
      expect(find.text('保存失败'), findsOneWidget);
      expect(find.byTooltip('取消编辑'), findsOneWidget);
      expect(find.byTooltip('保存配置'), findsOneWidget);
    });
  });
}

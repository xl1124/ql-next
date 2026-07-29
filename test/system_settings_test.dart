import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/models/models.dart';
import 'package:qinglong_flutter/ui/screens/settings/system_settings_screen.dart';

class _SystemSettingsApi extends QingLongApi {
  _SystemSettingsApi({this.failConfigOnce = false}) : super();

  bool failConfigOnce;
  var configCalls = 0;
  var healthCalls = 0;
  var updateCheckCalls = 0;
  var systemUpdateCalls = 0;
  var reloadCalls = 0;
  final updateCalls = <String>[];

  @override
  Future<QingLongResponse<SystemConfig>> getSystemConfig() async {
    configCalls++;
    if (failConfigOnce) {
      failConfigOnce = false;
      throw StateError('配置读取失败');
    }
    return QingLongResponse<SystemConfig>(
      code: 200,
      data: SystemConfig(
        panelTitle: '青龙面板',
        logRemoveFrequency: 7,
        cronConcurrency: 2,
        timezone: 'Asia/Shanghai',
      ),
    );
  }

  @override
  Future<QingLongResponse<SystemHealth>> getHealth() async {
    healthCalls++;
    return QingLongResponse<SystemHealth>(
      code: 200,
      data: SystemHealth(
        status: 'ok',
        http: true,
        grpc: true,
        uptime: 123,
        memoryUsed: 100,
        memoryTotal: 200,
      ),
    );
  }

  @override
  Future<QingLongResponse<SystemUpdateInfo>> checkSystemUpdate() async {
    updateCheckCalls++;
    return QingLongResponse<SystemUpdateInfo>(
      code: 200,
      data: SystemUpdateInfo(
        hasNewVersion: true,
        lastVersion: '2.19.0',
        lastLog: '修复问题',
      ),
    );
  }

  @override
  Future<QingLongResponse<dynamic>> updateSystem() async {
    systemUpdateCalls++;
    return QingLongResponse<dynamic>(code: 200);
  }

  @override
  Future<QingLongResponse<dynamic>> reloadSystem({String? type}) async {
    reloadCalls++;
    return QingLongResponse<dynamic>(code: 200);
  }

  QingLongResponse<dynamic> _record(String name) {
    updateCalls.add(name);
    return QingLongResponse<dynamic>(code: 200);
  }

  @override
  Future<QingLongResponse<dynamic>> updateLogRemoveFrequency(
    int? value,
  ) async => _record('log-remove-frequency');

  @override
  Future<QingLongResponse<dynamic>> updateCronConcurrency(int? value) async =>
      _record('cron-concurrency');

  @override
  Future<QingLongResponse<dynamic>> updateDependenceProxy(String value) async =>
      _record('dependence-proxy');

  @override
  Future<QingLongResponse<dynamic>> updatePythonMirror(String value) async =>
      _record('python-mirror');

  @override
  Future<QingLongResponse<dynamic>> updateTimezone(String value) async =>
      _record('timezone');

  @override
  Future<QingLongResponse<dynamic>> updateLanguage(String value) async =>
      _record('lang');

  @override
  Future<QingLongResponse<dynamic>> updatePanelTitle(String value) async =>
      _record('panel-title');

  @override
  Future<QingLongResponse<dynamic>> updateGlobalSshKey(String value) async =>
      _record('global-ssh-key');
}

Widget _testApp(Widget child) {
  return MaterialApp(theme: ThemeData.light(), home: child);
}

void main() {
  testWidgets('loads system config and displays health status', (tester) async {
    final api = _SystemSettingsApi();
    await tester.pumpWidget(_testApp(SystemSettingsScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('服务器设置'), findsOneWidget);
    expect(find.text('青龙面板'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('服务运行正常'), findsOneWidget);
    expect(find.text('HTTP 服务'), findsOneWidget);
    expect(find.text('gRPC 服务'), findsOneWidget);
    expect(api.configCalls, 1);
    expect(api.healthCalls, 1);
  });

  testWidgets('saves each supported system config field', (tester) async {
    final api = _SystemSettingsApi();
    await tester.pumpWidget(_testApp(SystemSettingsScreen(api: api)));
    await tester.pumpAndSettle();

    final saveButton = find.text('保存服务器设置');
    for (var index = 0; index < 20 && saveButton.evaluate().isEmpty; index++) {
      await tester.drag(find.byType(ListView), const Offset(0, -320));
      await tester.pumpAndSettle();
    }
    expect(saveButton, findsOneWidget);
    await tester.tap(find.text('保存服务器设置'));
    await tester.pumpAndSettle();

    expect(api.updateCalls, [
      'log-remove-frequency',
      'cron-concurrency',
      'dependence-proxy',
      'python-mirror',
      'timezone',
      'lang',
      'panel-title',
      'global-ssh-key',
    ]);
    expect(find.text('服务器设置已保存'), findsOneWidget);
  });

  testWidgets('shows a retry action when config loading fails', (tester) async {
    final api = _SystemSettingsApi(failConfigOnce: true);
    await tester.pumpWidget(_testApp(SystemSettingsScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('系统配置加载失败'), findsOneWidget);
    expect(find.text('重新加载'), findsOneWidget);
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('服务运行正常'), findsOneWidget);
    expect(api.configCalls, 2);
  });

  testWidgets('checks updates and requires confirmation before updating', (
    tester,
  ) async {
    final api = _SystemSettingsApi();
    await tester.pumpWidget(_testApp(SystemSettingsScreen(api: api)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.system_update_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('发现新版本 2.19.0'), findsNWidgets(2));
    await tester.ensureVisible(find.text('更新青龙'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('更新青龙'));
    await tester.pumpAndSettle();
    expect(find.text('更新期间后端会暂时中断，正在运行的任务可能受到影响。确定开始更新吗？'), findsOneWidget);
    expect(api.systemUpdateCalls, 0);

    await tester.tap(find.text('开始更新'));
    await tester.pumpAndSettle();
    expect(api.systemUpdateCalls, 1);
  });
}

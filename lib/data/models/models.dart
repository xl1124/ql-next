class QingLongResponse<T> {
  final int code;
  final String? message;
  final T? data;
  QingLongResponse({this.code = 0, this.message, this.data});

  factory QingLongResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? dataParser,
  ) {
    return QingLongResponse(
      code: json['code'] as int? ?? 0,
      message: json['message'] as String?,
      data: json['data'] != null && dataParser != null
          ? dataParser(json['data'])
          : null,
    );
  }
}

class LoginRequest {
  final String username;
  final String password;
  LoginRequest({required this.username, required this.password});
  Map<String, dynamic> toJson() => {'username': username, 'password': password};
}

class TwoFactorRequest {
  final String username;
  final String password;
  final String code;
  TwoFactorRequest({
    required this.username,
    required this.password,
    required this.code,
  });
  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    'code': code,
  };
}

class LoginData {
  final String? token;
  final String? tokenType;
  final String? lastIp;
  final String? lastAddr;
  final int? lastLogon;
  final String? isTwoFactor;
  LoginData({
    this.token,
    this.tokenType,
    this.lastIp,
    this.lastAddr,
    this.lastLogon,
    this.isTwoFactor,
  });
  factory LoginData.fromJson(Map<String, dynamic> j) => LoginData(
    token: j['token'] as String?,
    tokenType: j['token_type'] as String?,
    lastIp: j['lastip'] as String?,
    lastAddr: j['lastaddr'] as String?,
    lastLogon: j['lastlogon'] as int?,
    isTwoFactor: j['is_two_factor'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'token': token,
    'token_type': tokenType,
    'lastip': lastIp,
    'lastaddr': lastAddr,
    'lastlogon': lastLogon,
    'is_two_factor': isTwoFactor,
  };
}

class SystemInfo {
  final String? version;
  final String? versionNew;
  final String? type;
  final String? nodeVersion;
  final bool isInitialized;
  SystemInfo({
    this.version,
    this.versionNew,
    this.type,
    this.nodeVersion,
    this.isInitialized = false,
  });
  factory SystemInfo.fromJson(Map<String, dynamic> j) => SystemInfo(
    version: j['version'] as String?,
    versionNew: j['versionNew'] as String?,
    type: j['type'] as String?,
    nodeVersion: j['nodeVersion'] as String?,
    isInitialized: j['isInitialized'] as bool? ?? false,
  );
}

class SystemUpdateInfo {
  final bool hasNewVersion;
  final String lastVersion;
  final String lastLog;
  final String lastLogLink;

  const SystemUpdateInfo({
    this.hasNewVersion = false,
    this.lastVersion = '',
    this.lastLog = '',
    this.lastLogLink = '',
  });

  factory SystemUpdateInfo.fromJson(Map<String, dynamic> json) {
    return SystemUpdateInfo(
      hasNewVersion: json['hasNewVersion'] == true,
      lastVersion: json['lastVersion']?.toString() ?? '',
      lastLog: json['lastLog']?.toString() ?? '',
      lastLogLink: json['lastLogLink']?.toString() ?? '',
    );
  }
}

class SystemConfig {
  final int? id;
  final String type;
  final String lang;
  final String panelTitle;
  final int? logRemoveFrequency;
  final int? cronConcurrency;
  final String dependenceProxy;
  final String nodeMirror;
  final String pythonMirror;
  final String linuxMirror;
  final String timezone;
  final String globalSshKey;

  const SystemConfig({
    this.id,
    this.type = 'systemConfig',
    this.lang = 'zh',
    this.panelTitle = '',
    this.logRemoveFrequency,
    this.cronConcurrency,
    this.dependenceProxy = '',
    this.nodeMirror = '',
    this.pythonMirror = '',
    this.linuxMirror = '',
    this.timezone = 'Asia/Shanghai',
    this.globalSshKey = '',
  });

  factory SystemConfig.fromJson(Map<String, dynamic> json) {
    final rawInfo = json['info'];
    final info = rawInfo is Map ? Map<String, dynamic>.from(rawInfo) : json;
    return SystemConfig(
      id: (json['id'] as num?)?.toInt(),
      type: json['type']?.toString() ?? 'systemConfig',
      lang: info['lang']?.toString() ?? 'zh',
      panelTitle: info['panelTitle']?.toString() ?? '',
      logRemoveFrequency: (info['logRemoveFrequency'] as num?)?.toInt(),
      cronConcurrency: (info['cronConcurrency'] as num?)?.toInt(),
      dependenceProxy: info['dependenceProxy']?.toString() ?? '',
      nodeMirror: info['nodeMirror']?.toString() ?? '',
      pythonMirror: info['pythonMirror']?.toString() ?? '',
      linuxMirror: info['linuxMirror']?.toString() ?? '',
      timezone: info['timezone']?.toString() ?? 'Asia/Shanghai',
      globalSshKey: info['globalSshKey']?.toString() ?? '',
    );
  }
}

class SystemHealth {
  final String status;
  final bool http;
  final bool grpc;
  final int uptime;
  final int memoryUsed;
  final int memoryTotal;

  const SystemHealth({
    this.status = 'error',
    this.http = false,
    this.grpc = false,
    this.uptime = 0,
    this.memoryUsed = 0,
    this.memoryTotal = 0,
  });

  factory SystemHealth.fromJson(Map<String, dynamic> json) {
    final services = json['services'] is Map
        ? Map<String, dynamic>.from(json['services'] as Map)
        : const <String, dynamic>{};
    final metrics = json['metrics'] is Map
        ? Map<String, dynamic>.from(json['metrics'] as Map)
        : const <String, dynamic>{};
    final memory = metrics['memory'] is Map
        ? Map<String, dynamic>.from(metrics['memory'] as Map)
        : const <String, dynamic>{};
    return SystemHealth(
      status: json['status']?.toString() ?? 'error',
      http: services['http'] == true,
      grpc: services['grpc'] == true,
      uptime: (metrics['uptime'] as num?)?.toInt() ?? 0,
      memoryUsed: (memory['used'] as num?)?.toInt() ?? 0,
      memoryTotal: (memory['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class OpenApp {
  final int? id;
  final String name;
  final List<String> scopes;
  final String clientId;
  final String clientSecret;

  const OpenApp({
    this.id,
    this.name = '',
    this.scopes = const [],
    this.clientId = '',
    this.clientSecret = '',
  });

  factory OpenApp.fromJson(Map<String, dynamic> json) {
    return OpenApp(
      id: (json['id'] as num?)?.toInt(),
      name: json['name']?.toString() ?? '',
      scopes:
          (json['scopes'] as List?)?.map((item) => item.toString()).toList() ??
          const [],
      clientId: json['client_id']?.toString() ?? '',
      clientSecret: json['client_secret']?.toString() ?? '',
    );
  }
}

class CronTask {
  final String? id;
  final int? intId;
  final String name;
  final String command;
  final String schedule;
  final int? status;
  final int isDisabled;
  final int isPinned;
  final int isSystem;
  final String? lastExecuteTime;
  final int? lastRunningTime;
  final int? nextRunTime;
  final String? createdAt;
  final String? updatedAt;

  CronTask({
    this.id,
    this.intId,
    this.name = '',
    this.command = '',
    this.schedule = '',
    this.status,
    this.isDisabled = 0,
    this.isPinned = 0,
    this.isSystem = 0,
    this.lastExecuteTime,
    this.lastRunningTime,
    this.nextRunTime,
    this.createdAt,
    this.updatedAt,
  });

  factory CronTask.fromJson(Map<String, dynamic> j) => CronTask(
    id: j['_id']?.toString(),
    intId: j['id'] as int?,
    name: j['name'] as String? ?? '',
    command: j['command'] as String? ?? '',
    schedule: j['schedule'] as String? ?? '',
    status: j['status'] as int?,
    isDisabled: j['isDisabled'] as int? ?? 0,
    isPinned: j['isPinned'] as int? ?? 0,
    isSystem: j['isSystem'] as int? ?? 0,
    lastExecuteTime: j['last_execution_time']?.toString(),
    lastRunningTime: j['lastRunningTime'] as int?,
    nextRunTime: j['nextRunTime'] as int?,
    createdAt: j['createdAt']?.toString(),
    updatedAt: j['updatedAt']?.toString(),
  );

  int get stateCode {
    if (isDisabled == 1) return 2;
    if (status == 0) return 0;
    if (status == 3) return 3;
    return 1;
  }

  String get stateLabel {
    switch (stateCode) {
      case 0:
        return '运行中';
      case 1:
        return '空闲';
      case 2:
        return '已禁用';
      case 3:
        return '队列中';
      default:
        return '未知';
    }
  }
}

class TaskLogFile {
  final String filename;
  final String directory;
  final double? time;

  const TaskLogFile({
    required this.filename,
    required this.directory,
    this.time,
  });

  factory TaskLogFile.fromJson(Map<String, dynamic> j) => TaskLogFile(
    filename: j['filename']?.toString() ?? '',
    directory: j['directory']?.toString() ?? '',
    time: j['time'] is num
        ? (j['time'] as num).toDouble()
        : double.tryParse(j['time']?.toString() ?? ''),
  );

  String get key => '$directory/$filename';
}

class LogFileEntry {
  final String title;
  final String key;
  final String type;
  final String parent;
  final int? size;
  final double? createTime;
  final List<LogFileEntry> children;

  const LogFileEntry({
    required this.title,
    required this.key,
    required this.type,
    required this.parent,
    this.size,
    this.createTime,
    this.children = const [],
  });

  factory LogFileEntry.fromJson(Map<String, dynamic> json) {
    return LogFileEntry(
      title: json['title']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      type: json['type']?.toString() ?? 'file',
      parent: json['parent']?.toString() ?? '',
      size: json['size'] is num
          ? (json['size'] as num).toInt()
          : int.tryParse(json['size']?.toString() ?? ''),
      createTime: json['createTime'] is num
          ? (json['createTime'] as num).toDouble()
          : double.tryParse(json['createTime']?.toString() ?? ''),
      children:
          (json['children'] as List?)
              ?.whereType<Map>()
              .map(
                (item) =>
                    LogFileEntry.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList() ??
          const [],
    );
  }

  bool get isFile => type == 'file';
}

class SubscriptionInfo {
  final int id;
  final String name;
  final String type;
  final String scheduleType;
  final String schedule;
  final Map<String, dynamic> intervalSchedule;
  final String url;
  final String branch;
  final String alias;
  final String whitelist;
  final String blacklist;
  final String dependences;
  final String extensions;
  final String subBefore;
  final String subAfter;
  final String proxy;
  final String pullType;
  final Map<String, dynamic> pullOption;
  final int status;
  final int isDisabled;
  final int autoAddCron;
  final int autoDelCron;
  final int? pid;
  final String? logPath;
  final int? lastExecutionTime;

  const SubscriptionInfo({
    this.id = 0,
    this.name = '',
    this.type = 'public-repo',
    this.scheduleType = 'crontab',
    this.schedule = '',
    this.intervalSchedule = const {},
    this.url = '',
    this.branch = '',
    this.alias = '',
    this.whitelist = '',
    this.blacklist = '',
    this.dependences = '',
    this.extensions = '',
    this.subBefore = '',
    this.subAfter = '',
    this.proxy = '',
    this.pullType = 'ssh-key',
    this.pullOption = const {},
    this.status = 1,
    this.isDisabled = 0,
    this.autoAddCron = 1,
    this.autoDelCron = 1,
    this.pid,
    this.logPath,
    this.lastExecutionTime,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final interval = json['interval_schedule'];
    final pullOption = json['pull_option'];
    return SubscriptionInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? json['alias']?.toString() ?? '',
      type: json['type']?.toString() ?? 'public-repo',
      scheduleType: json['schedule_type']?.toString() ?? 'crontab',
      schedule: json['schedule']?.toString() ?? '',
      intervalSchedule: interval is Map
          ? Map<String, dynamic>.from(interval)
          : const {},
      url: json['url']?.toString() ?? '',
      branch: json['branch']?.toString() ?? '',
      alias: json['alias']?.toString() ?? '',
      whitelist: json['whitelist']?.toString() ?? '',
      blacklist: json['blacklist']?.toString() ?? '',
      dependences: json['dependences']?.toString() ?? '',
      extensions: json['extensions']?.toString() ?? '',
      subBefore: json['sub_before']?.toString() ?? '',
      subAfter: json['sub_after']?.toString() ?? '',
      proxy: json['proxy']?.toString() ?? '',
      pullType: json['pull_type']?.toString() ?? 'ssh-key',
      pullOption: pullOption is Map
          ? Map<String, dynamic>.from(pullOption)
          : const {},
      status: (json['status'] as num?)?.toInt() ?? 1,
      isDisabled: (json['is_disabled'] as num?)?.toInt() ?? 0,
      autoAddCron: (json['autoAddCron'] as num?)?.toInt() ?? 1,
      autoDelCron: (json['autoDelCron'] as num?)?.toInt() ?? 1,
      pid: (json['pid'] as num?)?.toInt(),
      logPath: json['log_path']?.toString(),
      lastExecutionTime: (json['last_execution_time'] as num?)?.toInt(),
    );
  }

  String get typeLabel => switch (type) {
    'private-repo' => '私有仓库',
    'file' => '单文件',
    _ => '公开仓库',
  };

  String get statusLabel {
    if (isDisabled == 1 && status == 1) return '已禁用';
    return switch (status) {
      0 => '运行中',
      1 => '空闲',
      2 => '已禁用',
      3 => '队列中',
      _ => '未知状态',
    };
  }

  bool get isRunning => status == 0 || status == 3;

  String get scheduleLabel {
    if (scheduleType == 'interval' && intervalSchedule.isNotEmpty) {
      final value = intervalSchedule['value']?.toString() ?? '';
      final unit = switch (intervalSchedule['type']?.toString()) {
        'hours' => '时',
        'minutes' => '分',
        'seconds' => '秒',
        _ => '天',
      };
      return '每$value$unit';
    }
    return schedule.isEmpty ? '未设置' : schedule;
  }
}

class CronListData {
  final List<CronTask> data;
  final int total;
  CronListData({this.data = const [], this.total = 0});
  factory CronListData.fromJson(Map<String, dynamic> j) => CronListData(
    data:
        (j['data'] as List<dynamic>?)
            ?.map((e) => CronTask.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    total: j['total'] as int? ?? 0,
  );
}

class Environment {
  final String? id;
  final int? intId;
  final String name;
  final String value;
  final String? remarks;
  final int isDisabled;
  final String? timestamp;
  final String? createdAt;
  final String? updatedAt;
  Environment({
    this.id,
    this.intId,
    this.name = '',
    this.value = '',
    this.remarks,
    this.isDisabled = 0,
    this.timestamp,
    this.createdAt,
    this.updatedAt,
  });

  factory Environment.fromJson(Map<String, dynamic> j) => Environment(
    id: j['_id']?.toString(),
    intId: j['id'] is num
        ? (j['id'] as num).toInt()
        : int.tryParse(j['id']?.toString() ?? ''),
    name: j['name'] as String? ?? '',
    value: j['value'] as String? ?? '',
    remarks: j['remarks']?.toString(),
    isDisabled: j['status'] as int? ?? 0,
    timestamp: j['timestamp']?.toString(),
    createdAt: j['createdAt']?.toString(),
    updatedAt: j['updatedAt']?.toString(),
  );
}

class DashboardOverview {
  final int total;
  final int enabled;
  final int disabled;
  final int todayRuns;
  final int todaySuccess;
  final int todayFail;
  final String successRate;
  final int avgTime;
  DashboardOverview({
    this.total = 0,
    this.enabled = 0,
    this.disabled = 0,
    this.todayRuns = 0,
    this.todaySuccess = 0,
    this.todayFail = 0,
    this.successRate = '0',
    this.avgTime = 0,
  });
  factory DashboardOverview.fromJson(Map<String, dynamic> j) =>
      DashboardOverview(
        total: j['total'] as int? ?? 0,
        enabled: j['enabled'] as int? ?? 0,
        disabled: j['disabled'] as int? ?? 0,
        todayRuns: j['todayRuns'] as int? ?? 0,
        todaySuccess: j['todaySuccess'] as int? ?? 0,
        todayFail: j['todayFail'] as int? ?? 0,
        successRate: j['successRate']?.toString() ?? '0',
        avgTime: j['avgTime'] as int? ?? 0,
      );
}

class DashboardRuntime {
  final int runningCount;
  final int queuedCount;
  final List<DashboardRunningTask> running;
  final List<DashboardIdleTask> idleTasks;

  const DashboardRuntime({
    this.runningCount = 0,
    this.queuedCount = 0,
    this.running = const [],
    this.idleTasks = const [],
  });

  factory DashboardRuntime.fromJson(Map<String, dynamic> json) {
    return DashboardRuntime(
      runningCount: _intValue(json['runningCount']),
      queuedCount: _intValue(json['queuedCount']),
      running:
          (json['running'] as List?)
              ?.whereType<Map>()
              .map(
                (item) => DashboardRunningTask.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList() ??
          const [],
      idleTasks:
          (json['idleTasks'] as List?)
              ?.whereType<Map>()
              .map(
                (item) =>
                    DashboardIdleTask.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList() ??
          const [],
    );
  }
}

class DashboardRunningTask {
  final int? instanceId;
  final int? id;
  final String name;
  final int? pid;
  final int elapsed;
  final String logPath;

  const DashboardRunningTask({
    this.instanceId,
    this.id,
    this.name = '',
    this.pid,
    this.elapsed = 0,
    this.logPath = '',
  });

  factory DashboardRunningTask.fromJson(Map<String, dynamic> json) {
    return DashboardRunningTask(
      instanceId: _intValueOrNull(json['instanceId']),
      id: _intValueOrNull(json['id']),
      name: json['name']?.toString() ?? '',
      pid: _intValueOrNull(json['pid']),
      elapsed: _intValue(json['elapsed']),
      logPath: json['logPath']?.toString() ?? '',
    );
  }
}

class DashboardIdleTask {
  final int? id;
  final String name;
  final String lastRun;

  const DashboardIdleTask({this.id, this.name = '', this.lastRun = '-'});

  factory DashboardIdleTask.fromJson(Map<String, dynamic> json) {
    return DashboardIdleTask(
      id: _intValueOrNull(json['id']),
      name: json['name']?.toString() ?? '',
      lastRun: json['lastRun']?.toString() ?? '-',
    );
  }
}

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _intValueOrNull(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

class EnvRequest {
  final String name;
  final String value;
  final String? remarks;
  final int? id;
  EnvRequest({required this.name, required this.value, this.remarks, this.id});
  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    if (remarks != null) 'remarks': remarks,
    if (id != null) 'id': id,
  };
}

class DependencyInfo {
  final int id;
  final String name;
  final int type;
  final int status;
  final String remark;
  final String? timestamp;
  final String? createdAt;
  final String? updatedAt;
  final List<String> log;

  const DependencyInfo({
    this.id = 0,
    this.name = '',
    this.type = 0,
    this.status = 6,
    this.remark = '',
    this.timestamp,
    this.createdAt,
    this.updatedAt,
    this.log = const [],
  });

  factory DependencyInfo.fromJson(Map<String, dynamic> json) => DependencyInfo(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name']?.toString() ?? '',
    type: (json['type'] as num?)?.toInt() ?? 0,
    status: (json['status'] as num?)?.toInt() ?? 6,
    remark: json['remark']?.toString() ?? '',
    timestamp: json['timestamp']?.toString(),
    createdAt: json['createdAt']?.toString(),
    updatedAt: json['updatedAt']?.toString(),
    log: (json['log'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'status': status,
    'remark': remark,
  };
}

class TaskRequest {
  final String name;
  final String command;
  final String schedule;
  final String? id;
  TaskRequest({
    required this.name,
    required this.command,
    required this.schedule,
    this.id,
  });
  Map<String, dynamic> toJson() => {
    'name': name,
    'command': command,
    'schedule': schedule,
    if (id != null) '_id': id,
  };
}

class UserInfo {
  final String username;
  final String? avatar;
  final bool twoFactorActivated;
  UserInfo({
    required this.username,
    this.avatar,
    this.twoFactorActivated = false,
  });
  factory UserInfo.fromJson(Map<String, dynamic> j) => UserInfo(
    username: j['username'] as String? ?? '',
    avatar: j['avatar'] as String?,
    twoFactorActivated: j['twoFactorActivated'] as bool? ?? false,
  );
}

class TwoFactorInitData {
  final String secret;
  final String url;

  const TwoFactorInitData({this.secret = '', this.url = ''});

  factory TwoFactorInitData.fromJson(Map<String, dynamic> json) {
    return TwoFactorInitData(
      secret: json['secret']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }
}

class LoginLog {
  final int? id;
  final String? ip;
  final String? address;
  final String? platform;
  final int? timestamp;
  final String? status;
  LoginLog({
    this.id,
    this.ip,
    this.address,
    this.platform,
    this.timestamp,
    this.status,
  });
  factory LoginLog.fromJson(Map<String, dynamic> j) {
    final rawStatus = j['status'];
    final status = rawStatus is num
        ? switch (rawStatus.toInt()) {
            0 => 'success',
            1 => 'fail',
            _ => rawStatus.toString(),
          }
        : rawStatus?.toString();
    final rawTimestamp = j['timestamp'];
    final timestamp = rawTimestamp is num
        ? rawTimestamp.toInt()
        : int.tryParse(rawTimestamp?.toString() ?? '');

    return LoginLog(
      id: (j['id'] as num?)?.toInt(),
      ip: j['ip']?.toString(),
      address: j['address']?.toString(),
      platform: j['platform']?.toString(),
      timestamp: timestamp,
      status: status,
    );
  }
}

class NotificationConfig {
  final String type;
  final Map<String, dynamic> values;

  const NotificationConfig({this.type = '', this.values = const {}});

  factory NotificationConfig.fromJson(Map<String, dynamic> json) {
    final values = Map<String, dynamic>.from(json);
    final type = values.remove('type')?.toString() ?? '';
    return NotificationConfig(type: type, values: values);
  }

  String value(String key) => values[key]?.toString() ?? '';

  Map<String, dynamic> toJson() => {'type': type, ...values};
}

class ConfigFileInfo {
  final String title;
  final String value;
  ConfigFileInfo({required this.title, required this.value});
  factory ConfigFileInfo.fromJson(Map<String, dynamic> j) => ConfigFileInfo(
    title: j['title'] as String? ?? '',
    value: j['value'] as String? ?? '',
  );
}

class ScriptFile {
  final String title;
  final String key;
  final String type;
  final String parent;
  final int createTime;
  final int? size;
  final List<ScriptFile> children;

  ScriptFile({
    required this.title,
    required this.key,
    required this.type,
    required this.parent,
    required this.createTime,
    this.size,
    this.children = const [],
  });

  bool get isDirectory => type == 'directory';

  factory ScriptFile.fromJson(Map<String, dynamic> json) {
    return ScriptFile(
      title: json['title'] as String? ?? '',
      key: json['key'] as String? ?? '',
      type: json['type'] as String? ?? 'file',
      parent: json['parent'] as String? ?? '',
      createTime: (json['createTime'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt(),
      children: (json['children'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ScriptFile.fromJson)
          .toList(),
    );
  }
}

class AccountEntry {
  final String server;
  final String token;
  final String username;
  AccountEntry({
    required this.server,
    required this.token,
    required this.username,
  });
  Map<String, dynamic> toJson() => {
    'server': server,
    'token': token,
    'username': username,
  };
  factory AccountEntry.fromJson(Map<String, dynamic> j) => AccountEntry(
    server: j['server'] as String? ?? '',
    token: j['token'] as String? ?? '',
    username: j['username'] as String? ?? '',
  );
}

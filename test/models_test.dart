import 'package:flutter_test/flutter_test.dart';
import 'package:qinglong_flutter/data/models/models.dart';

void main() {
  group('QingLongResponse', () {
    test('preserves the backend code, message, and parsed data', () {
      final response = QingLongResponse<int>.fromJson({
        'code': 400,
        'message': '参数校验失败',
        'data': {'value': 42},
      }, (data) => (data as Map<String, dynamic>)['value'] as int);

      expect(response.code, 400);
      expect(response.message, '参数校验失败');
      expect(response.data, 42);
    });

    test('uses defaults when optional response fields are absent', () {
      final response = QingLongResponse<String>.fromJson(
        const {},
        (data) => data?.toString() ?? '',
      );

      expect(response.code, 0);
      expect(response.message, isNull);
      expect(response.data, isNull);
    });
  });

  test('parses an open app and its scopes', () {
    final app = OpenApp.fromJson({
      'id': 7,
      'name': '移动端',
      'client_id': 'client-123',
      'client_secret': 'secret-456',
      'scopes': ['crons:read', 'envs:write'],
    });

    expect(app.id, 7);
    expect(app.name, '移动端');
    expect(app.clientId, 'client-123');
    expect(app.clientSecret, 'secret-456');
    expect(app.scopes, ['crons:read', 'envs:write']);
  });

  group('LoginLog', () {
    test('converts numeric status and timestamp values', () {
      final log = LoginLog.fromJson({
        'id': 9,
        'ip': '192.168.1.20',
        'address': '局域网',
        'platform': 'Android',
        'timestamp': 1710000000000,
        'status': 0,
      });

      expect(log.id, 9);
      expect(log.ip, '192.168.1.20');
      expect(log.platform, 'Android');
      expect(log.timestamp, 1710000000000);
      expect(log.status, 'success');
    });

    test('accepts string status and timestamp values', () {
      final log = LoginLog.fromJson({
        'timestamp': '1710000000123',
        'status': 'blocked',
      });

      expect(log.timestamp, 1710000000123);
      expect(log.status, 'blocked');
    });
  });

  test('parses multiple task log files and builds unique keys', () {
    final files = [
      TaskLogFile.fromJson({
        'filename': '2026-07-28.log',
        'directory': '/ql/log/repo/1',
        'time': 1710000000,
      }),
      TaskLogFile.fromJson({
        'filename': '2026-07-27.log',
        'directory': '/ql/log/repo/1',
        'time': '1709913600.5',
      }),
    ];

    expect(files, hasLength(2));
    expect(files.first.key, '/ql/log/repo/1/2026-07-28.log');
    expect(files.first.time, 1710000000.0);
    expect(files.last.time, 1709913600.5);
  });

  test('keeps an error status for configuration detail responses', () {
    final response = QingLongResponse<String>.fromJson({
      'code': 404,
      'message': '配置文件不存在',
      'data': '',
    }, (data) => data?.toString() ?? '');

    expect(response.code, 404);
    expect(response.message, '配置文件不存在');
    expect(response.data, isEmpty);
  });
}

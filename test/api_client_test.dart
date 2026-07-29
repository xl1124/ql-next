import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qinglong_flutter/data/api/api_client.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/local/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('normalizes the base URL, query parameters and auth headers', () async {
    SharedPreferences.setMockInitialValues({'server_url': 'example.test///'});
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'token-123'});
    final storage = LocalStorage();
    late http.Request request;
    final client = MockClient((incoming) async {
      request = incoming;
      return http.Response('{}', 200);
    });

    final result = await ApiClient(storage: storage, client: client).get(
      'api/items',
      queryParams: {'searchValue': 'hello world', 'page': '2'},
    );

    expect(result, isEmpty);
    expect(request.url.toString(), contains('http://example.test/api/items'));
    expect(request.url.queryParameters, {
      'searchValue': 'hello world',
      'page': '2',
    });
    expect(request.headers['authorization'], 'Bearer token-123');
    expect(request.headers['content-type'], 'application/json');
    expect(request.headers['accept'], 'application/json');
  });

  test('encodes JSON bodies for post, put and delete requests', () async {
    SharedPreferences.setMockInitialValues({
      'server_url': 'http://example.test',
    });
    final requests = <http.BaseRequest>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('{}', 200);
    });
    final api = ApiClient(storage: LocalStorage(), client: client);

    await api.post('api/post', body: {'name': 'post'});
    await api.put('api/put', body: {'name': 'put'});
    await api.delete('api/delete', body: [1, 2]);

    expect(requests.map((request) => request.method), [
      'POST',
      'PUT',
      'DELETE',
    ]);
    expect((requests[0] as http.Request).body, jsonEncode({'name': 'post'}));
    expect((requests[1] as http.Request).body, jsonEncode({'name': 'put'}));
    expect((requests[2] as http.Request).body, jsonEncode([1, 2]));
  });

  test('supports PUT multipart uploads for data imports', () async {
    SharedPreferences.setMockInitialValues({
      'server_url': 'http://example.test',
    });
    late http.Request request;
    final client = MockClient((incoming) async {
      request = incoming;
      return http.Response(jsonEncode({'code': 200}), 200);
    });

    final result = await ApiClient(storage: LocalStorage(), client: client)
        .uploadMultipart(
          'api/system/data/import',
          method: 'PUT',
          fieldName: 'data',
          filename: 'data.tgz',
          bytes: [1, 2, 3],
        );

    expect(result['code'], 200);
    expect(request.method, 'PUT');
    expect(request.url.path, '/api/system/data/import');
    expect(request.headers['content-type'], startsWith('multipart/form-data'));
    expect(utf8.decode(request.bodyBytes), contains('data.tgz'));
  });

  test('converts HTTP errors into useful exceptions', () async {
    SharedPreferences.setMockInitialValues({'server_url': 'example.test'});
    final client = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(jsonEncode({'message': '参数错误'})),
        400,
        headers: {'content-type': 'application/json; charset=utf-8'},
        reasonPhrase: 'Bad Request',
      ),
    );

    await expectLater(
      ApiClient(storage: LocalStorage(), client: client).post('api/test'),
      throwsA(
        isA<HttpException>().having(
          (error) => error.message,
          'message',
          'HTTP 400: 参数错误',
        ),
      ),
    );
  });

  test('handles empty and malformed JSON responses', () async {
    SharedPreferences.setMockInitialValues({'server_url': 'example.test'});
    final emptyClient = MockClient((_) async => http.Response('', 200));
    expect(
      await ApiClient(
        storage: LocalStorage(),
        client: emptyClient,
      ).get('api/empty'),
      isEmpty,
    );

    final malformedClient = MockClient(
      (_) async => http.Response('not-json', 200),
    );
    await expectLater(
      ApiClient(
        storage: LocalStorage(),
        client: malformedClient,
      ).get('api/malformed'),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'maps common network failures to user-facing network exceptions',
    () async {
      SharedPreferences.setMockInitialValues({'server_url': 'example.test'});
      final failures = <Object, String>{
        const SocketException('connection refused'): '无法连接青龙服务器',
        TimeoutException('timed out'): '连接青龙服务器超时',
        HandshakeException('bad certificate'): 'HTTPS 连接失败',
        http.ClientException('request failed'): '网络请求失败',
      };

      for (final entry in failures.entries) {
        final client = MockClient((_) async => throw entry.key);
        await expectLater(
          ApiClient(storage: LocalStorage(), client: client).get('api/test'),
          throwsA(
            isA<QingLongNetworkException>().having(
              (error) => error.message,
              'message',
              contains(entry.value),
            ),
          ),
        );
      }
    },
  );

  test(
    'QingLongApi.login persists the returned token and account info',
    () async {
      final storage = LocalStorage();
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'http://server.test:5700/api/user/login',
        );
        expect(jsonDecode(request.body), {
          'username': 'admin',
          'password': 'password',
        });
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 200,
              'data': {'token': 'token-123', 'token_type': 'Bearer'},
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = QingLongApi(
        client: ApiClient(storage: storage, client: client),
        storage: storage,
      );

      final response = await api.login(
        'server.test:5700///',
        'admin',
        'password',
      );

      expect(response.code, 200);
      expect(await storage.getToken(), 'token-123');
      expect(await storage.getServerUrl(), 'server.test:5700///');
      expect(await storage.getUsername(), 'admin');
      expect(await storage.getAccounts(), hasLength(1));
    },
  );

  test('reads system config, health and exports system data', () async {
    SharedPreferences.setMockInitialValues({
      'server_url': 'http://server.test:5700',
    });
    final requests = <http.BaseRequest>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/system/config') {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 200,
              'data': {
                'id': 1,
                'type': 'systemConfig',
                'info': {
                  'lang': 'zh',
                  'panelTitle': '青龙',
                  'logRemoveFrequency': 7,
                  'cronConcurrency': 2,
                  'timezone': 'Asia/Shanghai',
                },
              },
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/health') {
        return http.Response(
          jsonEncode({
            'code': 200,
            'data': {
              'status': 'ok',
              'services': {'http': true, 'grpc': true},
              'metrics': {
                'uptime': 123,
                'memory': {'used': 100, 'total': 200},
              },
            },
          }),
          200,
        );
      }
      return http.Response.bytes([4, 5, 6], 200);
    });
    final api = QingLongApi(
      client: ApiClient(storage: LocalStorage(), client: client),
      storage: LocalStorage(),
    );

    final config = await api.getSystemConfig();
    final health = await api.getHealth();
    final export = await api.exportSystemData();

    expect(config.data?.panelTitle, '青龙');
    expect(config.data?.cronConcurrency, 2);
    expect(health.data?.http, isTrue);
    expect(health.data?.memoryTotal, 200);
    expect(export, [4, 5, 6]);
    expect(requests.map((request) => request.method), ['GET', 'GET', 'PUT']);
    expect(
      (requests.last as http.Request).body,
      jsonEncode({'type': const <String>[]}),
    );
  });

  test('checks for updates and starts system maintenance actions', () async {
    SharedPreferences.setMockInitialValues({
      'server_url': 'http://server.test:5700',
    });
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/system/update-check') {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 200,
              'data': {
                'hasNewVersion': true,
                'lastVersion': '2.19.0',
                'lastLog': '修复问题',
                'lastLogLink': 'https://example.test/release',
              },
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{}', 200);
    });
    final api = QingLongApi(
      client: ApiClient(storage: LocalStorage(), client: client),
      storage: LocalStorage(),
    );

    final update = await api.checkSystemUpdate();
    final updateResult = await api.updateSystem();
    final reloadResult = await api.reloadSystem();

    expect(update.data?.hasNewVersion, isTrue);
    expect(update.data?.lastVersion, '2.19.0');
    expect(updateResult.code, 0);
    expect(reloadResult.code, 0);
    expect(requests.map((request) => [request.method, request.url.path]), [
      ['PUT', '/api/system/update-check'],
      ['PUT', '/api/system/update'],
      ['PUT', '/api/system/reload'],
    ]);
  });

  test('requires a configured server URL for authenticated requests', () async {
    final client = MockClient((_) async => http.Response('{}', 200));

    await expectLater(
      ApiClient(storage: LocalStorage(), client: client).get('api/test'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Server URL is not configured',
        ),
      ),
    );
  });
}

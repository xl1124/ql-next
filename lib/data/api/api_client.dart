import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../local/local_storage.dart';

class QingLongNetworkException implements Exception {
  final String message;

  const QingLongNetworkException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  static const _requestTimeout = Duration(seconds: 15);

  final LocalStorage _storage;
  final http.Client? _providedClient;

  ApiClient({LocalStorage? storage, http.Client? client})
    : _storage = storage ?? LocalStorage(),
      _providedClient = client;

  http.Client _client() => _providedClient ?? http.Client();

  void _closeClient(http.Client client) {
    if (_providedClient == null) client.close();
  }

  String _bUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) {
      throw ArgumentError.value(input, "input", "Server URL is required");
    }
    url = url.replaceAll(RegExp(r"/+$"), "");
    if (!url.startsWith("http://") && !url.startsWith("https://")) {
      url = "http://$url";
    }
    return url;
  }

  Future<Map<String, String>> _hdrs() async {
    final token = await _storage.getToken();
    final h = <String, String>{
      "Content-Type": "application/json",
      "Accept": "application/json",
    };
    if (token != null && token.isNotEmpty) {
      h["Authorization"] = "Bearer $token";
    }
    return h;
  }

  Future<String> _url(String path) async {
    final base = await _storage.getServerUrl();
    if (base == null || base.trim().isEmpty) {
      throw StateError("Server URL is not configured");
    }
    return "${_bUrl(base)}/$path";
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) return <String, dynamic>{};

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException("Expected a JSON object response");
  }

  Future<Map<String, dynamic>> _req(
    Future<http.Response> Function(http.Client client) fn,
  ) async {
    final c = _client();
    try {
      final resp = await _runWithNetworkErrors(() => fn(c));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return _decodeResponse(resp);
      }
      throw HttpException(_errorMessage(resp));
    } finally {
      _closeClient(c);
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
  }) => _req((c) async {
    final uri = Uri.parse(await _url(path));
    final finalUri = queryParams != null
        ? uri.replace(queryParameters: queryParams)
        : uri;
    return c.get(finalUri, headers: await _hdrs());
  });

  Future<Map<String, dynamic>> post(String path, {dynamic body}) =>
      _req((c) async {
        return c.post(
          Uri.parse(await _url(path)),
          headers: await _hdrs(),
          body: body != null ? jsonEncode(body) : null,
        );
      });

  Future<List<int>> download(
    String path, {
    String method = 'GET',
    dynamic body,
    Map<String, String>? queryParams,
  }) async {
    final c = _client();
    try {
      final uri = Uri.parse(await _url(path));
      final finalUri = queryParams == null
          ? uri
          : uri.replace(queryParameters: queryParams);
      final request = http.Request(method, finalUri);
      final headers = await _hdrs();
      headers['Accept'] = '*/*';
      request.headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);

      final response = await _runWithNetworkErrors(
        () async => http.Response.fromStream(await c.send(request)),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      throw HttpException(_errorMessage(response));
    } finally {
      _closeClient(c);
    }
  }

  Future<Map<String, dynamic>> uploadMultipart(
    String path, {
    String method = 'POST',
    required String fieldName,
    required String filename,
    required List<int> bytes,
    Map<String, String>? fields,
  }) async {
    final c = _client();
    try {
      final request = http.MultipartRequest(
        method,
        Uri.parse(await _url(path)),
      );
      final headers = await _hdrs();
      headers.remove('Content-Type');
      request.headers.addAll(headers);
      if (fields != null) request.fields.addAll(fields);
      request.files.add(
        http.MultipartFile.fromBytes(fieldName, bytes, filename: filename),
      );
      final response = await _runWithNetworkErrors(
        () async => http.Response.fromStream(await c.send(request)),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _decodeResponse(response);
      }
      throw HttpException(_errorMessage(response));
    } finally {
      _closeClient(c);
    }
  }

  Future<Map<String, dynamic>> put(String path, {dynamic body}) =>
      _req((c) async {
        return c.put(
          Uri.parse(await _url(path)),
          headers: await _hdrs(),
          body: body != null ? jsonEncode(body) : null,
        );
      });

  Future<Map<String, dynamic>> delete(
    String path, {
    dynamic body,
    Map<String, String>? queryParams,
  }) async {
    final c = _client();
    try {
      final uri = Uri.parse(await _url(path));
      final finalUri = queryParams == null
          ? uri
          : uri.replace(queryParameters: queryParams);
      final req = http.Request('DELETE', finalUri);
      req.headers.addAll(await _hdrs());
      if (body != null) req.body = jsonEncode(body);
      final resp = await _runWithNetworkErrors(
        () async => http.Response.fromStream(await c.send(req)),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return _decodeResponse(resp);
      }
      throw HttpException(_errorMessage(resp));
    } finally {
      _closeClient(c);
    }
  }

  String _errorMessage(http.Response response) {
    final fallback = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
    final body = response.body.trim();
    if (body.isEmpty) return fallback;

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return 'HTTP ${response.statusCode}: $message';
        }
      }
    } on FormatException {
      // Keep the status code when the server response is not JSON.
    }
    return fallback;
  }

  Future<T> _runWithNetworkErrors<T>(Future<T> Function() operation) async {
    try {
      return await operation().timeout(_requestTimeout);
    } on TimeoutException {
      throw const QingLongNetworkException('连接青龙服务器超时，请检查服务器地址、端口和网络连接。');
    } on SocketException {
      throw const QingLongNetworkException(
        '无法连接青龙服务器，请检查服务器地址、端口和网络连接。\n'
        '如果后端运行在电脑本机，请不要使用 127.0.0.1 或 localhost，'
        '应填写电脑在局域网中的 IP 地址。',
      );
    } on HandshakeException {
      throw const QingLongNetworkException(
        'HTTPS 连接失败，请检查服务器证书或改用正确的 HTTP/HTTPS 地址。',
      );
    } on http.ClientException {
      throw const QingLongNetworkException('网络请求失败，请检查服务器地址和当前网络连接。');
    }
  }

  Future<Map<String, dynamic>> postTo(
    String srv,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final c = _client();
    try {
      final url = '${_bUrl(srv)}/$path';
      final resp = await _runWithNetworkErrors(
        () => c.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: body != null ? jsonEncode(body) : null,
        ),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return _decodeResponse(resp);
      }
      throw HttpException('HTTP ${resp.statusCode}: ${resp.reasonPhrase}');
    } finally {
      _closeClient(c);
    }
  }

  Future<Map<String, dynamic>> putTo(
    String srv,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final c = _client();
    try {
      final url = '${_bUrl(srv)}/$path';
      final resp = await _runWithNetworkErrors(
        () => c.put(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: body != null ? jsonEncode(body) : null,
        ),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return _decodeResponse(resp);
      }
      throw HttpException('HTTP ${resp.statusCode}: ${resp.reasonPhrase}');
    } finally {
      _closeClient(c);
    }
  }
}

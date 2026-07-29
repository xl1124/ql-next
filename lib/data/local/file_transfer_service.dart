import 'package:flutter/services.dart';

class PickedFileData {
  final String name;
  final Uint8List bytes;

  const PickedFileData({required this.name, required this.bytes});
}

class FileTransferService {
  static const _channel = MethodChannel('qinglong/file_picker');

  static Future<PickedFileData?> pickFile({
    List<String> allowedExtensions = const [],
  }) async {
    final result = await _channel
        .invokeMethod<Map<dynamic, dynamic>>('pickFile', {
          'allowedExtensions': allowedExtensions,
          'mimeType': _mimeTypeFor(allowedExtensions),
        });
    if (result == null) return null;

    final name = result['name']?.toString() ?? '';
    final rawBytes = result['bytes'];
    final bytes = rawBytes is Uint8List
        ? rawBytes
        : rawBytes is List
        ? Uint8List.fromList(rawBytes.cast<int>())
        : null;
    if (name.isEmpty || bytes == null) return null;
    return PickedFileData(name: name, bytes: bytes);
  }

  static Future<String?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) {
    return _channel.invokeMethod<String>('saveFile', {
      'fileName': fileName,
      'bytes': bytes,
      'mimeType': mimeType ?? _mimeTypeFor([_extensionOf(fileName)]),
    });
  }

  static String _extensionOf(String fileName) {
    final index = fileName.lastIndexOf('.');
    return index == -1 ? '' : fileName.substring(index + 1).toLowerCase();
  }

  static String _mimeTypeFor(List<String> extensions) {
    final extension = extensions
        .map((value) => value.toLowerCase().replaceFirst('.', ''))
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    return switch (extension) {
      'json' => 'application/json',
      'env' || 'txt' || 'log' => 'text/plain',
      'tgz' || 'gz' => 'application/gzip',
      'js' => 'text/javascript',
      'py' || 'sh' => 'text/plain',
      _ => '*/*',
    };
  }
}

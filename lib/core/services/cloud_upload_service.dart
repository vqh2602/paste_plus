import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../features/settings/domain/app_settings.dart';

class CloudUploadService {
  const CloudUploadService({
    this.freeImageUploadEndpoint = 'https://freeimage.host/api/1/upload',
    this.imgBbUploadEndpoint = 'https://api.imgbb.com/1/upload',
  });

  static const _imgBbMaxBytes = 32 * 1024 * 1024;

  final String freeImageUploadEndpoint;
  final String imgBbUploadEndpoint;

  Future<String?> uploadImage({
    required String imagePath,
    required AppSettings settings,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;

    try {
      return switch (settings.cloudImageHost) {
        'freeimage' => _uploadToFreeImageHost(
          file: file,
          apiKey: settings.freeImageApiKey,
        ),
        'imgbb' => _uploadToImgBb(file: file, apiKey: settings.imgBbApiKey),
        _ => null,
      };
    } on Object {
      return null;
    }
  }

  Future<String?> _uploadToFreeImageHost({
    required File file,
    required String apiKey,
  }) async {
    final normalizedKey = apiKey.trim();
    if (normalizedKey.isEmpty) return null;
    return _uploadMultipart(
      endpoint: Uri.parse(freeImageUploadEndpoint),
      file: file,
      fileField: 'source',
      fields: {'key': normalizedKey, 'action': 'upload', 'format': 'json'},
      readUrl: (json) {
        if (json['status_code'] != 200 || json['image'] is! Map) return null;
        final image = (json['image'] as Map).cast<String, dynamic>();
        return (image['url'] as String?) ?? (image['display_url'] as String?);
      },
    );
  }

  Future<String?> _uploadToImgBb({
    required File file,
    required String apiKey,
  }) async {
    final normalizedKey = apiKey.trim();
    if (normalizedKey.isEmpty || await file.length() > _imgBbMaxBytes) {
      return null;
    }
    final baseEndpoint = Uri.parse(imgBbUploadEndpoint);
    final endpoint = baseEndpoint.replace(
      queryParameters: {...baseEndpoint.queryParameters, 'key': normalizedKey},
    );
    return _uploadMultipart(
      endpoint: endpoint,
      file: file,
      fileField: 'image',
      readUrl: (json) {
        if (json['success'] != true || json['status'] != 200) return null;
        final data = json['data'];
        if (data is! Map) return null;
        final values = data.cast<String, dynamic>();
        final image = values['image'];
        return (values['url'] as String?) ??
            (values['display_url'] as String?) ??
            (image is Map ? image['url'] as String? : null);
      },
    );
  }

  Future<String?> _uploadMultipart({
    required Uri endpoint,
    required File file,
    required String fileField,
    required String? Function(Map<String, dynamic> json) readUrl,
    Map<String, String> fields = const {},
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(endpoint);

      final boundary =
          '----ClipFlowFormBoundary${DateTime.now().millisecondsSinceEpoch}';
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final bytes = await file.readAsBytes();
      final fileName = _safeFileName(
        file.path.split(Platform.pathSeparator).last,
      );
      final body = BytesBuilder();

      void addFormField(String name, String value) {
        body.add(utf8.encode('--$boundary\r\n'));
        body.add(
          utf8.encode('Content-Disposition: form-data; name="$name"\r\n\r\n'),
        );
        body.add(utf8.encode('$value\r\n'));
      }

      for (final field in fields.entries) {
        addFormField(field.key, field.value);
      }

      body.add(utf8.encode('--$boundary\r\n'));
      body.add(
        utf8.encode(
          'Content-Disposition: form-data; name="$fileField"; filename="$fileName"\r\n',
        ),
      );
      body.add(utf8.encode('Content-Type: ${_mimeType(fileName)}\r\n\r\n'));
      body.add(bytes);
      body.add(utf8.encode('\r\n'));
      body.add(utf8.encode('--$boundary--\r\n'));

      final payload = body.takeBytes();
      request.contentLength = payload.length;
      request.add(payload);

      final response = await request.close();
      final responseText = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(responseText);
      if (decoded is! Map<String, dynamic>) return null;
      return readUrl(decoded);
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  String _safeFileName(String value) =>
      value.replaceAll(RegExp(r'[\r\n"]'), '_').trim();

  String _mimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      'tif' || 'tiff' => 'image/tiff',
      'svg' => 'image/svg+xml',
      _ => 'image/png',
    };
  }
}

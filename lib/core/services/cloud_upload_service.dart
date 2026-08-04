import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../features/settings/domain/app_settings.dart';

class CloudUploadService {
  const CloudUploadService();

  Future<String?> uploadImage({
    required String imagePath,
    required AppSettings settings,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;

    if (settings.cloudImageHost == 'freeimage') {
      return _uploadToFreeImageHost(
        file: file,
        apiKey: settings.freeImageApiKey,
      );
    }

    return null;
  }

  Future<String?> _uploadToFreeImageHost({
    required File file,
    required String apiKey,
  }) async {
    try {
      final client = HttpClient();
      final url = Uri.parse('https://freeimage.host/api/1/upload');
      final request = await client.postUrl(url);

      final boundary =
          '----ClipFlowFormBoundary${DateTime.now().millisecondsSinceEpoch}';
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final bytes = await file.readAsBytes();
      final fileName = file.path.split('/').last;
      final body = BytesBuilder();

      void addFormField(String name, String value) {
        body.add(utf8.encode('--$boundary\r\n'));
        body.add(
          utf8.encode('Content-Disposition: form-data; name="$name"\r\n\r\n'),
        );
        body.add(utf8.encode('$value\r\n'));
      }

      addFormField('key', apiKey);
      addFormField('action', 'upload');
      addFormField('format', 'json');

      body.add(utf8.encode('--$boundary\r\n'));
      body.add(
        utf8.encode(
          'Content-Disposition: form-data; name="source"; filename="$fileName"\r\n',
        ),
      );
      body.add(utf8.encode('Content-Type: image/png\r\n\r\n'));
      body.add(bytes);
      body.add(utf8.encode('\r\n'));
      body.add(utf8.encode('--$boundary--\r\n'));

      final payload = body.takeBytes();
      request.contentLength = payload.length;
      request.add(payload);

      final response = await request.close();
      if (response.statusCode == 200) {
        final responseText = await response.transform(utf8.decoder).join();
        client.close();
        final Map<String, dynamic> json =
            jsonDecode(responseText) as Map<String, dynamic>;
        if (json['status_code'] == 200 && json['image'] is Map) {
          final imageMap = json['image'] as Map<String, dynamic>;
          final uploadedUrl =
              (imageMap['url'] as String?) ??
              (imageMap['display_url'] as String?);
          return uploadedUrl;
        }
      } else {
        client.close();
      }
    } catch (_) {}
    return null;
  }
}

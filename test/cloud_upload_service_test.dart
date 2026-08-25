import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clipflow/core/services/cloud_upload_service.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ImgBB uploads a local image with POST multipart/form-data', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<({String method, String key, String body})>();
    server.listen((request) async {
      final body = latin1.decode(
        await request.fold<List<int>>(
          <int>[],
          (all, bytes) => all..addAll(bytes),
        ),
      );
      received.complete((
        method: request.method,
        key: request.uri.queryParameters['key'] ?? '',
        body: body,
      ));
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'data': {'url': 'https://i.ibb.co/example/test.gif'},
            'success': true,
            'status': 200,
          }),
        );
      await request.response.close();
    });

    final directory = await Directory.systemTemp.createTemp('clipflow-imgbb-');
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    final image = File('${directory.path}/pixel.gif');
    await image.writeAsBytes(ascii.encode('GIF89a-test-image'));
    final service = CloudUploadService(
      imgBbUploadEndpoint:
          'http://${server.address.address}:${server.port}/1/upload',
    );

    final url = await service.uploadImage(
      imagePath: image.path,
      settings: const AppSettings(
        cloudImageHost: 'imgbb',
        imgBbApiKey: 'test-api-key',
      ),
    );
    final request = await received.future;

    expect(url, 'https://i.ibb.co/example/test.gif');
    expect(request.method, 'POST');
    expect(request.key, 'test-api-key');
    expect(request.body, contains('name="image"; filename="pixel.gif"'));
    expect(request.body, contains('Content-Type: image/gif'));
    expect(request.body, contains('GIF89a-test-image'));
  });
}

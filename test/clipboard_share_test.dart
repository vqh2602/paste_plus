import 'dart:io';

import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:clipflow/features/clipboard_history/presentation/widgets/clipboard_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildClipboardShareParams', () {
    test('shares textual clipboard types as text', () {
      const textualTypes = <ClipboardContentType>[
        ClipboardContentType.text,
        ClipboardContentType.email,
        ClipboardContentType.phone,
        ClipboardContentType.code,
        ClipboardContentType.color,
        ClipboardContentType.json,
      ];

      for (final type in textualTypes) {
        final params = buildClipboardShareParams(
          _item(contentType: type, content: '  shared content  '),
        );

        expect(params, isNotNull, reason: type.name);
        expect(params!.text, 'shared content', reason: type.name);
        expect(params.uri, isNull, reason: type.name);
        expect(params.files, isNull, reason: type.name);
      }
    });

    test('shares a link as a URI', () {
      final params = buildClipboardShareParams(
        _item(
          contentType: ClipboardContentType.url,
          content: 'Link preview',
          primaryUrl: 'https://example.com/path?q=clip',
        ),
      );

      expect(params, isNotNull);
      expect(params!.uri, Uri.parse('https://example.com/path?q=clip'));
      expect(params.text, isNull);
      expect(params.files, isNull);
    });

    test('shares a local image as an image file', () async {
      final directory = await Directory.systemTemp.createTemp(
        'clipflow_share_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final image = File('${directory.path}/preview.png');
      await image.writeAsBytes(<int>[0, 1, 2, 3]);

      final params = buildClipboardShareParams(
        _item(
          contentType: ClipboardContentType.image,
          content: image.path,
          imagePath: image.path,
          mimeType: 'image/png',
        ),
      );

      expect(params, isNotNull);
      expect(params!.files, hasLength(1));
      expect(params.files!.single.path, image.path);
      expect(params.files!.single.mimeType, 'image/png');
      expect(params.text, isNull);
      expect(params.uri, isNull);
    });

    test(
      'shares every existing file and folder in one clipboard item',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'clipflow_share_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final document = File('${directory.path}/report.docx');
        final spreadsheet = File('${directory.path}/budget.xlsx');
        final folder = Directory('${directory.path}/attachments');
        await document.writeAsString('document');
        await spreadsheet.writeAsString('spreadsheet');
        await folder.create();

        final params = buildClipboardShareParams(
          _item(
            contentType: ClipboardContentType.file,
            content: '${document.path}\n${spreadsheet.uri}\n${folder.path}',
          ),
        );

        expect(params, isNotNull);
        expect(params!.files!.map((file) => file.path), <String>[
          document.path,
          spreadsheet.path,
          folder.path,
        ]);
        expect(params.text, isNull);
        expect(params.uri, isNull);
      },
    );

    test('falls back to sharing text when a local file is unavailable', () {
      const missingPath = '/missing/clipflow/document.pdf';
      final params = buildClipboardShareParams(
        _item(contentType: ClipboardContentType.file, content: missingPath),
      );

      expect(params, isNotNull);
      expect(params!.text, missingPath);
      expect(params.files, isNull);
      expect(params.uri, isNull);
    });

    test('does not create an empty share request', () {
      final params = buildClipboardShareParams(
        _item(contentType: ClipboardContentType.text, content: '   '),
      );

      expect(params, isNull);
    });
  });
}

ClipboardItem _item({
  required ClipboardContentType contentType,
  required String content,
  String? imagePath,
  String? primaryUrl,
  String? mimeType,
}) {
  final now = DateTime(2026, 8, 25);
  return ClipboardItem(
    id: 'share-${contentType.name}',
    content: content,
    normalizedContent: content.trim(),
    contentHash: 'hash-${contentType.name}',
    contentType: contentType,
    createdAt: now,
    updatedAt: now,
    lastCopiedAt: now,
    isPinned: false,
    isSensitive: false,
    copyCount: 1,
    imagePath: imagePath,
    primaryUrl: primaryUrl,
    mimeType: mimeType,
  );
}

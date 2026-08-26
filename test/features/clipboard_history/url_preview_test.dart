import 'dart:convert';

import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_feature_extractor.dart';
import 'package:clipflow/features/clipboard_history/domain/url_preview_metadata.dart';
import 'package:clipflow/features/clipboard_history/services/url_preview_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('URL preview metadata', () {
    test('extracts Open Graph fields regardless of attribute order', () {
      final preview = UrlPreviewService.parseHtml('''
        <html>
          <head>
            <meta content="ClipFlow &amp; Clipboard" property="og:title">
            <meta name='description' content='A fast &quot;local-first&quot; history.'>
            <meta content="/assets/cover.png" property="og:image">
            <meta property="og:site_name" content="Example">
            <title>Fallback title</title>
          </head>
        </html>
        ''', Uri.parse('https://example.com/articles/clipboard'));

      expect(preview.title, 'ClipFlow & Clipboard');
      expect(preview.description, 'A fast "local-first" history.');
      expect(preview.imageUrl, 'https://example.com/assets/cover.png');
      expect(preview.siteName, 'Example');
      expect(
        preview.displayTitle(Uri.parse('https://example.com')),
        'ClipFlow & Clipboard | Example',
      );
    });

    test('falls back to the HTML title and normalizes whitespace', () {
      final preview = UrlPreviewService.parseHtml(
        '<title>  Flutter\n   Documentation &mdash; Home </title>',
        Uri.parse('https://docs.flutter.dev/'),
      );

      expect(preview.title, 'Flutter Documentation — Home');
      expect(preview.imageUrl, isNull);
    });

    test('merges with existing clipboard metadata without losing OCR', () {
      final preview = UrlPreviewMetadata(
        resolvedUrl: 'https://example.com/final',
        fetchedAt: DateTime.utc(2026, 8, 26),
        title: 'Example page',
        description: 'Preview description',
        imageUrl: 'https://example.com/cover.jpg',
        siteName: 'Example',
      );

      final merged = preview.mergeIntoClipboardMetadata(
        jsonEncode({'ocrText': 'preserved'}),
      );
      final decoded = jsonDecode(merged) as Map<String, dynamic>;
      final restored = UrlPreviewMetadata.fromClipboardMetadata(merged);

      expect(decoded['ocrText'], 'preserved');
      expect(restored?.title, 'Example page');
      expect(restored?.resolvedUrl, 'https://example.com/final');
      expect(restored?.isFresh(DateTime.utc(2026, 8, 27)), isTrue);
    });

    test('indexes preview title and description for clipboard search', () {
      final metadata = UrlPreviewMetadata(
        resolvedUrl: 'https://example.com',
        fetchedAt: DateTime.utc(2026, 8, 26),
        title: 'Flutter release notes',
        description: 'Desktop clipboard improvements',
        siteName: 'Example',
      ).mergeIntoClipboardMetadata(null);

      final features = const ClipboardFeatureExtractor().extract(
        content: 'https://example.com',
        contentType: ClipboardContentType.url,
        metadataJson: metadata,
      );

      expect(features.searchableText, contains('flutter release notes'));
      expect(
        features.searchableText,
        contains('desktop clipboard improvements'),
      );
    });

    test('rejects loopback URLs before making a request', () async {
      final preview = await const UrlPreviewService().fetch(
        'http://127.0.0.1/private',
      );

      expect(preview, isNull);
    });
  });
}

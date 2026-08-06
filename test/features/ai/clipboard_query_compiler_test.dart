import 'package:clipflow/features/ai/services/clipboard_query_validator.dart';
import 'package:clipflow/features/ai/services/clipboard_semantic_query_compiler.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/search_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const compiler = ClipboardSemanticQueryCompiler();
  const validator = ClipboardQueryValidator();
  final now = DateTime(2026, 8, 6, 10);

  ClipboardSearchQuery compile(String request) => validator.validate(
    draft: compiler.compile(request),
    now: now,
  );

  group('type words are filters, never text keywords', () {
    test('"Tìm ảnh" filters by image content type', () {
      final query = compile('Tìm ảnh');
      expect(query.contentTypes, {ClipboardContentType.image});
      expect(query.textQuery, isNull);
      expect(query.containsUrl, isNull);
    });

    test('"Các clipboard có link" sets containsUrl without a text query', () {
      final query = compile('Các clipboard có link');
      expect(query.containsUrl, isTrue);
      expect(query.textQuery, isNull);
    });

    test('"Tìm link GitHub" resolves the host instead of a keyword', () {
      final query = compile('Tìm link GitHub');
      expect(query.containsUrl, isTrue);
      expect(query.urlHosts, contains('github.com'));
      expect(query.textQuery, isNull);
    });

    test('"Link ảnh" is an image URL, not a copied image file', () {
      final query = compile('Link ảnh');
      expect(query.containsUrl, isTrue);
      expect(query.urlKind, ClipboardUrlKind.image);
      expect(query.contentTypes, isEmpty);
    });

    test('"File ảnh" becomes a file query with image extensions', () {
      final query = compile('Tìm file ảnh');
      expect(query.contentTypes, {ClipboardContentType.file});
      expect(query.fileExtensions, containsAll(['png', 'jpg']));
      expect(query.containsUrl, isNull);
    });
  });

  group('real subject matter survives as text query', () {
    test('"Tìm code Flutter có Firebase" keeps the topic', () {
      final query = compile('Tìm code Flutter có Firebase');
      expect(query.contentTypes, {ClipboardContentType.code});
      final text = query.textQuery!.toLowerCase();
      expect(text, contains('flutter'));
      expect(text, contains('firebase'));
    });

    test('"Ảnh có chữ hóa đơn" searches OCR text for the subject', () {
      final query = compile('Ảnh có chữ hóa đơn');
      expect(query.contentTypes, {ClipboardContentType.image});
      expect(query.textQuery!.toLowerCase(), contains('hóa đơn'));
    });
  });

  group('date presets resolve deterministically', () {
    test('"hôm qua" resolves to the previous calendar day', () {
      final query = compile('Tìm các link GitHub tôi copy hôm qua');
      expect(query.containsUrl, isTrue);
      expect(query.urlHosts, contains('github.com'));
      expect(query.dateRange!.from, DateTime(2026, 8, 5));
      expect(query.dateRange!.to, DateTime(2026, 8, 6));
    });

    test('"tuần trước" resolves to a 7 day window', () {
      final query = compile('tìm ảnh từ Chrome tuần trước');
      expect(query.contentTypes, {ClipboardContentType.image});
      expect(query.sourceApps, contains('Chrome'));
      expect(query.dateRange!.from, DateTime(2026, 7, 30));
    });
  });

  group('multilingual parity', () {
    test('English', () {
      expect(
        compile('find the images I copied').contentTypes,
        {ClipboardContentType.image},
      );
      final urls = compile('show me clipboard items containing links');
      expect(urls.containsUrl, isTrue);
      expect(urls.textQuery, isNull);
    });

    test('Japanese', () {
      expect(
        compile('コピーした画像を探して').contentTypes,
        {ClipboardContentType.image},
      );
      final urls = compile('リンクを含むクリップボードを見せて');
      expect(urls.containsUrl, isTrue);
      expect(urls.textQuery, isNull);
    });

    test('Korean', () {
      expect(
        compile('복사한 이미지 찾아줘').contentTypes,
        {ClipboardContentType.image},
      );
      final urls = compile('링크가 포함된 클립보드 검색');
      expect(urls.containsUrl, isTrue);
      expect(urls.textQuery, isNull);
    });

    test('German', () {
      expect(
        compile('finde die kopierten Bilder').contentTypes,
        {ClipboardContentType.image},
      );
      final urls = compile('zeig mir Zwischenablage mit Links');
      expect(urls.containsUrl, isTrue);
      expect(urls.textQuery, isNull);
    });
  });

  group('validator hardening', () {
    test('sensitive items are never included and limits are clamped', () {
      final query = validator.validate(
        draft: compiler.compile('tìm ảnh').copyWithLimit(9999),
        now: now,
      );
      expect(query.includeSensitive, isFalse);
      expect(query.limit, 100);
    });

    test('url content type or host implies containsUrl', () {
      const repaired = ClipboardSearchQuery(
        contentTypes: {ClipboardContentType.url},
      );
      expect(validator.repairQuery(repaired).containsUrl, isTrue);
      expect(
        validator
            .repairQuery(const ClipboardSearchQuery(urlHosts: {'github.com'}))
            .containsUrl,
        isTrue,
      );
    });
  });
}


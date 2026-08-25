import 'package:clipflow/features/clipboard_history/domain/smart_text_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SmartTextTools transforms', () {
    test('formats and minifies JSON', () {
      expect(
        SmartTextTools.transform('{"a":1}', TextTransform.formatJson),
        '{\n  "a": 1\n}',
      );
      expect(
        SmartTextTools.transform('{\n  "a": 1\n}', TextTransform.minifyJson),
        '{"a":1}',
      );
    });

    test('encodes and decodes Base64 and URLs', () {
      expect(
        SmartTextTools.transform('Xin chào', TextTransform.base64Encode),
        'WGluIGNow6Bv',
      );
      expect(
        SmartTextTools.transform('WGluIGNow6Bv', TextTransform.base64Decode),
        'Xin chào',
      );
      expect(
        SmartTextTools.transform('a b&c', TextTransform.urlEncode),
        'a%20b%26c',
      );
    });

    test('hashes, sorts and removes duplicate lines', () {
      expect(
        SmartTextTools.transform('hello', TextTransform.md5Hash),
        '5d41402abc4b2a76b9719d911017c592',
      );
      expect(
        SmartTextTools.transform('b\na\nB', TextTransform.sortLines),
        'a\nb\nB',
      );
      expect(
        SmartTextTools.transform('a\nb\na', TextTransform.uniqueLines),
        'a\nb',
      );
    });
  });

  test('Link Cleaner removes tracking parameters and preserves useful ones', () {
    expect(
      SmartTextTools.cleanUrl(
        'https://example.com/article?id=7&utm_source=newsletter&fbclid=abc#part',
      ),
      'https://example.com/article?id=7#part',
    );
    expect(
      SmartTextTools.cleanUrl('https://example.com/?utm_source=newsletter'),
      'https://example.com/',
    );
  });

  group('smart recognition', () {
    test('recognizes JWT structure', () {
      expect(
        SmartTextTools.isJwt(
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
          'eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature',
        ),
        isTrue,
      );
      expect(SmartTextTools.isJwt('one.two.three'), isFalse);
    });

    test('detects programming language', () {
      expect(
        SmartTextTools.programmingLanguage(
          "import 'package:flutter/widgets.dart';\nclass Demo extends StatelessWidget {}",
        ),
        'Dart',
      );
      expect(
        SmartTextTools.programmingLanguage('SELECT * FROM clipboard_items'),
        'SQL',
      );
    });

    test('calculates valid expressions only', () {
      expect(SmartTextTools.calculate('2 + 3 * (4 - 1)'), '11');
      expect(SmartTextTools.calculate('sqrt(81) + 0.5'), '9.5');
      expect(SmartTextTools.calculate('123456'), isNull);
      expect(SmartTextTools.calculate('Call +84 123'), isNull);
      expect(SmartTextTools.calculate('1 / 0'), isNull);
    });
  });
}

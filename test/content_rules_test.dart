import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/content_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentNormalizer', () {
    test('trims and normalizes line endings', () {
      expect(ContentNormalizer.normalize('  hello\r\nworld  '), 'hello\nworld');
    });
  });

  group('ContentClassifier', () {
    final cases = <String, ClipboardContentType>{
      'https://flutter.dev/docs': ClipboardContentType.url,
      'hello@example.com': ClipboardContentType.email,
      '+84 912 345 678': ClipboardContentType.phone,
      '#635BFF': ClipboardContentType.color,
      '{"ok":true}': ClipboardContentType.json,
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
              'eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature':
          ClipboardContentType.jwt,
      '/Users/demo/file.txt': ClipboardContentType.file,
      '/Users/demo/report.xlsx': ClipboardContentType.file,
      r'C:\Users\demo\report.docx': ClipboardContentType.file,
      'file:///Users/demo/report.pdf': ClipboardContentType.file,
      '/Users/demo/one.png\n/Users/demo/two.docx': ClipboardContentType.file,
      '😀': ClipboardContentType.emoji,
      '❤️ 👍🏽 👨‍👩‍👧‍👦 🇻🇳 1️⃣': ClipboardContentType.emoji,
      'class Demo {\n  void run() {}\n}': ClipboardContentType.code,
      'def greet(name):\n    return f"Hello {name}"': ClipboardContentType.code,
      'Ghi chú bình thường': ClipboardContentType.text,
      'Xin chào 👋': ClipboardContentType.text,
    };

    for (final entry in cases.entries) {
      test('classifies ${entry.value.name}', () {
        expect(ContentClassifier.classify(entry.key), entry.value);
      });
    }
  });

  group('SensitiveContentDetector', () {
    test('recognizes OTP without blocking normal short text', () {
      expect(SensitiveContentDetector.isSensitive('123456'), isTrue);
      expect(SensitiveContentDetector.isSensitive('hello'), isFalse);
    });

    test('recognizes a long token and allows disabling the rule', () {
      const token = 'eyJhbGciOiJIUzI1NiJ9.abcdefghijklmnopqrstuvwxyz1234567890';
      expect(SensitiveContentDetector.isSensitive(token), isTrue);
      expect(
        SensitiveContentDetector.isSensitive(token, ignoreLongToken: false),
        isFalse,
      );
    });
  });
}

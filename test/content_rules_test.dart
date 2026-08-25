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
      '0912345678': ClipboardContentType.phone,
      '079203001234': ClipboardContentType.text,
      '079 203 001234': ClipboardContentType.text,
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

    test('recognizes international and national phone formats', () {
      const phoneNumbers = [
        '+1 (202) 555-0123 ext. 45',
        'tel:+44 20 7946 0958;ext=42',
        '0044 20 7946 0958',
        '+33 6 12 34 56 78',
        '+55 (11) 91234-5678',
        '+971 50 123 4567',
        '(202) 555-0123',
        '020 7946 0958',
        '06 12 34 56 78',
        '98765 43210',
        '8123 4567',
        '＋８１ ９０－１２３４－５６７８',
      ];
      for (final value in phoneNumbers) {
        expect(
          ContentClassifier.classify(value),
          ClipboardContentType.phone,
          reason: value,
        );
      }

      for (final value in ['2026-08-25', '+999 123456789', '123-45-6789']) {
        expect(
          ContentClassifier.classify(value),
          ClipboardContentType.text,
          reason: value,
        );
      }
    });
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

    test(
      'recognizes payment cards with Luhn without matching invalid cards',
      () {
        expect(
          SensitiveContentDetector.containsFinancialOrIdentity(
            'Card: 4111 1111 1111 1111',
          ),
          isTrue,
        );
        expect(
          SensitiveContentDetector.containsFinancialOrIdentity(
            'Card: 4111 1111 1111 1112',
          ),
          isFalse,
        );
      },
    );

    test('recognizes labeled identity and passport numbers', () {
      expect(
        SensitiveContentDetector.containsFinancialOrIdentity(
          'CCCD: 079203001234',
        ),
        isTrue,
      );
      expect(
        SensitiveContentDetector.containsFinancialOrIdentity(
          'Số định danh cá nhân: 079 203 001 234',
        ),
        isTrue,
      );
      expect(
        SensitiveContentDetector.containsFinancialOrIdentity('CMND: 012345678'),
        isTrue,
      );
      expect(
        SensitiveContentDetector.containsFinancialOrIdentity(
          'Hộ chiếu: B12345678',
        ),
        isTrue,
      );
      expect(
        SensitiveContentDetector.containsFinancialOrIdentity('Order 12345678'),
        isFalse,
      );
    });

    test('recognizes international IDs without matching phone numbers', () {
      const validIdentityNumbers = [
        '079203001234', // Vietnam CCCD
        '079-203-001234',
        '11010519491231002X', // China citizen ID
        '2345 6789 0124', // India Aadhaar
        '123456789018', // Japan My Number
        '1101700203450', // Thailand national ID
        'S1234567D', // Singapore NRIC
        'A123456789', // Taiwan national ID
        '12345678Z', // Spain DNI
        '123-45-6789', // United States SSN
        '900101-1234567', // South Korea resident number
      ];
      for (final value in validIdentityNumbers) {
        expect(
          SensitiveContentDetector.containsIdentityDocument(value),
          isTrue,
          reason: value,
        );
        expect(
          ContentClassifier.classify(value),
          ClipboardContentType.text,
          reason: value,
        );
      }

      final passportMrz = [
        'P<VNMSAMPLE<<TEST'.padRight(44, '<'),
        'C12345678VNM9001011M3001012'.padRight(44, '<'),
      ].join('\n');
      expect(
        SensitiveContentDetector.containsIdentityDocument(passportMrz),
        isTrue,
      );
      expect(
        SensitiveContentDetector.containsIdentityDocument('护照号码: E12345678'),
        isTrue,
      );
      expect(
        SensitiveContentDetector.containsIdentityDocument('여권 번호: M12345678'),
        isTrue,
      );

      expect(
        SensitiveContentDetector.containsIdentityDocument('999203001234'),
        isFalse,
      );
      expect(
        SensitiveContentDetector.containsIdentityDocument('110105194912310021'),
        isFalse,
      );
      expect(
        SensitiveContentDetector.containsIdentityDocument('12345678A'),
        isFalse,
      );
      expect(
        SensitiveContentDetector.containsIdentityDocument('0912345678'),
        isFalse,
      );
    });
  });
}

import 'dart:convert';

import '../../../../core/utils/color_parser.dart';
import 'clipboard_content_type.dart';
import 'identity_document_detector.dart';
import 'international_phone_detector.dart';
import 'smart_text_tools.dart';

class ContentNormalizer {
  const ContentNormalizer._();

  static String normalize(String value) {
    return value.replaceAll('\r\n', '\n').trim();
  }
}

class ContentClassifier {
  const ContentClassifier._();

  static final RegExp _email = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );
  static final RegExp _filePath = RegExp(
    r'^(?:/[^\n]+|[A-Za-z]:[\\/][^\n]+|\\\\[^\\/\n]+[\\/][^\n]+|file://[^\n]+)$',
  );

  static ClipboardContentType classify(String raw) {
    final value = ContentNormalizer.normalize(raw);
    if (_isJson(value)) return ClipboardContentType.json;
    final uri = Uri.tryParse(value);
    if (uri != null &&
        uri.hasScheme &&
        {'http', 'https'}.contains(uri.scheme)) {
      return ClipboardContentType.url;
    }
    if (_email.hasMatch(value)) return ClipboardContentType.email;
    if (ColorParser.parse(value) != null) return ClipboardContentType.color;
    if (_isEmojiOnly(value)) return ClipboardContentType.emoji;
    // Numeric identity documents can also satisfy regional phone metadata.
    // Keep verified IDs as text so they can be filtered as sensitive data
    // instead of being presented as phone numbers.
    if (SensitiveContentDetector.containsIdentityDocument(value)) {
      return ClipboardContentType.text;
    }
    if (InternationalPhoneDetector.isPhoneNumber(value)) {
      return ClipboardContentType.phone;
    }
    if (SmartTextTools.isJwt(value)) return ClipboardContentType.jwt;
    if (_isFilePathList(value)) return ClipboardContentType.file;
    if (SmartTextTools.programmingLanguage(value) != null ||
        _looksLikeCode(value)) {
      return ClipboardContentType.code;
    }
    return ClipboardContentType.text;
  }

  static bool _isFilePathList(String value) {
    final paths = value
        .split('\n')
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    return paths.isNotEmpty && paths.every(_filePath.hasMatch);
  }

  static bool _isJson(String value) {
    if (!(value.startsWith('{') && value.endsWith('}')) &&
        !(value.startsWith('[') && value.endsWith(']'))) {
      return false;
    }
    try {
      jsonDecode(value);
      return true;
    } on FormatException {
      return false;
    }
  }

  static bool _isEmojiOnly(String value) {
    if (value.isEmpty) return false;
    var hasEmoji = false;
    var keycapPending = false;
    for (final rune in value.runes) {
      if (_isEmojiBase(rune)) {
        if (keycapPending) return false;
        hasEmoji = true;
        continue;
      }
      if (rune == 0x23 || rune == 0x2A || (rune >= 0x30 && rune <= 0x39)) {
        keycapPending = true;
        continue;
      }
      if (rune == 0x20E3 && keycapPending) {
        hasEmoji = true;
        keycapPending = false;
        continue;
      }
      if (_isEmojiComponent(rune)) continue;
      if (_isWhitespace(rune)) {
        if (keycapPending) return false;
        continue;
      }
      return false;
    }
    return hasEmoji && !keycapPending;
  }

  static bool _isEmojiBase(int rune) =>
      (rune >= 0x1F000 && rune <= 0x1FAFF) ||
      (rune >= 0x2600 && rune <= 0x27BF) ||
      (rune >= 0x2190 && rune <= 0x21FF) ||
      (rune >= 0x2300 && rune <= 0x23FF) ||
      (rune >= 0x25A0 && rune <= 0x25FF) ||
      const {
        0x00A9,
        0x00AE,
        0x203C,
        0x2049,
        0x2122,
        0x2139,
        0x3030,
        0x303D,
        0x3297,
        0x3299,
      }.contains(rune);

  static bool _isEmojiComponent(int rune) =>
      rune == 0x200D ||
      rune == 0xFE0E ||
      rune == 0xFE0F ||
      (rune >= 0x1F3FB && rune <= 0x1F3FF) ||
      (rune >= 0xE0020 && rune <= 0xE007F);

  static bool _isWhitespace(int rune) =>
      rune == 0x20 || rune == 0x09 || rune == 0x0A || rune == 0x0D;

  static bool _looksLikeCode(String value) {
    if (RegExp(
      r'^(SELECT|INSERT|UPDATE|DELETE|CREATE)\s',
      caseSensitive: false,
    ).hasMatch(value)) {
      return true;
    }
    final signals = [
      RegExp(
        r'\b(class|const|final|void|function|import|return|async|await)\b',
      ),
      RegExp(r'=>|==|!=|\{[^}]*\}|;\s*(?:\n|$)'),
      RegExp(r'^\s*(?:curl|git|npm|flutter|dart)\s', multiLine: true),
    ];
    return signals.where((pattern) => pattern.hasMatch(value)).length >= 2 ||
        (value.contains('\n') &&
            signals.any((pattern) => pattern.hasMatch(value)));
  }
}

class SensitiveContentDetector {
  const SensitiveContentDetector._();

  static bool isSensitive(
    String value, {
    bool ignoreOtp = true,
    bool ignoreLongToken = true,
    bool ignoreFinancialAndIdentity = true,
  }) {
    final normalized = ContentNormalizer.normalize(value);
    if (ignoreOtp && RegExp(r'^\d{4,8}$').hasMatch(normalized)) return true;
    if (ignoreLongToken &&
        !normalized.contains(RegExp(r'\s')) &&
        normalized.length >= 48 &&
        RegExp(r'^[A-Za-z0-9_\-+.=/]+$').hasMatch(normalized)) {
      return true;
    }
    if (ignoreFinancialAndIdentity && containsFinancialOrIdentity(normalized)) {
      return true;
    }
    return false;
  }

  static bool containsFinancialOrIdentity(String value) {
    for (final match in RegExp(
      r'(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)',
    ).allMatches(value)) {
      final digits = match.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 13 && digits.length <= 19 && _passesLuhn(digits)) {
        return true;
      }
    }
    return containsIdentityDocument(value);
  }

  static bool containsIdentityDocument(String value) {
    return IdentityDocumentDetector.contains(value);
  }

  static bool _passesLuhn(String digits) {
    var sum = 0;
    var doubleDigit = false;
    for (var index = digits.length - 1; index >= 0; index--) {
      var digit = digits.codeUnitAt(index) - 0x30;
      if (doubleDigit) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      doubleDigit = !doubleDigit;
    }
    return sum % 10 == 0;
  }
}

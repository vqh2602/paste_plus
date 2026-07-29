import 'dart:convert';

import '../../../../core/utils/color_parser.dart';
import 'clipboard_content_type.dart';

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
  static final RegExp _phone = RegExp(r'^\+?[0-9][0-9 ()-]{6,18}$');
  static final RegExp _filePath = RegExp(
    r'^(?:/[^\n]+|[A-Za-z]:\\[^\n]+|file://[^\n]+)$',
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
    if (_phone.hasMatch(value)) return ClipboardContentType.phone;
    if (_filePath.hasMatch(value)) return ClipboardContentType.file;
    if (_looksLikeCode(value)) return ClipboardContentType.code;
    return ClipboardContentType.text;
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
  }) {
    final normalized = ContentNormalizer.normalize(value);
    if (ignoreOtp && RegExp(r'^\d{4,8}$').hasMatch(normalized)) return true;
    if (ignoreLongToken &&
        !normalized.contains(RegExp(r'\s')) &&
        normalized.length >= 48 &&
        RegExp(r'^[A-Za-z0-9_\-+.=/]+$').hasMatch(normalized)) {
      return true;
    }
    return false;
  }
}

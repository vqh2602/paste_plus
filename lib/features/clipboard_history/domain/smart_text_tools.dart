import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

enum TextTransform {
  formatJson,
  minifyJson,
  base64Encode,
  base64Decode,
  urlEncode,
  urlDecode,
  uppercase,
  lowercase,
  titleCase,
  parseTimestamp,
  md5Hash,
  sortLines,
  uniqueLines,
}

class TextTransformException implements Exception {
  const TextTransformException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SmartTextTools {
  const SmartTextTools._();

  static String transform(String input, TextTransform transform) {
    try {
      return switch (transform) {
        TextTransform.formatJson => const JsonEncoder.withIndent(
          '  ',
        ).convert(jsonDecode(input)),
        TextTransform.minifyJson => jsonEncode(jsonDecode(input)),
        TextTransform.base64Encode => base64Encode(utf8.encode(input)),
        TextTransform.base64Decode => utf8.decode(base64Decode(input.trim())),
        TextTransform.urlEncode => Uri.encodeComponent(input),
        TextTransform.urlDecode => Uri.decodeComponent(input),
        TextTransform.uppercase => input.toUpperCase(),
        TextTransform.lowercase => input.toLowerCase(),
        TextTransform.titleCase => _titleCase(input),
        TextTransform.parseTimestamp => _parseTimestamp(input),
        TextTransform.md5Hash => md5.convert(utf8.encode(input)).toString(),
        TextTransform.sortLines => _sortLines(input),
        TextTransform.uniqueLines => _uniqueLines(input),
      };
    } on TextTransformException {
      rethrow;
    } on Object catch (error) {
      throw TextTransformException(error.toString());
    }
  }

  static String cleanUrl(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty) {
      throw const TextTransformException('Invalid URL');
    }
    final filtered = <String, List<String>>{};
    for (final entry in uri.queryParametersAll.entries) {
      if (!_trackingParameters.contains(entry.key.toLowerCase())) {
        filtered[entry.key] = entry.value;
      }
    }
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
      queryParameters: filtered.isEmpty ? null : filtered,
      fragment: uri.hasFragment ? uri.fragment : null,
    ).toString();
  }

  static bool isJwt(String input) {
    final parts = input.trim().split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) return false;
    try {
      final header = _decodeJwtPart(parts[0]);
      final payload = _decodeJwtPart(parts[1]);
      return header is Map<String, dynamic> &&
          payload is Map<String, dynamic> &&
          (header.containsKey('alg') || header['typ'] == 'JWT');
    } on Object {
      return false;
    }
  }

  static String? programmingLanguage(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;
    final rules = <(String, List<RegExp>)>[
      (
        'Dart',
        [
          RegExp(r'''\bimport\s+['"](?:dart:|package:)'''),
          RegExp(r'\b(?:StatelessWidget|StatefulWidget|BuildContext)\b'),
        ],
      ),
      (
        'TypeScript',
        [
          RegExp(r'\b(?:interface|type)\s+\w+\s*[={]'),
          RegExp(r'\b(?:string|number|boolean)\s*[;,)\]]'),
        ],
      ),
      (
        'JavaScript',
        [
          RegExp(r'\b(?:const|let|var)\s+\w+\s*='),
          RegExp(r'\b(?:function|console\.log|require\()'),
        ],
      ),
      (
        'Python',
        [
          RegExp(r'^\s*(?:def|class|from|import)\s+', multiLine: true),
          RegExp(r':\s*(?:#.*)?$', multiLine: true),
        ],
      ),
      (
        'Swift',
        [
          RegExp(r'\b(?:import\s+SwiftUI|struct\s+\w+\s*:\s*View)\b'),
          RegExp(r'\b(?:let|var)\s+\w+\s*:\s*[A-Z]\w*'),
        ],
      ),
      (
        'Kotlin',
        [RegExp(r'\bfun\s+\w+\s*\('), RegExp(r'\b(?:val|var)\s+\w+\s*[:=]')],
      ),
      (
        'Java',
        [
          RegExp(r'\bpublic\s+(?:static\s+)?(?:class|void)\b'),
          RegExp(r'\bSystem\.out\.print'),
        ],
      ),
      (
        'C/C++',
        [
          RegExp(r'^\s*#include\s*[<\"]', multiLine: true),
          RegExp(r'\b(?:std::|printf\s*\(|int\s+main\s*\()'),
        ],
      ),
      (
        'SQL',
        [
          RegExp(
            r'^\s*(?:SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER)\b',
            caseSensitive: false,
          ),
        ],
      ),
      (
        'Shell',
        [
          RegExp(r'^\s*#!\s*/(?:usr/)?bin/(?:ba|z|fi)?sh', multiLine: true),
          RegExp(r'^\s*(?:curl|grep|sed|awk|export)\s+', multiLine: true),
        ],
      ),
      (
        'HTML',
        [
          RegExp(
            r'<!doctype\s+html|<(?:html|body|div|script)\b',
            caseSensitive: false,
          ),
        ],
      ),
      (
        'CSS',
        [
          RegExp(
            r'(?:^|\n)\s*[.#]?[\w-]+\s*\{[^}]*[\w-]+\s*:',
            multiLine: true,
          ),
        ],
      ),
    ];
    String? bestLanguage;
    var bestScore = 0;
    for (final rule in rules) {
      final score = rule.$2.where((pattern) => pattern.hasMatch(value)).length;
      if (score > bestScore) {
        bestScore = score;
        bestLanguage = rule.$1;
      }
    }
    return bestLanguage;
  }

  static String? calculate(String input) {
    final value = input.trim();
    if (value.isEmpty || value.length > 300 || value.contains('\n')) {
      return null;
    }
    if (!RegExp(
      r'[+\-*/%^()]|\b(?:sqrt|abs|sin|cos|tan|log|ln)\b',
    ).hasMatch(value)) {
      return null;
    }
    try {
      final result = _ExpressionParser(value).parse();
      if (!result.isFinite) return null;
      if ((result - result.roundToDouble()).abs() < 1e-12) {
        return result.round().toString();
      }
      return result
          .toStringAsPrecision(12)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    } on Object {
      return null;
    }
  }

  static dynamic _decodeJwtPart(String part) {
    final normalized = base64Url.normalize(part);
    return jsonDecode(utf8.decode(base64Url.decode(normalized)));
  }

  static String _titleCase(String input) => input.replaceAllMapped(
    RegExp(r'\p{L}[\p{L}\p{M}\p{N}]*', unicode: true),
    (match) {
      final word = match.group(0)!;
      final first = String.fromCharCode(word.runes.first);
      return '${first.toUpperCase()}${word.substring(first.length).toLowerCase()}';
    },
  );

  static String _parseTimestamp(String input) {
    final value = input.trim();
    DateTime? parsed;
    final integer = int.tryParse(value);
    if (integer != null) {
      final absolute = integer.abs();
      if (absolute >= 100000000000) {
        parsed = DateTime.fromMillisecondsSinceEpoch(integer);
      } else if (absolute >= 100000000) {
        parsed = DateTime.fromMillisecondsSinceEpoch(integer * 1000);
      }
    }
    parsed ??= DateTime.tryParse(value);
    if (parsed == null) {
      throw const TextTransformException('Invalid timestamp');
    }
    return 'Local: ${parsed.toLocal().toIso8601String()}\nUTC: ${parsed.toUtc().toIso8601String()}';
  }

  static String _sortLines(String input) {
    final lines = input.split('\n');
    lines.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return lines.join('\n');
  }

  static String _uniqueLines(String input) {
    final seen = <String>{};
    return input.split('\n').where(seen.add).join('\n');
  }

  static const _trackingParameters = {
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'utm_id',
    'utm_name',
    'gclid',
    'dclid',
    'fbclid',
    'msclkid',
    'mc_cid',
    'mc_eid',
    'igshid',
    'ref',
    'ref_src',
    'spm',
    'si',
    '_hsenc',
    '_hsmi',
    'vero_conv',
    'vero_id',
    'wickedid',
    'yclid',
    'twclid',
  };
}

class _ExpressionParser {
  _ExpressionParser(String source)
    : _source = source.replaceAll('×', '*').replaceAll('÷', '/');

  final String _source;
  int _index = 0;

  double parse() {
    final result = _expression();
    _skipSpaces();
    if (_index != _source.length) throw const FormatException();
    return result;
  }

  double _expression() {
    var value = _term();
    while (true) {
      if (_consume('+')) {
        value += _term();
      } else if (_consume('-')) {
        value -= _term();
      } else {
        return value;
      }
    }
  }

  double _term() {
    var value = _power();
    while (true) {
      if (_consume('*')) {
        value *= _power();
      } else if (_consume('/')) {
        final divisor = _power();
        if (divisor == 0) throw const FormatException();
        value /= divisor;
      } else if (_consume('%')) {
        final divisor = _power();
        if (divisor == 0) throw const FormatException();
        value %= divisor;
      } else {
        return value;
      }
    }
  }

  double _power() {
    final value = _unary();
    if (_consume('^')) return math.pow(value, _power()).toDouble();
    return value;
  }

  double _unary() {
    if (_consume('+')) return _unary();
    if (_consume('-')) return -_unary();
    return _primary();
  }

  double _primary() {
    if (_consume('(')) {
      final value = _expression();
      if (!_consume(')')) throw const FormatException();
      return value;
    }
    _skipSpaces();
    final identifier = _read(RegExp(r'[A-Za-z]'));
    if (identifier.isNotEmpty) {
      if (identifier == 'pi') return math.pi;
      if (identifier == 'e') return math.e;
      if (!_consume('(')) throw const FormatException();
      final argument = _expression();
      if (!_consume(')')) throw const FormatException();
      return switch (identifier.toLowerCase()) {
        'sqrt' when argument >= 0 => math.sqrt(argument),
        'abs' => argument.abs(),
        'sin' => math.sin(argument),
        'cos' => math.cos(argument),
        'tan' => math.tan(argument),
        'ln' when argument > 0 => math.log(argument),
        'log' when argument > 0 => math.log(argument) / math.ln10,
        'round' => argument.roundToDouble(),
        'floor' => argument.floorToDouble(),
        'ceil' => argument.ceilToDouble(),
        _ => throw const FormatException(),
      };
    }
    final number = _read(RegExp(r'[0-9.]'));
    final parsed = double.tryParse(number);
    if (parsed == null) throw const FormatException();
    return parsed;
  }

  String _read(RegExp allowed) {
    _skipSpaces();
    final start = _index;
    while (_index < _source.length && allowed.hasMatch(_source[_index])) {
      _index++;
    }
    return _source.substring(start, _index);
  }

  bool _consume(String token) {
    _skipSpaces();
    if (!_source.startsWith(token, _index)) return false;
    _index += token.length;
    return true;
  }

  void _skipSpaces() {
    while (_index < _source.length && _source[_index].trim().isEmpty) {
      _index++;
    }
  }
}

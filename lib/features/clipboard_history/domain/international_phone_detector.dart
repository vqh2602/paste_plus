import 'package:phone_numbers_parser/phone_numbers_parser.dart';

class InternationalPhoneDetector {
  const InternationalPhoneDetector._();

  static const List<IsoCode> _commonRegions = [
    IsoCode.VN,
    IsoCode.US,
    IsoCode.CA,
    IsoCode.GB,
    IsoCode.FR,
    IsoCode.DE,
    IsoCode.ES,
    IsoCode.IT,
    IsoCode.AU,
    IsoCode.NZ,
    IsoCode.JP,
    IsoCode.KR,
    IsoCode.CN,
    IsoCode.IN,
    IsoCode.SG,
    IsoCode.HK,
    IsoCode.TH,
    IsoCode.ID,
    IsoCode.MY,
    IsoCode.PH,
    IsoCode.BR,
    IsoCode.MX,
    IsoCode.AR,
    IsoCode.ZA,
    IsoCode.RU,
    IsoCode.AE,
    IsoCode.SA,
  ];

  static final RegExp _extension = RegExp(
    r'(?:\s*(?:ext(?:ension)?\.?|x|#|máy\s*lẻ|nhánh|分機|内線|내선)\s*[:.=]?\s*|;ext=)\d{1,6}\s*$',
    caseSensitive: false,
    unicode: true,
  );

  static bool isPhoneNumber(String value) {
    var normalized = _normalizeDigits(value).trim();
    if (normalized.isEmpty || normalized.contains('\n')) return false;

    var hasExplicitPhoneContext = false;
    if (normalized.toLowerCase().startsWith('tel:')) {
      normalized = normalized.substring(4).trim();
      hasExplicitPhoneContext = true;
    }
    normalized = normalized.replaceFirst(_extension, '');

    if (!RegExp(r'^\+?[0-9][0-9\s()./\-]*$').hasMatch(normalized) &&
        !RegExp(r'^\([0-9]{1,5}\)[0-9\s./\-]+$').hasMatch(normalized)) {
      return false;
    }
    if (!_hasBalancedParentheses(normalized) || _looksLikeDate(normalized)) {
      return false;
    }

    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) return false;

    if (normalized.startsWith('+')) {
      return _isValid(normalized);
    }
    if (normalized.startsWith('00') && digits.length >= 9) {
      return _isValid('+${digits.substring(2)}');
    }

    final hasFormatting =
        hasExplicitPhoneContext || RegExp(r'[\s()./\-]').hasMatch(normalized);
    if (!hasFormatting && !_hasRecognizableNationalPrefix(digits)) {
      return false;
    }
    for (final region in _commonRegions) {
      if (_isValid(normalized, destinationCountry: region)) return true;
    }
    return false;
  }

  static bool _isValid(String value, {IsoCode? destinationCountry}) {
    try {
      final number = PhoneNumber.parse(
        value,
        destinationCountry: destinationCountry,
      );
      return number.isValid();
    } on Object {
      return false;
    }
  }

  static bool _hasRecognizableNationalPrefix(String digits) {
    return RegExp(r'^0(?:2\d{8,9}|[35789]\d{8})$').hasMatch(digits) ||
        RegExp(r'^[2-9]\d{2}[2-9]\d{6}$').hasMatch(digits) ||
        RegExp(r'^1[3-9]\d{9}$').hasMatch(digits) ||
        RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ||
        RegExp(r'^[3689]\d{7}$').hasMatch(digits) ||
        RegExp(r'^[6789]\d{8}$').hasMatch(digits) ||
        RegExp(r'^0\d{9,10}$').hasMatch(digits);
  }

  static bool _hasBalancedParentheses(String value) {
    var depth = 0;
    for (final rune in value.runes) {
      if (rune == 0x28) depth++;
      if (rune == 0x29 && --depth < 0) return false;
      if (depth > 1) return false;
    }
    return depth == 0;
  }

  static bool _looksLikeDate(String value) {
    return RegExp(r'^\d{4}[-/.]\d{1,2}[-/.]\d{1,2}$').hasMatch(value) ||
        RegExp(r'^\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}$').hasMatch(value);
  }

  static String _normalizeDigits(String value) {
    final result = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= 0xFF10 && rune <= 0xFF19) {
        result.writeCharCode(0x30 + rune - 0xFF10);
      } else if (rune >= 0x0660 && rune <= 0x0669) {
        result.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        result.writeCharCode(0x30 + rune - 0x06F0);
      } else if (rune == 0x00A0 || rune == 0x202F) {
        result.write(' ');
      } else if (rune == 0xFF0B) {
        result.write('+');
      } else if (rune == 0xFF08) {
        result.write('(');
      } else if (rune == 0xFF09) {
        result.write(')');
      } else if (rune == 0xFF0D) {
        result.write('-');
      } else if (rune == 0x3000) {
        result.write(' ');
      } else {
        result.writeCharCode(rune);
      }
    }
    return result.toString();
  }
}

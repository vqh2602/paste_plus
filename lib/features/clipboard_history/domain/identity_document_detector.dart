class IdentityDocumentDetector {
  const IdentityDocumentDetector._();

  static const Set<String> _vietnameseProvinceCodes = {
    '001',
    '002',
    '004',
    '006',
    '008',
    '010',
    '011',
    '012',
    '014',
    '015',
    '017',
    '019',
    '020',
    '022',
    '024',
    '025',
    '026',
    '027',
    '030',
    '031',
    '033',
    '034',
    '035',
    '036',
    '037',
    '038',
    '040',
    '042',
    '044',
    '045',
    '046',
    '048',
    '049',
    '051',
    '052',
    '054',
    '056',
    '058',
    '060',
    '062',
    '064',
    '066',
    '067',
    '068',
    '070',
    '072',
    '074',
    '075',
    '077',
    '079',
    '080',
    '082',
    '083',
    '084',
    '086',
    '087',
    '089',
    '091',
    '092',
    '093',
    '094',
    '095',
    '096',
  };

  static const Set<String> _chineseProvinceCodes = {
    '11',
    '12',
    '13',
    '14',
    '15',
    '21',
    '22',
    '23',
    '31',
    '32',
    '33',
    '34',
    '35',
    '36',
    '37',
    '41',
    '42',
    '43',
    '44',
    '45',
    '46',
    '50',
    '51',
    '52',
    '53',
    '54',
    '61',
    '62',
    '63',
    '64',
    '65',
    '71',
    '81',
    '82',
  };

  static const List<int> _chineseIdentityWeights = [
    7,
    9,
    10,
    5,
    8,
    4,
    2,
    1,
    6,
    3,
    7,
    9,
    10,
    5,
    8,
    4,
    2,
  ];
  static const List<String> _chineseIdentityChecks = [
    '1',
    '0',
    'X',
    '9',
    '8',
    '7',
    '6',
    '5',
    '4',
    '3',
    '2',
  ];

  static const List<List<int>> _verhoeffProducts = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
  ];
  static const List<List<int>> _verhoeffPermutations = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
    [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
  ];

  static final RegExp _labeledDocument = RegExp(
    r"(?:cmnd|cccd|căn\s*cước(?:\s*công\s*dân)?|chứng\s*minh(?:\s*nhân\s*dân)?|số\s*định\s*danh(?:\s*cá\s*nhân)?|mã\s*định\s*danh|identity\s*(?:card|number|id)|national\s*id|citizen\s*id|social\s*security\s*(?:number|no\.?|id)|ssn|passport|hộ\s*chiếu|aadhaar|nric|fin|resident\s*registration\s*(?:number|no\.?|id)|dni|nie|身份证|身分證|公民身份号码|护照|護照|マイナンバー|個人番号|パスポート|주민등록번호|주민등록증|여권|personalausweis(?:nummer)?|reisepass|carte\s+(?:nationale\s+)?d['’]identité|passeport|documento\s+nacional\s+de\s+identidad|pasaporte|carta\s+d['’]identità|passaporto|documento\s+de\s+identidade|passaporte)\s*(?:(?:number|no\.?|nr\.?|nº|số|号码|號碼|番号|번호)\s*)?[:#-]?\s*([a-z0-9]{6,20}|[a-z0-9]{1,5}(?:[ -][a-z0-9]{1,6}){1,4})(?![a-z0-9])",
    caseSensitive: false,
    unicode: true,
  );

  static bool contains(String value) {
    final normalized = value.replaceAll('\r\n', '\n').trim();
    if (_containsLabeledDocument(normalized) || _isPassportMrz(normalized)) {
      return true;
    }
    if (!RegExp(r'^[a-z0-9 -]+$', caseSensitive: false).hasMatch(normalized)) {
      return false;
    }

    final compact = normalized.replaceAll(RegExp(r'[ -]'), '').toUpperCase();
    return _isVietnameseCitizenId(compact) ||
        _isChineseCitizenId(compact) ||
        _isIndianAadhaar(compact) ||
        _isJapaneseMyNumber(compact) ||
        _isThaiNationalId(compact) ||
        _isSingaporeNricOrFin(compact) ||
        _isTaiwanNationalId(compact) ||
        _isSpanishDniOrNie(compact) ||
        _isUnitedStatesSsn(normalized) ||
        _isKoreanResidentNumber(normalized);
  }

  static bool _containsLabeledDocument(String value) {
    for (final match in _labeledDocument.allMatches(value)) {
      final candidate = match.group(1)!;
      final compact = candidate.replaceAll(RegExp(r'[ -]'), '');
      if (compact.length >= 6 &&
          compact.length <= 20 &&
          RegExp(r'\d').hasMatch(compact)) {
        return true;
      }
    }
    return false;
  }

  static bool _isPassportMrz(String value) {
    final lines = value
        .split('\n')
        .map((line) => line.trim().toUpperCase())
        .toList(growable: false);
    return lines.length == 2 &&
        RegExp(r'^P[A-Z<][A-Z]{3}[A-Z<]{39}$').hasMatch(lines.first) &&
        RegExp(r'^[A-Z0-9<]{44}$').hasMatch(lines.last);
  }

  static bool _isVietnameseCitizenId(String value) =>
      RegExp(r'^\d{12}$').hasMatch(value) &&
      _vietnameseProvinceCodes.contains(value.substring(0, 3));

  static bool _isChineseCitizenId(String value) {
    if (!RegExp(r'^\d{17}[\dX]$').hasMatch(value) ||
        !_chineseProvinceCodes.contains(value.substring(0, 2)) ||
        value.substring(14, 17) == '000' ||
        !_isDate(value.substring(6, 14), yearDigits: 4)) {
      return false;
    }
    var sum = 0;
    for (var index = 0; index < 17; index++) {
      sum += _digit(value, index) * _chineseIdentityWeights[index];
    }
    return value[17] == _chineseIdentityChecks[sum % 11];
  }

  static bool _isIndianAadhaar(String value) {
    if (!RegExp(r'^[2-9]\d{11}$').hasMatch(value)) return false;
    var checksum = 0;
    final reversed = value.split('').reversed;
    var index = 0;
    for (final character in reversed) {
      final digit = character.codeUnitAt(0) - 0x30;
      checksum =
          _verhoeffProducts[checksum][_verhoeffPermutations[index % 8][digit]];
      index++;
    }
    return checksum == 0;
  }

  static bool _isJapaneseMyNumber(String value) {
    if (!RegExp(r'^\d{12}$').hasMatch(value)) return false;
    const weights = [6, 5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
    var sum = 0;
    for (var index = 0; index < 11; index++) {
      sum += _digit(value, index) * weights[index];
    }
    final remainder = sum % 11;
    final expected = remainder <= 1 ? 0 : 11 - remainder;
    return _digit(value, 11) == expected;
  }

  static bool _isThaiNationalId(String value) {
    if (!RegExp(r'^\d{13}$').hasMatch(value)) return false;
    var sum = 0;
    for (var index = 0; index < 12; index++) {
      sum += _digit(value, index) * (13 - index);
    }
    return _digit(value, 12) == (11 - (sum % 11)) % 10;
  }

  static bool _isSingaporeNricOrFin(String value) {
    if (!RegExp(r'^[STFGM]\d{7}[A-Z]$').hasMatch(value)) return false;
    const weights = [2, 7, 6, 5, 4, 3, 2];
    var sum = 0;
    for (var index = 0; index < 7; index++) {
      sum += _digit(value, index + 1) * weights[index];
    }
    final prefix = value[0];
    if (prefix == 'T' || prefix == 'G') sum += 4;
    if (prefix == 'M') sum += 3;
    final checks = prefix == 'S' || prefix == 'T'
        ? 'JZIHGFEDCBA'
        : 'XWUTRQPNMLK';
    return value[8] == checks[sum % 11];
  }

  static bool _isTaiwanNationalId(String value) {
    if (!RegExp(r'^[A-Z][12]\d{8}$').hasMatch(value)) return false;
    const letterCodes = {
      'A': 10,
      'B': 11,
      'C': 12,
      'D': 13,
      'E': 14,
      'F': 15,
      'G': 16,
      'H': 17,
      'J': 18,
      'K': 19,
      'L': 20,
      'M': 21,
      'N': 22,
      'P': 23,
      'Q': 24,
      'R': 25,
      'S': 26,
      'T': 27,
      'U': 28,
      'V': 29,
      'X': 30,
      'Y': 31,
      'W': 32,
      'Z': 33,
      'I': 34,
      'O': 35,
    };
    final code = letterCodes[value[0]]!;
    var sum = code ~/ 10 + (code % 10) * 9;
    for (var index = 1; index <= 8; index++) {
      sum += _digit(value, index) * (9 - index);
    }
    sum += _digit(value, 9);
    return sum % 10 == 0;
  }

  static bool _isSpanishDniOrNie(String value) {
    const checkLetters = 'TRWAGMYFPDXBNJZSQVHLCKE';
    final dni = RegExp(r'^(\d{8})([A-Z])$').firstMatch(value);
    if (dni != null) {
      return dni.group(2) == checkLetters[int.parse(dni.group(1)!) % 23];
    }
    final nie = RegExp(r'^([XYZ])(\d{7})([A-Z])$').firstMatch(value);
    if (nie == null) return false;
    final prefix = const {'X': '0', 'Y': '1', 'Z': '2'}[nie.group(1)]!;
    final number = int.parse('$prefix${nie.group(2)}');
    return nie.group(3) == checkLetters[number % 23];
  }

  static bool _isKoreanResidentNumber(String value) {
    final match = RegExp(r'^(\d{6})-([1-8])\d{6}$').firstMatch(value);
    if (match == null) return false;
    final century = switch (match.group(2)) {
      '1' || '2' || '5' || '6' => 1900,
      _ => 2000,
    };
    return _isDate(match.group(1)!, yearDigits: 2, century: century);
  }

  static bool _isUnitedStatesSsn(String value) {
    final match = RegExp(r'^(\d{3})-(\d{2})-(\d{4})$').firstMatch(value);
    if (match == null) return false;
    final area = int.parse(match.group(1)!);
    final group = int.parse(match.group(2)!);
    final serial = int.parse(match.group(3)!);
    return area != 0 && area != 666 && area < 900 && group != 0 && serial != 0;
  }

  static bool _isDate(
    String value, {
    required int yearDigits,
    int century = 0,
  }) {
    final year = century + int.parse(value.substring(0, yearDigits));
    final month = int.parse(value.substring(yearDigits, yearDigits + 2));
    final day = int.parse(value.substring(yearDigits + 2, yearDigits + 4));
    if (year < 1800 || year > DateTime.now().year || month < 1 || day < 1) {
      return false;
    }
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day;
  }

  static int _digit(String value, int index) => value.codeUnitAt(index) - 0x30;
}

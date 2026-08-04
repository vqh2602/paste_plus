import 'package:flutter/widgets.dart';

class AiLocaleSpec {
  const AiLocaleSpec({
    required this.tag,
    required this.englishName,
    required this.nativeName,
    required this.textDirection,
  });

  final String tag;
  final String englishName;
  final String nativeName;
  final TextDirection textDirection;

  Locale get locale {
    final parts = tag.split('-');
    if (parts.length == 1) return Locale(parts.first);
    if (parts.length == 2) {
      final second = parts[1];
      return second.length == 4
          ? Locale.fromSubtags(languageCode: parts[0], scriptCode: second)
          : Locale(parts[0], second);
    }
    return Locale.fromSubtags(
      languageCode: parts[0],
      scriptCode: parts[1],
      countryCode: parts[2],
    );
  }
}

abstract final class AiLanguageRegistry {
  static const fallbackTag = 'en-US';

  static const languages = <String, AiLocaleSpec>{
    'vi-VN': AiLocaleSpec(
      tag: 'vi-VN',
      englishName: 'Vietnamese',
      nativeName: 'Tiếng Việt',
      textDirection: TextDirection.ltr,
    ),
    'en-US': AiLocaleSpec(
      tag: 'en-US',
      englishName: 'English',
      nativeName: 'English',
      textDirection: TextDirection.ltr,
    ),
    'ja-JP': AiLocaleSpec(
      tag: 'ja-JP',
      englishName: 'Japanese',
      nativeName: '日本語',
      textDirection: TextDirection.ltr,
    ),
    'ko-KR': AiLocaleSpec(
      tag: 'ko-KR',
      englishName: 'Korean',
      nativeName: '한국어',
      textDirection: TextDirection.ltr,
    ),
    'zh-Hans-CN': AiLocaleSpec(
      tag: 'zh-Hans-CN',
      englishName: 'Simplified Chinese',
      nativeName: '简体中文',
      textDirection: TextDirection.ltr,
    ),
    'de-DE': AiLocaleSpec(
      tag: 'de-DE',
      englishName: 'German',
      nativeName: 'Deutsch',
      textDirection: TextDirection.ltr,
    ),
    'ar-SA': AiLocaleSpec(
      tag: 'ar-SA',
      englishName: 'Arabic',
      nativeName: 'العربية',
      textDirection: TextDirection.rtl,
    ),
  };

  static AiLocaleSpec resolve(String? tag) {
    final normalized = normalizeTag(tag);
    return languages[normalized] ?? languages[fallbackTag]!;
  }

  static String normalizeTag(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return fallbackTag;
    const aliases = {
      'vi': 'vi-VN',
      'Vietnamese': 'vi-VN',
      'en': 'en-US',
      'English': 'en-US',
      'ja': 'ja-JP',
      'Japanese': 'ja-JP',
      'ko': 'ko-KR',
      'Korean': 'ko-KR',
      'de': 'de-DE',
      'German': 'de-DE',
    };
    return aliases[raw] ?? raw;
  }
}

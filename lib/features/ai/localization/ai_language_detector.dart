abstract interface class AiLanguageDetector {
  Future<String?> detect(String text);
}

String? detectLanguageByScript(String text) {
  if (RegExp(r'[\u3040-\u30ff]').hasMatch(text)) return 'ja-JP';
  if (RegExp(r'[\uac00-\ud7af]').hasMatch(text)) return 'ko-KR';
  if (RegExp(r'[\u0600-\u06ff]').hasMatch(text)) return 'ar-SA';
  if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) return 'zh-Hans-CN';
  return null;
}

class CallbackAiLanguageDetector implements AiLanguageDetector {
  const CallbackAiLanguageDetector(this._detect);

  final Future<String?> Function(String text) _detect;

  @override
  Future<String?> detect(String text) => _detect(text);
}

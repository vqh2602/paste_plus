abstract interface class AiLanguageDetector {
  Future<String?> detect(String text);
}

class CallbackAiLanguageDetector implements AiLanguageDetector {
  const CallbackAiLanguageDetector(this._detect);

  final Future<String?> Function(String text) _detect;

  @override
  Future<String?> detect(String text) => _detect(text);
}

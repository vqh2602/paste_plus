class TranslationService {
  const TranslationService();

  /// Translate text into [targetLanguage] (e.g. 'vi', 'en', 'ja', 'zh-CN', etc.)
  Future<String?> translate({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'auto',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    // Network translation was intentionally removed. Translation is handled
    // by the selected local GGUF model through the AI feature pipeline.
    return null;
  }
}

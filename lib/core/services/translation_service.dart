import 'dart:convert';
import 'dart:io';

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

    try {
      final client = HttpClient();
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sourceLanguage&tl=$targetLanguage&dt=t&q=${Uri.encodeComponent(trimmed)}',
      );

      final request = await client.getUrl(url);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );

      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return null;
      }

      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      final dynamic parsed = jsonDecode(responseBody);
      if (parsed is List && parsed.isNotEmpty && parsed[0] is List) {
        final List<dynamic> segments = parsed[0] as List<dynamic>;
        final buffer = StringBuffer();
        for (final segment in segments) {
          if (segment is List && segment.isNotEmpty && segment[0] is String) {
            buffer.write(segment[0]);
          }
        }
        final resultText = buffer.toString().trim();
        return resultText.isEmpty ? null : resultText;
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}

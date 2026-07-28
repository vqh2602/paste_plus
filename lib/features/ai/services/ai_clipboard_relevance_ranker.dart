import '../../clipboard_history/domain/clipboard_content_type.dart';
import '../../clipboard_history/domain/clipboard_item.dart';

class AiClipboardRelevanceRanker {
  const AiClipboardRelevanceRanker();

  bool hasExactFileConstraint(String prompt) {
    final normalized = _normalize(prompt);
    return _imageExtensions.any(
      (extension) => RegExp(
        '(^|[^a-z0-9])${extension.substring(1)}([^a-z0-9]|\$)',
      ).hasMatch(normalized),
    );
  }

  List<ClipboardItem> rank({
    required String prompt,
    required Iterable<ClipboardItem> items,
    Map<String, double> semanticScores = const {},
  }) {
    final normalizedPrompt = _normalize(prompt);
    final queryTerms = _terms(
      normalizedPrompt,
    ).where((term) => !_stopWords.contains(term));
    final uniqueTerms = queryTerms.toSet();
    final asksForLink = _containsAny(normalizedPrompt, const {
      'link',
      'url',
      'đường dẫn',
      'duong dan',
    });
    final asksForImage = _containsAny(normalizedPrompt, const {
      'ảnh',
      'anh',
      'image',
      'photo',
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
    });
    final requestedExtensions = _imageExtensions
        .where((extension) => normalizedPrompt.contains(extension.substring(1)))
        .toSet();

    final ranked = <({ClipboardItem item, double score, int order})>[];
    var order = 0;
    for (final item in items) {
      final content = item.content.trim();
      if (content.isEmpty || item.isSensitive) continue;
      final normalizedContent = _normalize(content);
      if (normalizedContent == normalizedPrompt) continue;

      var lexicalScore = 0.0;
      for (final term in uniqueTerms) {
        if (normalizedContent.contains(term)) lexicalScore += 2.5;
      }
      final looksLikeUrl =
          item.contentType == ClipboardContentType.url ||
          RegExp(r'https?://', caseSensitive: false).hasMatch(content);
      final lowerContent = content.toLowerCase();
      final isImageUrl =
          looksLikeUrl &&
          _imageExtensions.any((extension) => lowerContent.contains(extension));

      if (asksForLink && looksLikeUrl) lexicalScore += 7;
      if (asksForImage && item.contentType == ClipboardContentType.image) {
        lexicalScore += 3;
      }
      if (asksForImage && isImageUrl) lexicalScore += 9;
      for (final extension in requestedExtensions) {
        if (lowerContent.contains(extension)) lexicalScore += 8;
      }

      final semanticScore = semanticScores[item.id] ?? 0;
      final pinnedBoost = item.isPinned ? 0.8 : 0.0;
      final age = DateTime.now().difference(item.lastCopiedAt);
      final recencyBoost = age.inDays <= 7 ? 0.35 : 0.0;
      ranked.add((
        item: item,
        score: lexicalScore + semanticScore * 2 + pinnedBoost + recencyBoost,
        order: order++,
      ));
    }

    ranked.sort((left, right) {
      final scoreComparison = right.score.compareTo(left.score);
      return scoreComparison != 0
          ? scoreComparison
          : left.order.compareTo(right.order);
    });
    return ranked.map((entry) => entry.item).toList(growable: false);
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  Iterable<String> _terms(String value) => value
      .split(RegExp(r'[^\p{L}\p{N}.]+', unicode: true))
      .where((term) => term.length > 1);

  bool _containsAny(String value, Set<String> terms) =>
      terms.any(value.contains);

  static const _imageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.heic',
    '.avif',
  };

  static const _stopWords = {
    'tìm',
    'tim',
    'cho',
    'tôi',
    'toi',
    'các',
    'cac',
    'bản',
    'ban',
    'ghi',
    'về',
    've',
    'trong',
    'clipboard',
    'hãy',
    'hay',
    'find',
    'search',
    'for',
    'the',
    'records',
    'items',
    'please',
  };
}

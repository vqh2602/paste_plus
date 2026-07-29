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
      'liên kết',
      'lien ket',
      'hyperlink',
      'http',
      'https',
    });
    final asksForImage = _containsAny(normalizedPrompt, const {
      'ảnh',
      'anh',
      'image',
      'photo',
      'picture',
      'hình',
      'hinh',
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'svg',
      'heic',
      'avif',
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

      final isUrlType = item.contentType == ClipboardContentType.url;
      final containsHttpUrl =
          RegExp(r'https?://', caseSensitive: false).hasMatch(content);
      // final looksLikeUrl = isUrlType || containsHttpUrl;
      final imageLink = isImageUrl(content);

      if (asksForLink) {
        if (isUrlType) {
          lexicalScore += 15.0;
        } else if (containsHttpUrl) {
          lexicalScore += 3.0;
        }
      }

      if (asksForImage) {
        if (item.contentType == ClipboardContentType.image) {
          lexicalScore += 12.0;
        }
      }

      if (asksForLink && asksForImage) {
        if (isUrlType && imageLink) {
          lexicalScore += 20.0;
        } else if (imageLink) {
          lexicalScore += 8.0;
        }
      } else if (asksForImage && imageLink) {
        lexicalScore += 12.0;
      }

      for (final extension in requestedExtensions) {
        if (normalizedContent.contains(extension.substring(1))) {
          lexicalScore += 10.0;
        }
      }

      final isLogMetadata = normalizedContent.contains('mục clipboard') ||
          normalizedContent.contains('clipbroad') ||
          normalizedContent.contains('phân tích nội dung clipboard');
      if (isLogMetadata) {
        lexicalScore -= 15.0;
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

  bool isImageUrl(String content) {
    final lower = content.toLowerCase().trim();
    final looksLikeUrl =
        RegExp(r'https?://', caseSensitive: false).hasMatch(lower);
    if (!looksLikeUrl) return false;

    final hasImageExt =
        _imageExtensions.any((ext) => lower.contains(ext));
    final hasImageDomain =
        _imageHostDomains.any((domain) => lower.contains(domain));
    return hasImageExt || hasImageDomain;
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
    '.svg',
    '.heic',
    '.avif',
  };

  static const _imageHostDomains = {
    'iili.io',
    'freeimage.host',
    'imgur.com',
    'gyazo.com',
    'cloudinary.com',
    'unsplash.com',
    'postimg.cc',
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

import 'dart:convert';

class UrlPreviewMetadata {
  const UrlPreviewMetadata({
    required this.resolvedUrl,
    required this.fetchedAt,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });

  static const metadataKey = 'urlPreview';

  final String resolvedUrl;
  final DateTime fetchedAt;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  bool get hasRichContent =>
      title?.isNotEmpty == true ||
      description?.isNotEmpty == true ||
      imageUrl?.isNotEmpty == true;

  bool isFresh(DateTime now, {Duration maxAge = const Duration(days: 7)}) {
    return now.difference(fetchedAt) < maxAge;
  }

  String displayTitle(Uri fallbackUri) {
    final pageTitle = title?.trim();
    final site = siteName?.trim();
    if (pageTitle?.isNotEmpty == true) {
      if (site?.isNotEmpty == true &&
          !pageTitle!.toLowerCase().contains(site!.toLowerCase())) {
        return '$pageTitle | $site';
      }
      return pageTitle!;
    }
    if (site?.isNotEmpty == true) return site!;
    return fallbackUri.host.replaceFirst(RegExp(r'^www\.'), '');
  }

  UrlPreviewMetadata copyWith({String? imageUrl, bool clearImage = false}) {
    return UrlPreviewMetadata(
      resolvedUrl: resolvedUrl,
      fetchedAt: fetchedAt,
      title: title,
      description: description,
      imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
      siteName: siteName,
    );
  }

  Map<String, Object?> toMap() => {
    'resolvedUrl': resolvedUrl,
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    if (title != null) 'title': title,
    if (description != null) 'description': description,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (siteName != null) 'siteName': siteName,
  };

  factory UrlPreviewMetadata.fromMap(Map<String, dynamic> map) {
    return UrlPreviewMetadata(
      resolvedUrl: map['resolvedUrl']?.toString() ?? '',
      fetchedAt:
          DateTime.tryParse(map['fetchedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      title: _optionalString(map['title']),
      description: _optionalString(map['description']),
      imageUrl: _optionalString(map['imageUrl']),
      siteName: _optionalString(map['siteName']),
    );
  }

  static UrlPreviewMetadata? fromClipboardMetadata(String? metadataJson) {
    if (metadataJson == null || metadataJson.trim().isEmpty) return null;
    try {
      final root = jsonDecode(metadataJson);
      if (root is! Map<String, dynamic>) return null;
      final preview = root[metadataKey];
      if (preview is! Map) return null;
      return UrlPreviewMetadata.fromMap(
        preview.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on Object {
      return null;
    }
  }

  String mergeIntoClipboardMetadata(String? metadataJson) {
    Map<String, dynamic> root = {};
    try {
      final decoded = metadataJson?.trim().isNotEmpty == true
          ? jsonDecode(metadataJson!)
          : null;
      if (decoded is Map<String, dynamic>) root = Map.of(decoded);
    } on Object {
      root = {};
    }
    root[metadataKey] = toMap();
    return jsonEncode(root);
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

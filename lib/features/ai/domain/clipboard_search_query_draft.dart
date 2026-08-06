class ClipboardSearchQueryDraft {
  const ClipboardSearchQueryDraft({
    required this.contentTypes,
    required this.containsUrl,
    required this.urlHosts,
    required this.urlKind,
    required this.textQuery,
    required this.sourceApps,
    required this.fileExtensions,
    required this.datePreset,
    required this.pinned,
    required this.sort,
    required this.limit,
    required this.confidence,
  });

  final List<String> contentTypes;
  final bool? containsUrl;
  final List<String> urlHosts;
  final String? urlKind;
  final String? textQuery;
  final List<String> sourceApps;
  final List<String> fileExtensions;
  final String? datePreset;
  final bool? pinned;
  final String sort;
  final int limit;
  final double confidence;

  ClipboardSearchQueryDraft copyWithLimit(int value) =>
      ClipboardSearchQueryDraft(
        contentTypes: contentTypes,
        containsUrl: containsUrl,
        urlHosts: urlHosts,
        urlKind: urlKind,
        textQuery: textQuery,
        sourceApps: sourceApps,
        fileExtensions: fileExtensions,
        datePreset: datePreset,
        pinned: pinned,
        sort: sort,
        limit: value,
        confidence: confidence,
      );

  factory ClipboardSearchQueryDraft.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) => value is List
        ? value.map((item) => item.toString()).toList(growable: false)
        : const [];
    return ClipboardSearchQueryDraft(
      contentTypes: strings(json['content_types']),
      containsUrl: json['contains_url'] as bool?,
      urlHosts: strings(json['url_hosts']),
      urlKind: json['url_kind']?.toString(),
      textQuery: json['text_query']?.toString(),
      sourceApps: strings(json['source_apps']),
      fileExtensions: strings(json['file_extensions']),
      datePreset: json['date_preset']?.toString(),
      pinned: json['pinned'] as bool?,
      sort: json['sort']?.toString() ?? 'newest',
      limit: (json['limit'] as num?)?.toInt() ?? 30,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}

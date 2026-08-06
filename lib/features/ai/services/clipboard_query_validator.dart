import '../../clipboard_history/domain/clipboard_content_type.dart';
import '../../clipboard_history/domain/search_query.dart';
import '../domain/clipboard_search_query_draft.dart';

class ClipboardQueryValidator {
  const ClipboardQueryValidator();

  ClipboardSearchQuery validate({
    required ClipboardSearchQueryDraft draft,
    required DateTime now,
  }) {
    final types = <ClipboardContentType>{};
    for (final value in draft.contentTypes) {
      final normalized = value.trim().toLowerCase();
      for (final type in ClipboardContentType.values) {
        if (type.name == normalized) types.add(type);
      }
    }
    final hosts = draft.urlHosts
        .map(_normalizeHost)
        .where((host) => host.isNotEmpty)
        .toSet();
    final extensions = draft.fileExtensions
        .map((value) => value.trim().toLowerCase().replaceFirst(RegExp(r'^\.'), ''))
        .where((value) => RegExp(r'^[a-z0-9]{1,10}$').hasMatch(value))
        .toSet();
    final query = ClipboardSearchQuery(
      contentTypes: types,
      textQuery: _normalizedText(draft.textQuery),
      containsUrl: draft.containsUrl,
      urlHosts: hosts,
      urlKind: _urlKind(draft.urlKind),
      sourceApps: draft.sourceApps
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet(),
      fileExtensions: extensions,
      pinned: draft.pinned,
      dateRange: draft.datePreset == null
          ? null
          : ClipboardDateRange(preset: draft.datePreset).resolve(now),
      sort: _sort(draft.sort),
      limit: draft.limit.clamp(1, 100),
      includeSensitive: false,
    );
    return repairQuery(query);
  }

  ClipboardSearchQuery repairQuery(ClipboardSearchQuery query) {
    if (query.contentTypes.contains(ClipboardContentType.url) ||
        query.urlHosts.isNotEmpty || query.urlKind != null) {
      return query.copyWith(containsUrl: true);
    }
    return query;
  }

  String _normalizeHost(String value) {
    var host = value.trim().toLowerCase();
    final uri = Uri.tryParse(host.contains('://') ? host : 'https://$host');
    host = uri?.host ?? host;
    return host.replaceFirst(RegExp(r'^www\.'), '').replaceAll(RegExp(r'[^a-z0-9.-]'), '');
  }

  String? _normalizedText(String? value) {
    final text = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text == null || text.isEmpty ? null : text;
  }

  ClipboardUrlKind? _urlKind(String? value) => switch (value) {
    'any' => ClipboardUrlKind.any,
    'web_page' || 'webPage' => ClipboardUrlKind.webPage,
    'image' => ClipboardUrlKind.image,
    'video' => ClipboardUrlKind.video,
    'download' => ClipboardUrlKind.download,
    'repository' => ClipboardUrlKind.repository,
    _ => null,
  };

  ClipboardSort _sort(String value) => switch (value) {
    'oldest' => ClipboardSort.oldest,
    'most_copied' || 'mostCopied' => ClipboardSort.mostCopied,
    'recently_copied' || 'recentlyCopied' => ClipboardSort.recentlyCopied,
    _ => ClipboardSort.newest,
  };
}

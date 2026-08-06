import 'clipboard_content_type.dart';
import 'clipboard_item.dart';

enum ClipboardSort { newest, oldest, mostCopied, recentlyCopied }

enum ClipboardUrlKind { any, webPage, image, video, download, repository }

class ClipboardDateRange {
  const ClipboardDateRange({this.from, this.to, this.preset});

  final DateTime? from;
  final DateTime? to;
  final String? preset;

  ClipboardDateRange resolve(DateTime now) {
    if (from != null || to != null || preset == null) return this;
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    return switch (preset) {
      'today' => ClipboardDateRange(from: today, to: today.add(const Duration(days: 1))),
      'yesterday' => ClipboardDateRange(
          from: today.subtract(const Duration(days: 1)),
          to: today,
        ),
      'last_7_days' => ClipboardDateRange(
          from: today.subtract(const Duration(days: 7)),
          to: today.add(const Duration(days: 1)),
        ),
      'last_30_days' => ClipboardDateRange(
          from: today.subtract(const Duration(days: 30)),
          to: today.add(const Duration(days: 1)),
        ),
      _ => this,
    };
  }
}

/// Typed query used by the deep clipboard agent.
///
/// [parse] and [matches] remain as compatibility helpers for the history
/// screen's compact search syntax.
class ClipboardSearchQuery {
  const ClipboardSearchQuery({
    this.contentTypes = const {},
    this.textQuery,
    this.containsUrl,
    this.urlHosts = const {},
    this.urlKind,
    this.sourceApps = const {},
    this.fileExtensions = const {},
    this.pinned,
    this.collectionIds = const {},
    this.dateRange,
    this.sort = ClipboardSort.newest,
    this.limit = 30,
    this.offset = 0,
    this.includeSensitive = false,
    this.terms = const [],
    this.type,
    this.pinnedOnly = false,
    this.sourceApp,
    this.after,
    this.noteQuery,
  });

  final Set<ClipboardContentType> contentTypes;
  final String? textQuery;
  final bool? containsUrl;
  final Set<String> urlHosts;
  final ClipboardUrlKind? urlKind;
  final Set<String> sourceApps;
  final Set<String> fileExtensions;
  final bool? pinned;
  final Set<String> collectionIds;
  final ClipboardDateRange? dateRange;
  final ClipboardSort sort;
  final int limit;
  final int offset;
  final bool includeSensitive;

  // Legacy history-filter fields.
  final List<String> terms;
  final ClipboardContentType? type;
  final bool pinnedOnly;
  final String? sourceApp;
  final DateTime? after;
  final String? noteQuery;

  ClipboardSearchQuery copyWith({
    Set<ClipboardContentType>? contentTypes,
    String? textQuery,
    bool clearTextQuery = false,
    bool? containsUrl,
    Set<String>? urlHosts,
    ClipboardUrlKind? urlKind,
    Set<String>? sourceApps,
    Set<String>? fileExtensions,
    bool? pinned,
    Set<String>? collectionIds,
    ClipboardDateRange? dateRange,
    ClipboardSort? sort,
    int? limit,
    int? offset,
    bool? includeSensitive,
  }) {
    return ClipboardSearchQuery(
      contentTypes: contentTypes ?? this.contentTypes,
      textQuery: clearTextQuery ? null : (textQuery ?? this.textQuery),
      containsUrl: containsUrl ?? this.containsUrl,
      urlHosts: urlHosts ?? this.urlHosts,
      urlKind: urlKind ?? this.urlKind,
      sourceApps: sourceApps ?? this.sourceApps,
      fileExtensions: fileExtensions ?? this.fileExtensions,
      pinned: pinned ?? this.pinned,
      collectionIds: collectionIds ?? this.collectionIds,
      dateRange: dateRange ?? this.dateRange,
      sort: sort ?? this.sort,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      includeSensitive: includeSensitive ?? this.includeSensitive,
      terms: terms,
      type: type,
      pinnedOnly: pinnedOnly,
      sourceApp: sourceApp,
      after: after,
      noteQuery: noteQuery,
    );
  }

  factory ClipboardSearchQuery.parse(String raw) {
    ClipboardContentType? type;
    var pinnedOnly = false;
    String? sourceApp;
    DateTime? after;
    String? noteQuery;
    final terms = <String>[];

    final trimmed = raw.trim();
    final noteMatch = RegExp(
      r'\bnote:\s*(?:"([^"]*)"|(\S+))',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (noteMatch != null) {
      noteQuery = (noteMatch.group(1) ?? noteMatch.group(2) ?? '').toLowerCase();
    } else if (RegExp(r'\bnote:\s*$', caseSensitive: false).hasMatch(trimmed)) {
      noteQuery = '';
    }

    final sanitizedRaw = trimmed.replaceAll(
      RegExp(r'\bnote:\s*(?:"[^"]*"|\S+)?', caseSensitive: false),
      '',
    );
    for (final token in sanitizedRaw.trim().split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final parts = token.split(':');
      if (parts.length == 2) {
        switch (parts.first.toLowerCase()) {
          case 'type':
            type = ClipboardContentType.values
                .where((item) => item.name == parts.last.toLowerCase())
                .firstOrNull;
          case 'is':
            pinnedOnly = parts.last.toLowerCase() == 'pinned';
          case 'app':
            sourceApp = parts.last.toLowerCase();
          case 'after':
            after = DateTime.tryParse(parts.last);
          default:
            terms.add(token.toLowerCase());
        }
      } else {
        terms.add(token.toLowerCase());
      }
    }
    return ClipboardSearchQuery(
      terms: terms,
      type: type,
      pinnedOnly: pinnedOnly,
      sourceApp: sourceApp,
      after: after,
      noteQuery: noteQuery,
    );
  }

  bool matches(ClipboardItem item) {
    if (type != null && item.contentType != type) return false;
    if (pinnedOnly && !item.isPinned) return false;
    if (sourceApp != null &&
        !(item.sourceAppName ?? '').toLowerCase().contains(sourceApp!)) {
      return false;
    }
    if (after != null && item.lastCopiedAt.isBefore(after!)) return false;
    if (noteQuery != null) {
      if (noteQuery!.isEmpty) {
        if (item.note == null || item.note!.trim().isEmpty) return false;
      } else if (item.note == null ||
          !item.note!.toLowerCase().contains(noteQuery!)) {
        return false;
      }
    }
    final haystack =
        '${item.content} ${item.sourceAppName ?? ''} ${item.note ?? ''}'
            .toLowerCase();
    return terms.every(haystack.contains);
  }

  Map<String, dynamic> toJson() => {
        'content_types': contentTypes.map((value) => value.name).toList(),
        'text_query': textQuery,
        'contains_url': containsUrl,
        'url_hosts': urlHosts.toList(),
        'url_kind': urlKind?.name,
        'source_apps': sourceApps.toList(),
        'file_extensions': fileExtensions.toList(),
        'pinned': pinned,
        'collection_ids': collectionIds.toList(),
        'date_preset': dateRange?.preset,
        'from': dateRange?.from?.toIso8601String(),
        'to': dateRange?.to?.toIso8601String(),
        'sort': sort.name,
        'limit': limit,
        'offset': offset,
        'include_sensitive': includeSensitive,
      };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

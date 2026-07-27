import 'clipboard_content_type.dart';
import 'clipboard_item.dart';

class ClipboardSearchQuery {
  ClipboardSearchQuery._({
    required this.terms,
    this.type,
    this.pinnedOnly = false,
    this.sourceApp,
    this.after,
  });

  final List<String> terms;
  final ClipboardContentType? type;
  final bool pinnedOnly;
  final String? sourceApp;
  final DateTime? after;

  factory ClipboardSearchQuery.parse(String raw) {
    ClipboardContentType? type;
    var pinnedOnly = false;
    String? sourceApp;
    DateTime? after;
    final terms = <String>[];

    for (final token in raw.trim().split(RegExp(r'\s+'))) {
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
    return ClipboardSearchQuery._(
      terms: terms,
      type: type,
      pinnedOnly: pinnedOnly,
      sourceApp: sourceApp,
      after: after,
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
    final haystack = '${item.content} ${item.sourceAppName ?? ''}'
        .toLowerCase();
    return terms.every(haystack.contains);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

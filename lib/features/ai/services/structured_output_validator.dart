import 'dart:convert';

import '../../clipboard_history/domain/clipboard_item.dart';

class ClipboardSearchMatch {
  ClipboardSearchMatch({
    required this.clipId,
    required this.reason,
    required this.value,
  });

  final String clipId;
  final String reason;
  String value;

  Map<String, dynamic> toJson() => {
        'clip_id': clipId,
        'value': value,
        'reason': reason,
      };
}

class ClipboardSearchResponse {
  ClipboardSearchResponse({required this.matches});

  factory ClipboardSearchResponse.fromJson(Map<String, dynamic> json) {
    final matchesRaw = json['matches'];
    final matches = <ClipboardSearchMatch>[];

    if (matchesRaw is List) {
      for (final item in matchesRaw) {
        if (item is Map<String, dynamic>) {
          final clipId = (item['clip_id'] ?? item['clipId'] ?? '').toString().trim();
          final reason = (item['reason'] ?? '').toString().trim();
          final value = (item['value'] ?? '').toString();
          if (clipId.isNotEmpty) {
            matches.add(ClipboardSearchMatch(clipId: clipId, reason: reason, value: value));
          }
        } else if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final clipId = (map['clip_id'] ?? map['clipId'] ?? '').toString().trim();
          final reason = (map['reason'] ?? '').toString().trim();
          final value = (map['value'] ?? '').toString();
          if (clipId.isNotEmpty) {
            matches.add(ClipboardSearchMatch(clipId: clipId, reason: reason, value: value));
          }
        }
      }
    }

    return ClipboardSearchResponse(matches: matches);
  }

  final List<ClipboardSearchMatch> matches;

  Map<String, dynamic> toJson() => {
        'matches': matches.map((m) => m.toJson()).toList(),
      };
}

/// 3-Layer Validation Service: JSON extraction -> Schema Validation -> DB Ground-Truth Verifier.
class StructuredOutputValidator {
  const StructuredOutputValidator();

  /// GBNF JSON Schema grammar string enforcing strict ClipboardSearchResponse JSON syntax.
  static const searchJsonGrammar = '''
root ::= ClipboardSearchResponse
ClipboardSearchResponse ::= "{" ws "\\"matches\\":" ws "[" ws (Match ("," ws Match)*)? ws "]" ws "}"
Match ::= "{" ws "\\"clip_id\\":" ws String ws "," ws "\\"value\\":" ws String ws "," ws "\\"reason\\":" ws String ws "}"
String ::= "\\"" ([^"\\\\\\x00-\\x1F] | "\\\\" (["\\\\/bfnrt] | "u" [0-9a-fA-F]{4}))* "\\""
ws ::= [ \\t\\n\\r]*
''';

  /// Extracts valid JSON string from raw model output or markdown code fences.
  String extractJson(String rawText) {
    final trimmed = rawText.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start != -1 && end > start) {
      return trimmed.substring(start, end + 1);
    }
    return '{"matches":[]}';
  }

  /// Parses, validates, and enforces Database Ground-Truth verification on model outputs.
  ClipboardSearchResponse validateSearchOutput({
    required String rawOutput,
    required List<ClipboardItem> databaseCandidates,
  }) {
    final jsonStr = extractJson(rawOutput);
    Map<String, dynamic> decoded;

    try {
      final parsed = jsonDecode(jsonStr);
      decoded = parsed is Map<String, dynamic>
          ? parsed
          : (parsed is Map ? Map<String, dynamic>.from(parsed) : {'matches': []});
    } on Object {
      decoded = {'matches': []};
    }

    final parsedResponse = ClipboardSearchResponse.fromJson(decoded);
    final itemById = {for (final item in databaseCandidates) item.id: item};
    final verifiedMatches = <ClipboardSearchMatch>[];

    for (final match in parsedResponse.matches) {
      // 1. Business Check: Reject unknown / hallucinated clipboard IDs
      if (!itemById.containsKey(match.clipId)) {
        continue;
      }

      // 2. Ground-Truth Check: Enforce exact DB content for value field
      final originalItem = itemById[match.clipId]!;
      match.value = originalItem.content;

      verifiedMatches.add(match);
    }

    return ClipboardSearchResponse(matches: verifiedMatches);
  }
}

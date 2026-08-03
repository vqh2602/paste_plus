import 'dart:convert';

import '../../clipboard_history/domain/clipboard_item.dart';
import 'structured_output_validator.dart';

/// Report containing outcomes of the self-verification & correction step.
class VerificationReport {
  const VerificationReport({
    required this.isValid,
    required this.correctedText,
    this.issues = const [],
    this.citations = const [],
  });

  final bool isValid;
  final String correctedText;
  final List<String> issues;
  final List<String> citations;
}

/// Self-Verification & Correction Engine for ClipFlow AI responses.
class AiResponseVerifier {
  const AiResponseVerifier([
    this._jsonValidator = const StructuredOutputValidator(),
  ]);

  final StructuredOutputValidator _jsonValidator;

  /// Inspects [draftText] against [candidates] and returns clean [VerificationReport].
  VerificationReport verifyAndCorrect({
    required String draftText,
    required List<ClipboardItem> candidates,
    required String responseLanguage,
    bool requiresJson = false,
  }) {
    if (draftText.trim().isEmpty) {
      return const VerificationReport(
        isValid: true,
        correctedText: '',
      );
    }

    var text = draftText;
    final issues = <String>[];
    final citations = <String>[];
    final validIds = {for (final item in candidates) item.id};

    // 1. Verify and repair clip_id citations (e.g. [clip:id] or "clip_id": "id")
    final idRegex = RegExp(r'\[clip:([a-zA-Z0-9_\-]+)\]|"?clip_id"?\s*:\s*"([a-zA-Z0-9_\-]+)"', caseSensitive: false);

    text = text.replaceAllMapped(idRegex, (match) {
      final id = match.group(1) ?? match.group(2) ?? '';
      if (validIds.contains(id)) {
        if (!citations.contains(id)) {
          citations.add(id);
        }
        return match.group(1) != null ? '[clip:$id]' : '"clip_id": "$id"';
      }
      issues.add('Loại bỏ trích dẫn ID không tồn tại: $id');
      return '';
    });

    // 2. URL integrity check: restore truncated or mutilated URLs to DB verbatim content
    final candidateUrls = <String>{};
    for (final item in candidates) {
      final urlMatches = RegExp(r'https?://[^\s<>"]+').allMatches(item.content);
      for (final match in urlMatches) {
        candidateUrls.add(match.group(0)!);
      }
    }

    for (final trueUrl in candidateUrls) {
      final host = Uri.tryParse(trueUrl)?.host ?? '';
      if (host.isNotEmpty && text.contains(host) && !text.contains(trueUrl)) {
        final brokenRegex = RegExp(RegExp.escape(host) + r'[^\s<>"]*');
        text = text.replaceAll(brokenRegex, trueUrl);
        issues.add('Phục hồi URL chính xác từ CSDL: $trueUrl');
      }
    }

    // 3. JSON schema check if requested
    if (requiresJson) {
      final jsonResponse = _jsonValidator.validateSearchOutput(
        rawOutput: text,
        databaseCandidates: candidates,
      );
      if (jsonResponse.matches.isEmpty && candidates.isNotEmpty) {
        issues.add('Model sinh JSON chưa đúng schema.');
      }
      text = jsonEncode({
        'matches': jsonResponse.matches.map((match) {
          return {
            'clip_id': match.clipId,
            'value': match.value,
            'reason': match.reason,
          };
        }).toList(),
      });
    }

    // Clean up double spaces or trailing empty lines resulting from ID stripping
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    return VerificationReport(
      isValid: issues.isEmpty,
      correctedText: text,
      issues: issues,
      citations: citations,
    );
  }
}

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
      return const VerificationReport(isValid: true, correctedText: '');
    }

    var text = draftText;
    final issues = <String>[];
    final citations = <String>[];
    final validIds = {for (final item in candidates) item.id};

    // 1. Verify and repair clip_id citations (e.g. [clip:id] or "clip_id": "id")
    final idRegex = RegExp(
      r'\[clip:([a-zA-Z0-9_\-]+)\]|"?clip_id"?\s*:\s*"([a-zA-Z0-9_\-]+)"',
      caseSensitive: false,
    );

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

    // 3. JSON schema check & human-readable formatting for search responses
    if (requiresJson) {
      final jsonResponse = _jsonValidator.validateSearchOutput(
        rawOutput: text,
        databaseCandidates: candidates,
      );
      final isVietnamese = responseLanguage.toLowerCase().startsWith('vi');
      if (jsonResponse.matches.isEmpty) {
        issues.add('Model sinh JSON chưa đúng schema hoặc không tìm thấy kết quả.');
        text = isVietnamese
            ? 'Không tìm thấy mục clipboard nào phù hợp với yêu cầu của bạn trong lịch sử.'
            : 'No matching clipboard items were found in history for your query.';
      } else {
        final buffer = StringBuffer()
          ..writeln(
            isVietnamese
                ? 'Đã tìm thấy ${jsonResponse.matches.length} kết quả phù hợp trong lịch sử clipboard:'
                : 'Found ${jsonResponse.matches.length} matching item(s) in clipboard history:',
          )
          ..writeln();
        for (var i = 0; i < jsonResponse.matches.length; i++) {
          final m = jsonResponse.matches[i];
          final val = m.value.length > 300
              ? '${m.value.substring(0, 300)}…'
              : m.value;
          buffer.writeln('${i + 1}. [clip:${m.clipId}] $val');
          if (m.reason.isNotEmpty) {
            buffer.writeln('   Lý do: ${m.reason}');
          }
          buffer.writeln();
        }
        text = buffer.toString().trim();
      }
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

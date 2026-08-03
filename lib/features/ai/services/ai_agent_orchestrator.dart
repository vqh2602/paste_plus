import '../../clipboard_history/domain/clipboard_content_type.dart';
import '../../clipboard_history/domain/clipboard_item.dart';
import '../domain/ai_execution_plan.dart';

class AiStepResult {
  const AiStepResult({
    required this.stepId,
    required this.tool,
    required this.output,
    this.items = const [],
  });

  final int stepId;
  final String tool;
  final String output;
  final List<ClipboardItem> items;
}

/// Orchestrates multi-step AI tool execution pipelines.
class AiAgentOrchestrator {
  const AiAgentOrchestrator();

  /// Executes [plan] sequentially, resolving step dependencies `$step_N`.
  List<AiStepResult> executePlan({
    required AiExecutionPlan plan,
    required String prompt,
    required String contextText,
    required List<ClipboardItem> clipboardHistory,
  }) {
    final stepResults = <int, AiStepResult>{};
    final outputList = <AiStepResult>[];

    for (final step in plan.steps) {
      final sourceText = _resolveSource(
        arguments: step.arguments,
        contextText: contextText,
        stepResults: stepResults,
      );

      final result = _executeStep(
        step: step,
        prompt: prompt,
        sourceText: sourceText,
        clipboardHistory: clipboardHistory,
      );

      stepResults[step.stepId] = result;
      outputList.add(result);
    }

    return outputList;
  }

  /// Synthesizes the results of all steps into a single clear context text string.
  String synthesizeContext(List<AiStepResult> results, String defaultContext) {
    if (results.isEmpty) return defaultContext;
    if (results.length == 1 && results.first.items.isEmpty) {
      return results.first.output.isNotEmpty ? results.first.output : defaultContext;
    }

    final buffer = StringBuffer();
    for (final result in results) {
      buffer.writeln('[Bước ${result.stepId} - Công cụ ${result.tool}]');
      buffer.writeln(result.output.trim());
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  String _resolveSource({
    required Map<String, dynamic> arguments,
    required String contextText,
    required Map<int, AiStepResult> stepResults,
  }) {
    final sourceVal = arguments['source'];
    if (sourceVal is String) {
      if (sourceVal.startsWith(r'$step_')) {
        final refNum = int.tryParse(sourceVal.replaceFirst(r'$step_', ''));
        if (refNum != null && stepResults.containsKey(refNum)) {
          return stepResults[refNum]!.output;
        }
      }
    }
    return contextText;
  }

  AiStepResult _executeStep({
    required AiExecutionStep step,
    required String prompt,
    required String sourceText,
    required List<ClipboardItem> clipboardHistory,
  }) {
    switch (step.tool) {
      case 'search_clipboard':
        final contentTypeArg = (step.arguments['content_type'] ?? '').toString().toLowerCase();
        final queryArg = (step.arguments['query'] ?? prompt).toString().toLowerCase();
        final dateRangeArg = (step.arguments['date_range'] ?? '').toString().toLowerCase();

        final matches = clipboardHistory.where((item) {
          if (contentTypeArg.isNotEmpty) {
            if (contentTypeArg == 'json' && item.contentType != ClipboardContentType.json) return false;
            if (contentTypeArg == 'url' && item.contentType != ClipboardContentType.url) return false;
            if (contentTypeArg == 'code' && item.contentType != ClipboardContentType.code) return false;
            if (contentTypeArg == 'image' && item.contentType != ClipboardContentType.image) return false;
          }
          if (dateRangeArg == 'yesterday') {
            final now = DateTime.now();
            final yesterday = now.subtract(const Duration(days: 1));
            if (item.createdAt.day != yesterday.day) return false;
          }
          return true;
        }).toList();

        final targetItems = matches.isNotEmpty ? matches : clipboardHistory;
        final formattedItems = targetItems.take(5).map((item) => '[clip:${item.id}] (${item.contentType.name}): ${item.content}').join('\n---\n');

        return AiStepResult(
          stepId: step.stepId,
          tool: step.tool,
          output: 'Đã tìm thấy ${targetItems.length} mục clipboard khớp:\n$formattedItems',
          items: targetItems,
        );

      case 'extract_urls':
        final urlRegex = RegExp(r'https?://[^\s<>"]+|www\.[^\s<>"]+', caseSensitive: false);
        final matches = urlRegex.allMatches(sourceText).map((m) => m.group(0)!).toList();
        final outputText = matches.isNotEmpty
            ? 'Đã trích xuất ${matches.length} URL:\n${matches.join('\n')}'
            : 'Không tìm thấy URL nào trong nguồn dữ liệu.';
        return AiStepResult(
          stepId: step.stepId,
          tool: step.tool,
          output: outputText,
        );

      case 'explain_content':
      case 'qa_clipboard':
        return AiStepResult(
          stepId: step.stepId,
          tool: step.tool,
          output: 'Nội dung phân tích/giải thích:\n$sourceText',
        );

      default:
        return AiStepResult(
          stepId: step.stepId,
          tool: step.tool,
          output: sourceText,
        );
    }
  }
}

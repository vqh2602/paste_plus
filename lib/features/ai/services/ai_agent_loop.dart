import '../../clipboard_history/domain/clipboard_content_type.dart';
import '../../clipboard_history/domain/clipboard_item.dart';
import '../domain/ai_execution_plan.dart';
import '../tools/ai_tool_registry.dart';
import 'ai_agent_orchestrator.dart';

/// Decision made by planner at each iteration of the agent loop.
class AiAgentDecision {
  const AiAgentDecision({
    required this.isFinalAnswer,
    this.answer,
    this.toolName,
    this.arguments = const {},
  });

  factory AiAgentDecision.finalAnswer(String answer) => AiAgentDecision(
        isFinalAnswer: true,
        answer: answer,
      );

  factory AiAgentDecision.callTool(String toolName, Map<String, dynamic> arguments) =>
      AiAgentDecision(
        isFinalAnswer: false,
        toolName: toolName,
        arguments: arguments,
      );

  final bool isFinalAnswer;
  final String? answer;
  final String? toolName;
  final Map<String, dynamic> arguments;
}

/// Accumulates observations gathered during the agent loop.
class AiAgentState {
  final List<String> observations = [];
  final List<AiStepResult> stepResults = [];
  final Map<int, AiStepResult> stepResultMap = {};

  void addObservation(String observation) {
    observations.add(observation);
  }

  void addStepResult(AiStepResult result) {
    stepResults.add(result);
    stepResultMap[result.stepId] = result;
    observations.add('[Bước ${result.stepId} - Công cụ: ${result.tool}]\n${result.output}');
  }

  String buildContextSummary() {
    return observations.join('\n---\n');
  }
}

/// Runs the multi-step agent loop with tool execution and confirmation handling.
class AiAgentLoop {
  const AiAgentLoop({
    this.maxSteps = 4,
    required this.toolRegistry,
  });

  final int maxSteps;
  final AiToolRegistry toolRegistry;

  /// Runs an execution plan step-by-step in an async loop with dependency resolution.
  Future<List<AiStepResult>> runPlan({
    required AiExecutionPlan plan,
    required String prompt,
    required String contextText,
    required List<ClipboardItem> clipboardHistory,
    Future<bool> Function(String toolName, Map<String, dynamic> args)?
        onConfirmationRequested,
  }) async {
    final state = AiAgentState();

    for (var i = 0; i < plan.steps.length && i < maxSteps; i++) {
      final step = plan.steps[i];
      final sourceText = _resolveSource(
        arguments: step.arguments,
        contextText: contextText,
        stepResults: state.stepResultMap,
      );

      final registeredTool = toolRegistry.getTool(step.tool);
      late AiStepResult stepResult;

      if (registeredTool != null) {
        final args = Map<String, dynamic>.from(step.arguments);
        if (!args.containsKey('text') && sourceText.isNotEmpty) {
          args['text'] = sourceText;
        }

        final toolResult = await toolRegistry.execute(
          step.tool,
          args,
          onConfirmationRequested: onConfirmationRequested,
        );

        final items = <ClipboardItem>[];
        if (toolResult.data is List<ClipboardItem>) {
          items.addAll(toolResult.data as List<ClipboardItem>);
        } else if (toolResult.data is ClipboardItem) {
          items.add(toolResult.data as ClipboardItem);
        }

        stepResult = AiStepResult(
          stepId: step.stepId,
          tool: step.tool,
          output: toolResult.output,
          items: items,
        );
      } else {
        stepResult = _executeFallbackStep(
          step: step,
          sourceText: sourceText,
          clipboardHistory: clipboardHistory,
        );
      }

      state.addStepResult(stepResult);
    }

    return state.stepResults;
  }

  /// Runs a dynamic decision agent loop.
  Future<String> run({
    required String prompt,
    required Future<AiAgentDecision> Function(AiAgentState state, int step) nextDecision,
    Future<bool> Function(String toolName, Map<String, dynamic> args)? onConfirmationRequested,
  }) async {
    final state = AiAgentState();

    for (var step = 0; step < maxSteps; step++) {
      final decision = await nextDecision(state, step);

      if (decision.isFinalAnswer) {
        return decision.answer ?? 'Đã hoàn thành xử lý.';
      }

      if (decision.toolName != null && decision.toolName!.isNotEmpty) {
        final result = await toolRegistry.execute(
          decision.toolName!,
          decision.arguments,
          onConfirmationRequested: onConfirmationRequested,
        );

        state.addObservation(
          '[Bước ${step + 1} - Công cụ: ${decision.toolName}]\n${result.output}',
        );
      }
    }

    return state.observations.isNotEmpty
        ? state.observations.join('\n\n')
        : 'Đã hoàn thành các bước xử lý.';
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

  AiStepResult _executeFallbackStep({
    required AiExecutionStep step,
    required String sourceText,
    required List<ClipboardItem> clipboardHistory,
  }) {
    switch (step.tool) {
      case 'search_clipboard':
        final contentTypeArg = (step.arguments['content_type'] ?? '').toString().toLowerCase();
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
      default:
        return AiStepResult(
          stepId: step.stepId,
          tool: step.tool,
          output: 'Nội dung phân tích/giải thích:\n$sourceText',
        );
    }
  }
}

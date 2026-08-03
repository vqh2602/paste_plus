import '../../clipboard_history/domain/clipboard_item.dart';
import '../domain/ai_execution_plan.dart';
import '../tools/ai_tool_registry.dart';
import '../tools/impl/clipboard_tools.dart';
import 'ai_agent_loop.dart';

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

/// Orchestrates multi-step AI tool execution pipelines using [AiAgentLoop] and [AiToolRegistry].
class AiAgentOrchestrator {
  const AiAgentOrchestrator([this._customRegistry]);

  final AiToolRegistry? _customRegistry;

  /// Executes [plan] sequentially by delegating to [AiAgentLoop].
  Future<List<AiStepResult>> executePlan({
    required AiExecutionPlan plan,
    required String prompt,
    required String contextText,
    required List<ClipboardItem> clipboardHistory,
    Future<bool> Function(String toolName, Map<String, dynamic> arguments)?
        onConfirmationRequested,
  }) async {
    final registry = _customRegistry ?? _buildDefaultRegistry(clipboardHistory);
    final agentLoop = AiAgentLoop(
      maxSteps: plan.steps.isNotEmpty ? plan.steps.length : 4,
      toolRegistry: registry,
    );

    return agentLoop.runPlan(
      plan: plan,
      prompt: prompt,
      contextText: contextText,
      clipboardHistory: clipboardHistory,
      onConfirmationRequested: onConfirmationRequested,
    );
  }

  AiToolRegistry _buildDefaultRegistry(List<ClipboardItem> history) {
    final registry = AiToolRegistry();
    registry.register(SearchClipboardTool(history));
    registry.register(GetClipboardItemTool(history));
    registry.register(ExtractUrlsTool());
    registry.register(ListCollectionsTool());
    registry.register(PinClipboardTool());
    registry.register(AddToCollectionTool());
    registry.register(DeleteClipboardItemTool());
    return registry;
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
}

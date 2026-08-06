import '../../clipboard_history/domain/clipboard_item.dart';
import '../../clipboard_history/domain/clipboard_repository.dart';
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
  const AiAgentOrchestrator([
    dynamic repositoryOrRegistry,
    AiToolRegistry? customRegistry,
  ]) : _repository = repositoryOrRegistry is ClipboardRepository
           ? repositoryOrRegistry
           : null,
       _customRegistry =
           customRegistry ??
           (repositoryOrRegistry is AiToolRegistry
               ? repositoryOrRegistry
               : null);

  final ClipboardRepository? _repository;
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
    final registry =
        _customRegistry ?? _buildDefaultRegistry(clipboardHistory, _repository);
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

  AiToolRegistry _buildDefaultRegistry(
    List<ClipboardItem> history, [
    ClipboardRepository? repository,
  ]) {
    final registry = AiToolRegistry();
    registry.register(SearchClipboardTool(history, repository));
    registry.register(GetClipboardItemTool(history, repository));
    registry.register(ExtractUrlsTool());
    registry.register(ListCollectionsTool(repository));
    registry.register(PinClipboardTool(repository, history));
    registry.register(AddToCollectionTool(repository, history));
    registry.register(DeleteClipboardItemTool(repository, history));
    return registry;
  }

  /// Synthesizes the results of all steps into a single clear context text string.
  /// When [toolResultItems] are provided, formats them as structured clipboard
  /// context with [clip:id] references so the LLM can produce accurate output.
  String synthesizeContext(
    List<AiStepResult> results,
    String defaultContext, [
    List<ClipboardItem> toolResultItems = const [],
  ]) {
    if (results.isEmpty) return defaultContext;

    // If we have concrete clipboard items from tools, build a proper [clip:id]
    // formatted context that the LLM and AiResponseVerifier can both process.
    if (toolResultItems.isNotEmpty) {
      final buffer = StringBuffer();
      for (var i = 0; i < toolResultItems.length; i++) {
        final item = toolResultItems[i];
        var content = item.content.trim();
        if (item.contentType.name == 'image') {
          final fileName = item.imagePath?.split('/').last ?? 'image.png';
          content = content.isEmpty || content == '[Image]'
              ? '[image file_name="$fileName"]'
              : '[image file_name="$fileName" ocr="$content"]';
        }
        if (content.isEmpty) continue;
        final app = item.sourceAppName ?? 'Unknown';
        buffer.writeln(
          '[clip:${item.id}] (${item.contentType.name}) $app: $content',
        );
      }
      return buffer.toString().trim();
    }

    // Single step with no items: use step output text directly
    if (results.length == 1 && results.first.items.isEmpty) {
      return results.first.output.isNotEmpty
          ? results.first.output
          : defaultContext;
    }

    // Multi-step: combine all step outputs labelled by step id and tool name
    final buffer = StringBuffer();
    for (final result in results) {
      buffer.writeln('[step:${result.stepId} tool:${result.tool}]');
      buffer.writeln(result.output.trim());
      buffer.writeln();
    }
    return buffer.toString().trim();
  }
}

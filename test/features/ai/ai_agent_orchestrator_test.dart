import 'package:clipflow/features/ai/domain/ai_execution_plan.dart';
import 'package:clipflow/features/ai/services/ai_agent_orchestrator.dart';
import 'package:clipflow/features/ai/tools/ai_tool.dart';
import 'package:clipflow/features/ai/tools/ai_tool_registry.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:flutter_test/flutter_test.dart';

ClipboardItem mockItem({
  required String id,
  required String content,
  required ClipboardContentType type,
  DateTime? createdAt,
}) {
  final timestamp = createdAt ?? DateTime(2026, 8, 2);
  return ClipboardItem(
    id: id,
    content: content,
    normalizedContent: content.toLowerCase(),
    contentHash: 'hash-$id',
    contentType: type,
    createdAt: timestamp,
    updatedAt: timestamp,
    lastCopiedAt: timestamp,
    sourceAppName: 'Test App',
    isPinned: false,
    isSensitive: false,
    copyCount: 1,
  );
}

class FakeTool implements AiTool {
  FakeTool(this.name, this.outputToReturn);

  @override
  final String name;
  final String outputToReturn;

  int executionCount = 0;
  String? lastReceivedText;

  @override
  String get description => 'Fake tool for testing';

  @override
  bool get requiresConfirmation => false;

  @override
  Map<String, dynamic> get inputSchema => {};

  @override
  Future<AiToolResult> execute(Map<String, dynamic> arguments) async {
    executionCount++;
    lastReceivedText = arguments['text']?.toString();
    return AiToolResult.ok(outputToReturn);
  }
}

void main() {
  const orchestrator = AiAgentOrchestrator();

  group('AiAgentOrchestrator', () {
    test('executes multi-step search, extract, and explain pipeline', () async {
      final jsonItem = mockItem(
        id: 'json_clip',
        content: '{"api": "https://api.example.com/v1/user", "status": "active"}',
        type: ClipboardContentType.json,
      );

      final plan = AiExecutionPlan(
        intent: 'multi_step',
        language: 'Vietnamese',
        needsClipboard: true,
        steps: const [
          AiExecutionStep(
            stepId: 1,
            tool: 'search_clipboard',
            arguments: {'content_type': 'json'},
          ),
          AiExecutionStep(
            stepId: 2,
            tool: 'extract_urls',
            arguments: {'source': r'$step_1'},
          ),
          AiExecutionStep(
            stepId: 3,
            tool: 'explain_content',
            arguments: {'source': r'$step_1'},
          ),
        ],
      );

      final results = await orchestrator.executePlan(
        plan: plan,
        prompt: 'tìm đoạn JSON rồi trích URL',
        contextText: jsonItem.content,
        clipboardHistory: [jsonItem],
      );

      expect(results.length, 3);
      expect(results[0].tool, 'search_clipboard');
      expect(results[0].output, contains('https://api.example.com/v1/user'));

      expect(results[1].tool, 'extract_urls');
      expect(results[1].output, contains('https://api.example.com/v1/user'));

      expect(results[2].tool, 'explain_content');
      expect(results[2].output, contains('https://api.example.com/v1/user'));

      final synthesized = orchestrator.synthesizeContext(results, jsonItem.content);
      expect(synthesized, contains('Bước 1'));
      expect(synthesized, contains('Bước 2'));
      expect(synthesized, contains('Bước 3'));
    });

    test('awaits real tool execution and passes observation output to subsequent steps', () async {
      final fakeRegistry = AiToolRegistry();
      final fakeTool1 = FakeTool('fake_tool_1', 'OUTPUT_FROM_REAL_TOOL');
      final fakeTool2 = FakeTool('fake_tool_2', 'FINAL_STEP_OUTPUT');
      fakeRegistry.register(fakeTool1);
      fakeRegistry.register(fakeTool2);

      final customOrchestrator = AiAgentOrchestrator(fakeRegistry);

      final plan = const AiExecutionPlan(
        intent: 'multi_step',
        language: 'Vietnamese',
        needsClipboard: true,
        steps: [
          AiExecutionStep(
            stepId: 1,
            tool: 'fake_tool_1',
            arguments: {},
          ),
          AiExecutionStep(
            stepId: 2,
            tool: 'fake_tool_2',
            arguments: {'source': r'$step_1'},
          ),
        ],
      );

      final results = await customOrchestrator.executePlan(
        plan: plan,
        prompt: 'test prompt',
        contextText: 'UNRELATED_INITIAL_CONTEXT',
        clipboardHistory: const [],
      );

      expect(fakeTool1.executionCount, 1);
      expect(results[0].output, equals('OUTPUT_FROM_REAL_TOOL'));

      expect(fakeTool2.executionCount, 1);
      expect(fakeTool2.lastReceivedText, equals('OUTPUT_FROM_REAL_TOOL'));
      expect(results[1].output, equals('FINAL_STEP_OUTPUT'));
    });
  });
}


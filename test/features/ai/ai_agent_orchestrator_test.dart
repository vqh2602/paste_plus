import 'package:clipflow/features/ai/domain/ai_execution_plan.dart';
import 'package:clipflow/features/ai/services/ai_agent_orchestrator.dart';
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

void main() {
  const orchestrator = AiAgentOrchestrator();

  group('AiAgentOrchestrator', () {
    test('executes multi-step search, extract, and explain pipeline', () {
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

      final results = orchestrator.executePlan(
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
  });
}

import 'package:clipflow/features/ai/services/ai_agent_loop.dart';
import 'package:clipflow/features/ai/tools/ai_tool_registry.dart';
import 'package:clipflow/features/ai/tools/impl/clipboard_tools.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late AiToolRegistry registry;

  setUp(() {
    registry = AiToolRegistry();
    registry.register(ExtractUrlsTool());
    registry.register(PinClipboardTool());
  });

  group('AiAgentLoop', () {
    test('runs multi-step decisions and accumulates observations', () async {
      final loop = AiAgentLoop(maxSteps: 3, toolRegistry: registry);

      final finalAnswer = await loop.run(
        prompt: 'Lấy URL rồi ghim bản ghi',
        nextDecision: (state, step) async {
          if (step == 0) {
            return AiAgentDecision.callTool(
              'extract_urls',
              {'text': 'Visit https://example.com/api'},
            );
          } else if (step == 1) {
            return AiAgentDecision.callTool(
              'pin_clipboard',
              {'clip_id': 'clip_456', 'pinned': true},
            );
          }
          return AiAgentDecision.finalAnswer(
            'Đã trích xuất URL https://example.com/api và ghim bản ghi thành công.',
          );
        },
        onConfirmationRequested: (tool, args) async => true,
      );

      expect(
        finalAnswer,
        equals('Đã trích xuất URL https://example.com/api và ghim bản ghi thành công.'),
      );
    });

    test('handles user rejection in mutating step', () async {
      final loop = AiAgentLoop(maxSteps: 3, toolRegistry: registry);

      final result = await loop.run(
        prompt: 'Ghim clipboard',
        nextDecision: (state, step) async {
          if (step == 0) {
            return AiAgentDecision.callTool(
              'pin_clipboard',
              {'clip_id': 'clip_789', 'pinned': true},
            );
          }
          return AiAgentDecision.finalAnswer(
            'Không thể ghim bản ghi do người dùng từ chối.',
          );
        },
        onConfirmationRequested: (tool, args) async => false, // User cancels
      );

      expect(result, contains('từ chối'));
    });
  });
}

import 'package:clipflow/features/ai/domain/ai_execution_plan.dart';
import 'package:clipflow/features/ai/services/ai_planner_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = AiPlannerService();

  group('AiPlannerService - Model Planner Trigger', () {
    test('shouldUseModelPlanner returns false for simple single-action prompts', () {
      expect(
        service.shouldUseModelPlanner(
          prompt: 'dịch đoạn này sang tiếng Anh',
          hasSelectedClipboard: true,
        ),
        isFalse,
      );

      expect(
        service.shouldUseModelPlanner(
          prompt: 'tóm tắt văn bản',
          hasSelectedClipboard: true,
        ),
        isFalse,
      );

      expect(
        service.shouldUseModelPlanner(
          prompt: 'sửa lỗi chính tả',
          hasSelectedClipboard: true,
        ),
        isFalse,
      );
    });

    test('shouldUseModelPlanner returns true for complex multi-step or reference prompts', () {
      expect(
        service.shouldUseModelPlanner(
          prompt: 'Tìm đoạn JSON tôi copy hôm qua, lấy URL rồi giải thích API',
          hasSelectedClipboard: false,
        ),
        isTrue,
      );

      expect(
        service.shouldUseModelPlanner(
          prompt: 'Lấy link từ đoạn code vừa tìm rồi ghim vào bộ sưu tập',
          hasSelectedClipboard: false,
        ),
        isTrue,
      );

      expect(
        service.shouldUseModelPlanner(
          prompt: 'giải thích kĩ hơn kết quả vừa rồi',
          hasSelectedClipboard: false,
        ),
        isTrue,
      );
    });

    test('createPlan parses valid rawModelPlanJson into executionPlan', () {
      const validJson = '''
      {
        "intent": "multi_step",
        "language": "Vietnamese",
        "needs_clipboard": true,
        "steps": [
          {
            "step_id": 1,
            "tool": "search_clipboard",
            "arguments": {"content_type": "json"}
          },
          {
            "step_id": 2,
            "tool": "extract_urls",
            "arguments": {"source": "\$step_1"}
          }
        ]
      }
      ''';

      final requestPlan = service.createPlan(
        prompt: 'tìm JSON rồi lấy URL',
        hasSelectedClipboard: false,
        hasConversation: false,
        rawModelPlanJson: validJson,
      );

      expect(requestPlan.executionPlan, isNotNull);
      expect(requestPlan.executionPlan!.isMultiStep, isTrue);
      expect(requestPlan.executionPlan!.steps.length, 2);
      expect(requestPlan.executionPlan!.steps[0].tool, 'search_clipboard');
      expect(requestPlan.executionPlan!.steps[1].tool, 'extract_urls');
    });

    test('createPlan falls back when rawModelPlanJson is invalid', () {
      const invalidJson = '''
      {
        "intent": "multi_step",
        "language": "Vietnamese",
        "steps": [
          {
            "step_id": 1,
            "tool": "unsupported_malicious_tool"
          }
        ]
      }
      ''';

      final requestPlan = service.createPlan(
        prompt: 'dịch đoạn này',
        hasSelectedClipboard: true,
        hasConversation: false,
        rawModelPlanJson: invalidJson,
      );

      expect(requestPlan.executionPlan, isNotNull);
      expect(requestPlan.executionPlan!.steps.length, 1);
      expect(requestPlan.executionPlan!.steps.first.tool, isNot('unsupported_malicious_tool'));
    });
  });
}

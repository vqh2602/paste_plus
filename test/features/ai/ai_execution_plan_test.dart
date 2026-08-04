import 'package:clipflow/features/ai/domain/ai_execution_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiExecutionPlan', () {
    test('parses multi-step JSON correctly', () {
      const jsonStr = '''
{
  "intent": "multi_step",
  "language": "Vietnamese",
  "needs_clipboard": true,
  "steps": [
    {
      "step_id": 1,
      "tool": "search_clipboard",
      "arguments": {
        "content_type": "json",
        "date_range": "yesterday"
      }
    },
    {
      "step_id": 2,
      "tool": "extract_urls",
      "arguments": {
        "source": "\$step_1"
      }
    }
  ],
  "output_format": "markdown",
  "confidence": 0.95
}
''';

      final plan = AiExecutionPlan.tryParseJson(jsonStr);

      expect(plan, isNotNull);
      expect(plan!.intent, 'multi_step');
      expect(plan.language, 'Vietnamese');
      expect(plan.needsClipboard, isTrue);
      expect(plan.isMultiStep, isTrue);
      expect(plan.steps.length, 2);

      expect(plan.steps[0].stepId, 1);
      expect(plan.steps[0].tool, 'search_clipboard');
      expect(plan.steps[0].arguments['content_type'], 'json');

      expect(plan.steps[1].stepId, 2);
      expect(plan.steps[1].tool, 'extract_urls');
      expect(plan.steps[1].arguments['source'], r'$step_1');
    });

    test('extracts JSON from markdown code block fences', () {
      const markdownBlock = '''
Here is the execution plan:
```json
{
  "intent": "single_step",
  "language": "English",
  "needs_clipboard": false,
  "steps": [
    {
      "step_id": 1,
      "tool": "explain_content",
      "arguments": {}
    }
  ]
}
```
''';

      final plan = AiExecutionPlan.tryParseJson(markdownBlock);

      expect(plan, isNotNull);
      expect(plan!.intent, 'single_step');
      expect(plan.language, 'English');
      expect(plan.steps.length, 1);
      expect(plan.steps.first.tool, 'explain_content');
    });

    test('singleStepFallback creates valid 1-step plan', () {
      final fallback = AiExecutionPlan.singleStepFallback(
        tool: 'search_clipboard',
        language: 'Vietnamese',
        arguments: {'query': 'test'},
      );

      expect(fallback.intent, 'single_step');
      expect(fallback.isMultiStep, isFalse);
      expect(fallback.hasExecutableTools, isTrue);
      expect(fallback.steps.length, 1);
      expect(fallback.steps.first.tool, 'search_clipboard');
      expect(fallback.steps.first.arguments['query'], 'test');
    });

    test('hasExecutableTools identifies actionable tool steps correctly', () {
      final pinPlan = AiExecutionPlan.singleStepFallback(
        tool: 'pin_clipboard',
        language: 'Vietnamese',
      );
      final deletePlan = AiExecutionPlan.singleStepFallback(
        tool: 'delete_clipboard_item',
        language: 'Vietnamese',
      );
      final listPlan = AiExecutionPlan.singleStepFallback(
        tool: 'list_collections',
        language: 'Vietnamese',
      );
      final chatPlan = AiExecutionPlan.singleStepFallback(
        tool: 'explain_content',
        language: 'Vietnamese',
      );

      expect(pinPlan.hasExecutableTools, isTrue);
      expect(deletePlan.hasExecutableTools, isTrue);
      expect(listPlan.hasExecutableTools, isTrue);
      expect(chatPlan.hasExecutableTools, isFalse);
    });
  });
}

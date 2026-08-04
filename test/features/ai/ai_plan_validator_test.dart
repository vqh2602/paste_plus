import 'package:clipflow/features/ai/domain/ai_execution_plan.dart';
import 'package:clipflow/features/ai/services/ai_plan_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = AiPlanValidator();

  group('AiPlanValidator', () {
    test('validates normal 1 to 3 step plans with supported tools', () {
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
        ],
      );

      expect(validator.isValid(plan), isTrue);
    });

    test('rejects plan with empty steps or > 4 steps', () {
      final emptyPlan = AiExecutionPlan(
        intent: 'single_step',
        language: 'Vietnamese',
        needsClipboard: false,
        steps: const [],
      );

      expect(validator.isValid(emptyPlan), isFalse);

      final overLimitPlan = AiExecutionPlan(
        intent: 'multi_step',
        language: 'English',
        needsClipboard: true,
        steps: const [
          AiExecutionStep(stepId: 1, tool: 'search_clipboard'),
          AiExecutionStep(
            stepId: 2,
            tool: 'extract_urls',
            arguments: {'source': r'$step_1'},
          ),
          AiExecutionStep(
            stepId: 3,
            tool: 'explain_content',
            arguments: {'source': r'$step_2'},
          ),
          AiExecutionStep(
            stepId: 4,
            tool: 'summarize_text',
            arguments: {'source': r'$step_3'},
          ),
          AiExecutionStep(
            stepId: 5,
            tool: 'translate_text',
            arguments: {'source': r'$step_4'},
          ),
        ],
      );

      expect(validator.isValid(overLimitPlan), isFalse);
    });

    test('rejects plan with unregistered tools or forward step references', () {
      final invalidToolPlan = AiExecutionPlan(
        intent: 'single_step',
        language: 'Vietnamese',
        needsClipboard: false,
        steps: const [
          AiExecutionStep(stepId: 1, tool: 'delete_system_database'),
        ],
      );

      expect(validator.isValid(invalidToolPlan), isFalse);

      final advertisedButUnimplementedToolPlan = AiExecutionPlan(
        intent: 'single_step',
        language: 'Vietnamese',
        needsClipboard: true,
        steps: const [AiExecutionStep(stepId: 1, tool: 'summarize_text')],
      );

      expect(validator.isValid(advertisedButUnimplementedToolPlan), isFalse);

      final invalidRefPlan = AiExecutionPlan(
        intent: 'multi_step',
        language: 'English',
        needsClipboard: true,
        steps: const [
          AiExecutionStep(
            stepId: 1,
            tool: 'extract_urls',
            arguments: {'source': r'$step_2'},
          ),
          AiExecutionStep(stepId: 2, tool: 'search_clipboard'),
        ],
      );

      expect(validator.isValid(invalidRefPlan), isFalse);
    });

    test('validateOrFallback returns valid plan or safe fallback', () {
      final invalidPlan = AiExecutionPlan(
        intent: 'single_step',
        language: 'Vietnamese',
        needsClipboard: false,
        steps: const [AiExecutionStep(stepId: 1, tool: 'malicious_tool')],
      );

      final validated = validator.validateOrFallback(
        invalidPlan,
        defaultTool: 'search_clipboard',
        defaultLanguageTag: 'vi-VN',
      );

      expect(validated.steps.length, 1);
      expect(validated.steps.first.tool, 'search_clipboard');
    });
  });
}

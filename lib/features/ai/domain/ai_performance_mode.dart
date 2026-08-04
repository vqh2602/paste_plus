import 'ai_request_plan.dart';

enum AiPerformanceMode { fast, balanced, smart }

extension AiPerformanceModeX on AiPerformanceMode {
  bool enablesThinking({
    required bool modelSupportsThinking,
    required AiRequestIntent intent,
  }) {
    if (!modelSupportsThinking) return false;
    return switch (this) {
      AiPerformanceMode.fast => false,
      AiPerformanceMode.balanced => intent == AiRequestIntent.clipboardAction,
      AiPerformanceMode.smart => true,
    };
  }
}

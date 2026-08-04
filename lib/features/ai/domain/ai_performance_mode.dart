import 'ai_request_classification.dart';

enum AiPerformanceMode { fast, balanced, smart }

extension AiPerformanceModeX on AiPerformanceMode {
  bool enablesThinking({
    required bool modelSupportsThinking,
    required AiReasoningLevel reasoningLevel,
  }) {
    if (!modelSupportsThinking) return false;
    return switch (this) {
      AiPerformanceMode.fast => false,
      AiPerformanceMode.balanced => reasoningLevel == AiReasoningLevel.high,
      AiPerformanceMode.smart => reasoningLevel != AiReasoningLevel.low,
    };
  }
}

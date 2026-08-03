import 'dart:convert';

/// Represents an individual step within a multi-step AI execution plan.
class AiExecutionStep {
  const AiExecutionStep({
    required this.stepId,
    required this.tool,
    this.arguments = const {},
  });

  factory AiExecutionStep.fromJson(
    Map<String, dynamic> json,
    int defaultStepId,
  ) {
    final stepId = json['step_id'] is int
        ? json['step_id'] as int
        : (json['stepId'] is int ? json['stepId'] as int : defaultStepId);
    final tool = (json['tool'] ?? json['action'] ?? 'search_clipboard')
        .toString()
        .trim();
    final argsRaw = json['arguments'] ?? json['args'];
    final Map<String, dynamic> arguments = argsRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(argsRaw)
        : (argsRaw is Map
              ? Map<String, dynamic>.from(argsRaw)
              : <String, dynamic>{});

    return AiExecutionStep(stepId: stepId, tool: tool, arguments: arguments);
  }

  final int stepId;
  final String tool;
  final Map<String, dynamic> arguments;

  Map<String, dynamic> toJson() => {
    'step_id': stepId,
    'tool': tool,
    'arguments': arguments,
  };
}

/// Structured multi-step or single-step execution plan produced by planner.
class AiExecutionPlan {
  const AiExecutionPlan({
    required this.intent,
    required this.language,
    required this.needsClipboard,
    required this.steps,
    this.outputFormat = 'markdown',
    this.confidence = 1.0,
  });

  factory AiExecutionPlan.singleStepFallback({
    required String tool,
    required String language,
    Map<String, dynamic> arguments = const {},
  }) {
    return AiExecutionPlan(
      intent: 'single_step',
      language: language,
      needsClipboard: true,
      steps: [AiExecutionStep(stepId: 1, tool: tool, arguments: arguments)],
    );
  }

  factory AiExecutionPlan.fromJson(Map<String, dynamic> json) {
    final intent = (json['intent'] ?? 'single_step').toString();
    final language = (json['language'] ?? 'Vietnamese').toString();
    final needsClipboard =
        json['needs_clipboard'] == true || json['needsClipboard'] == true;
    final outputFormat =
        (json['output_format'] ?? json['outputFormat'] ?? 'markdown')
            .toString();
    final confidence = (json['confidence'] is num)
        ? (json['confidence'] as num).toDouble()
        : 1.0;

    final stepsRaw = json['steps'];
    final steps = <AiExecutionStep>[];
    if (stepsRaw is List) {
      for (var index = 0; index < stepsRaw.length; index++) {
        final item = stepsRaw[index];
        if (item is Map<String, dynamic>) {
          steps.add(AiExecutionStep.fromJson(item, index + 1));
        } else if (item is Map) {
          steps.add(
            AiExecutionStep.fromJson(
              Map<String, dynamic>.from(item),
              index + 1,
            ),
          );
        }
      }
    }

    return AiExecutionPlan(
      intent: intent,
      language: language,
      needsClipboard: needsClipboard,
      steps: steps,
      outputFormat: outputFormat,
      confidence: confidence,
    );
  }

  static AiExecutionPlan? tryParseJson(String rawText) {
    try {
      final trimmed = rawText.trim();
      var jsonStr = trimmed;
      if (trimmed.contains('```')) {
        final startIndex = trimmed.indexOf('{');
        final endIndex = trimmed.lastIndexOf('}');
        if (startIndex != -1 && endIndex > startIndex) {
          jsonStr = trimmed.substring(startIndex, endIndex + 1);
        }
      }
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return AiExecutionPlan.fromJson(decoded);
      } else if (decoded is Map) {
        return AiExecutionPlan.fromJson(Map<String, dynamic>.from(decoded));
      }
    } on Object {
      // Return null on malformed JSON
    }
    return null;
  }

  final String intent;
  final String language;
  final bool needsClipboard;
  final List<AiExecutionStep> steps;
  final String outputFormat;
  final double confidence;

  bool get isMultiStep => steps.length > 1;

  Map<String, dynamic> toJson() => {
    'intent': intent,
    'language': language,
    'needs_clipboard': needsClipboard,
    'steps': steps.map((s) => s.toJson()).toList(),
    'output_format': outputFormat,
    'confidence': confidence,
  };
}

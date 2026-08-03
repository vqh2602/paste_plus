import '../tools/ai_tool_registry.dart';

/// Decision made by planner at each iteration of the agent loop.
class AiAgentDecision {
  const AiAgentDecision({
    required this.isFinalAnswer,
    this.answer,
    this.toolName,
    this.arguments = const {},
  });

  factory AiAgentDecision.finalAnswer(String answer) => AiAgentDecision(
        isFinalAnswer: true,
        answer: answer,
      );

  factory AiAgentDecision.callTool(String toolName, Map<String, dynamic> arguments) =>
      AiAgentDecision(
        isFinalAnswer: false,
        toolName: toolName,
        arguments: arguments,
      );

  final bool isFinalAnswer;
  final String? answer;
  final String? toolName;
  final Map<String, dynamic> arguments;
}

/// Accumulates observations gathered during the agent loop.
class AiAgentState {
  final List<String> observations = [];

  void addObservation(String observation) {
    observations.add(observation);
  }

  String buildContextSummary() {
    return observations.join('\n---\n');
  }
}

/// Runs the multi-step agent loop with tool execution and confirmation handling.
class AiAgentLoop {
  const AiAgentLoop({
    this.maxSteps = 4,
    required this.toolRegistry,
  });

  final int maxSteps;
  final AiToolRegistry toolRegistry;

  Future<String> run({
    required String prompt,
    required Future<AiAgentDecision> Function(AiAgentState state, int step) nextDecision,
    Future<bool> Function(String toolName, Map<String, dynamic> args)? onConfirmationRequested,
  }) async {
    final state = AiAgentState();

    for (var step = 0; step < maxSteps; step++) {
      final decision = await nextDecision(state, step);

      if (decision.isFinalAnswer) {
        return decision.answer ?? 'Đã hoàn thành xử lý.';
      }

      if (decision.toolName != null && decision.toolName!.isNotEmpty) {
        final result = await toolRegistry.execute(
          decision.toolName!,
          decision.arguments,
          onConfirmationRequested: onConfirmationRequested,
        );

        state.addObservation(
          '[Bước ${step + 1} - Công cụ: ${decision.toolName}]\n${result.output}',
        );
      }
    }

    return state.observations.isNotEmpty
        ? state.observations.join('\n\n')
        : 'Đã hoàn thành các bước xử lý.';
  }
}

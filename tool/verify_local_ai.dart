import 'dart:io';

import 'package:clipflow/features/ai/services/llama_inference_service.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      'Usage: dart run tool/verify_local_ai.dart <model.gguf> [prompt]',
    );
    exitCode = 64;
    return;
  }

  final service = LlamaInferenceService();
  final answer = StringBuffer();
  final thinking = StringBuffer();
  try {
    await for (final token in service.generate(
      modelPath: arguments.first,
      contextSize: 2048,
      systemPrompt:
          'You are ClipFlow, a friendly conversational assistant. Reply in '
          '${arguments.length == 2 ? 'Vietnamese' : 'English'}. '
          'For greetings, reply with exactly '
          'one short, natural sentence. Do not discuss hidden context.',
      userPrompt: arguments.length == 2
          ? 'Reply naturally in Vietnamese with one short sentence. User: ${arguments[1]}'
          : 'hi',
      maxTokens: 768,
      temperature: 0.2,
      thinkingModel: true,
    )) {
      if (token.thinking != null) thinking.write(token.thinking);
      if (token.content != null) answer.write(token.content);
    }
    stdout.writeln('THINKING_CHARS=${thinking.length}');
    stdout.writeln('ANSWER=${answer.toString().trim()}');
    if (answer.toString().trim().isEmpty) exitCode = 1;
  } finally {
    await service.dispose();
  }
}

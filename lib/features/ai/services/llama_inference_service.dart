import 'package:llamadart/llamadart.dart';

class LlamaConversationTurn {
  const LlamaConversationTurn({required this.isUser, required this.text});
  final bool isUser;
  final String text;
}

class LlamaStreamToken {
  const LlamaStreamToken({this.content, this.thinking});
  final String? content;
  final String? thinking;
}

class LlamaInferenceService {
  LlamaEngine? _engine;
  String? _loadedModelPath;

  Future<void> _ensureLoaded(String modelPath, int contextSize) async {
    if (_engine?.isReady == true && _loadedModelPath == modelPath) return;
    await _engine?.dispose();
    final engine = LlamaEngine(LlamaBackend());
    await engine.loadModel(
      modelPath,
      modelParams: ModelParams(contextSize: contextSize, gpuLayers: 999),
    );
    _engine = engine;
    _loadedModelPath = modelPath;
  }

  Stream<LlamaStreamToken> generate({
    required String modelPath,
    required int contextSize,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.55,
    int maxTokens = 768,
    bool thinkingModel = false,
    List<LlamaConversationTurn> conversation = const [],
  }) async* {
    await _ensureLoaded(modelPath, contextSize);
    final messages = [
      LlamaChatMessage.fromText(role: LlamaChatRole.system, text: systemPrompt),
      for (final turn in conversation)
        LlamaChatMessage.fromText(
          role: turn.isUser ? LlamaChatRole.user : LlamaChatRole.assistant,
          text: turn.text,
        ),
      LlamaChatMessage.fromText(role: LlamaChatRole.user, text: userPrompt),
    ];
    await for (final chunk in _engine!.create(
      messages,
      params: GenerationParams(
        maxTokens: maxTokens,
        temp: temperature.clamp(0.0, 2.0),
        topP: 0.9,
        topK: 40,
        penalty: 1.08,
      ),
    )) {
      final text = chunk.choices.first.delta.content;
      final thinking = chunk.choices.first.delta.thinking;
      if ((text?.isNotEmpty ?? false) || (thinking?.isNotEmpty ?? false)) {
        yield LlamaStreamToken(content: text, thinking: thinking);
      }
    }
  }

  Future<List<List<double>>> embedBatch({
    required String modelPath,
    required int contextSize,
    required List<String> texts,
  }) async {
    await _ensureLoaded(modelPath, contextSize);
    return _engine!.embedBatch(texts);
  }

  void cancel() => _engine?.cancelGeneration();

  Future<void> dispose() async {
    await _engine?.dispose();
    _engine = null;
    _loadedModelPath = null;
  }
}

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
  int? _loadedContextSize;

  Future<void> _ensureLoaded(String modelPath, int contextSize) async {
    if (_engine?.isReady == true &&
        _loadedModelPath == modelPath &&
        _loadedContextSize == contextSize) {
      return;
    }
    await _engine?.dispose();
    final engine = LlamaEngine(LlamaBackend());
    await engine.loadModel(
      modelPath,
      modelParams: ModelParams(contextSize: contextSize, gpuLayers: 999),
    );
    _engine = engine;
    _loadedModelPath = modelPath;
    _loadedContextSize = contextSize;
  }

  Future<void> prepareModel(String modelPath, int contextSize) =>
      _ensureLoaded(modelPath, contextSize);

  Future<List<int>> tokenize(String text) async {
    final engine = _engine;
    if (engine == null || !engine.isReady) {
      throw StateError('Model must be prepared before tokenization.');
    }
    return engine.tokenize(text, addSpecial: false);
  }

  Future<String> detokenize(List<int> tokens) async {
    final engine = _engine;
    if (engine == null || !engine.isReady) {
      throw StateError('Model must be prepared before detokenization.');
    }
    return engine.detokenize(tokens);
  }

  Future<int> countChatTokens({
    required String systemPrompt,
    required String userPrompt,
    bool thinkingModel = false,
    List<LlamaConversationTurn> conversation = const [],
  }) async {
    final engine = _engine;
    if (engine == null || !engine.isReady) {
      throw StateError('Model must be prepared before counting tokens.');
    }
    final template = await engine.chatTemplate(
      _messages(systemPrompt, userPrompt, conversation),
      enableThinking: thinkingModel,
      includeTokenCount: true,
    );
    return template.tokenCount ?? engine.getTokenCount(template.prompt);
  }

  Stream<LlamaStreamToken> generate({
    required String modelPath,
    required int contextSize,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.55,
    int maxTokens = 768,
    bool thinkingModel = false,
    String? grammar,
    List<LlamaConversationTurn> conversation = const [],
  }) async* {
    await _ensureLoaded(modelPath, contextSize);
    final messages = _messages(systemPrompt, userPrompt, conversation);
    await for (final chunk in _engine!.create(
      messages,
      params: GenerationParams(
        maxTokens: maxTokens,
        temp: temperature.clamp(0.0, 2.0),
        topP: 0.9,
        topK: 40,
        penalty: 1.08,
        grammar: grammar,
      ),
      enableThinking: thinkingModel,
    )) {
      final text = chunk.choices.first.delta.content;
      final thinking = chunk.choices.first.delta.thinking;
      if ((text?.isNotEmpty ?? false) || (thinking?.isNotEmpty ?? false)) {
        yield LlamaStreamToken(content: text, thinking: thinking);
      }
    }
  }

  List<LlamaChatMessage> _messages(
    String systemPrompt,
    String userPrompt,
    List<LlamaConversationTurn> conversation,
  ) => [
    LlamaChatMessage.fromText(role: LlamaChatRole.system, text: systemPrompt),
    for (final turn in conversation)
      LlamaChatMessage.fromText(
        role: turn.isUser ? LlamaChatRole.user : LlamaChatRole.assistant,
        text: turn.text,
      ),
    LlamaChatMessage.fromText(role: LlamaChatRole.user, text: userPrompt),
  ];

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
    _loadedContextSize = null;
  }
}

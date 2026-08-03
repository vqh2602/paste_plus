
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
  String? _loadedMmprojPath;

  Future<void> _ensureLoaded(
    String modelPath,
    int contextSize, {
    String? mmprojPath,
  }) async {
    final modelChanged =
        _engine?.isReady != true ||
        _loadedModelPath != modelPath ||
        _loadedContextSize != contextSize;

    if (modelChanged) {
      await _engine?.dispose();
      final engine = LlamaEngine(LlamaBackend());
      await engine.loadModel(
        modelPath,
        modelParams: ModelParams(contextSize: contextSize, gpuLayers: 999),
      );
      _engine = engine;
      _loadedModelPath = modelPath;
      _loadedContextSize = contextSize;
      _loadedMmprojPath = null;
    }

    // Load multimodal projector if needed and not yet loaded
    if (mmprojPath != null && mmprojPath != _loadedMmprojPath) {
      try {
        await _engine!.loadMultimodalProjector(mmprojPath);
        _loadedMmprojPath = mmprojPath;
      } catch (_) {
        // Best-effort: if mmproj cannot be loaded, continue in text-only mode
      }
    }
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
    String? mmprojPath,
    List<String> imagePaths = const [],
    List<LlamaConversationTurn> conversation = const [],
  }) async* {
    await _ensureLoaded(modelPath, contextSize, mmprojPath: mmprojPath);
    final messages = _messages(
      systemPrompt,
      userPrompt,
      conversation,
      imagePaths: imagePaths,
    );
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
    List<LlamaConversationTurn> conversation, {
    List<String> imagePaths = const [],
  }) => [
    LlamaChatMessage.fromText(role: LlamaChatRole.system, text: systemPrompt),
    for (final turn in conversation)
      LlamaChatMessage.fromText(
        role: turn.isUser ? LlamaChatRole.user : LlamaChatRole.assistant,
        text: turn.text,
      ),
    if (imagePaths.isNotEmpty)
      LlamaChatMessage.withContent(
        role: LlamaChatRole.user,
        content: [
          for (final path in imagePaths) LlamaImageContent(path: path),
          LlamaTextContent(userPrompt),
        ],
      )
    else
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
    _loadedMmprojPath = null;
  }
}

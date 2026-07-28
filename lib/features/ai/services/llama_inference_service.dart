import 'package:llamadart/llamadart.dart';

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

  Stream<String> generate({
    required String modelPath,
    required int contextSize,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.55,
    int maxTokens = 768,
  }) async* {
    await _ensureLoaded(modelPath, contextSize);
    final messages = [
      LlamaChatMessage.fromText(role: LlamaChatRole.system, text: systemPrompt),
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
      if (text != null && text.isNotEmpty) yield text;
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

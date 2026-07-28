import 'package:clipflow/features/ai/services/ai_token_budget_manager.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> tokenizeRunes(String text) async => text.runes.toList();

Future<String> detokenizeRunes(List<int> tokens) async =>
    String.fromCharCodes(tokens);

void main() {
  late AiTokenBudgetManager manager;

  setUp(() {
    manager = AiTokenBudgetManager(
      tokenize: tokenizeRunes,
      detokenize: detokenizeRunes,
    );
  });

  test('reserves output and safety tokens before accepting a prompt', () {
    final budget = manager.budgetFor(
      contextWindow: 4096,
      requestedOutputTokens: 1000,
    );

    expect(budget.maximumPromptTokens, lessThan(3096));
    expect(budget.accepts(budget.maximumPromptTokens), isTrue);
    expect(budget.accepts(budget.maximumPromptTokens + 1), isFalse);
  });

  test('token chunks preserve every source token exactly once', () async {
    final source = List.generate(180, (index) => '${index % 10}').join();
    final chunks = await manager.chunkText(
      source,
      maximumTokens: 64,
      overlapTokens: 8,
    );

    expect(chunks.map((chunk) => chunk.text).join(), source);
    expect(chunks, hasLength(3));
    expect(chunks.first.leadingContext, isEmpty);
    expect(chunks[1].leadingContext, source.substring(56, 64));
  });

  test('translation and OCR options choose lossless strategies', () {
    expect(
      manager.taskFor(
        intentName: 'clipboardAction',
        prompt: 'dịch nội dung này',
      ),
      AiTokenTask.losslessTranslation,
    );
    expect(
      manager.taskFor(
        intentName: 'clipboardAction',
        prompt: 'xử lý ảnh',
        featureName: 'ocrRefine',
        selectedOption: 'Tóm tắt văn bản từ ảnh',
      ),
      AiTokenTask.hierarchicalSummary,
    );
  });

  test('chat, search, summary and rewrite use separate strategies', () {
    expect(
      manager.taskFor(intentName: 'followUp', prompt: 'nói tiếp'),
      AiTokenTask.rollingChat,
    );
    expect(
      manager.taskFor(intentName: 'clipboardSearch', prompt: 'find URL'),
      AiTokenTask.retrievalQa,
    );
    expect(
      manager.taskFor(
        intentName: 'clipboardAction',
        prompt: 'tóm tắt',
        featureName: 'summary',
      ),
      AiTokenTask.hierarchicalSummary,
    );
    expect(
      manager.taskFor(
        intentName: 'clipboardAction',
        prompt: 'viết lại',
        featureName: 'rewrite',
      ),
      AiTokenTask.contextualRewrite,
    );
  });
}

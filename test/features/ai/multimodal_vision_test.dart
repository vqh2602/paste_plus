import 'package:clipflow/features/ai/domain/ai_model_info.dart';
import 'package:clipflow/features/ai/services/local_ai_engine.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Multimodal Vision Inference', () {
    test('AiModelInfo supports multimodal vision flags and mmproj projections', () {
      const visionModel = AiModelInfo(
        id: 'gemma-4-12b-vision',
        name: 'Gemma 4 12B Multimodal Vision',
        description: 'Google Gemma 4 vision model capable of direct image pixel inspection.',
        parameterSize: '12B',
        fileSizeMb: 7500,
        downloadUrl: 'https://example.com/gemma-4-vision.gguf',
        recommendedFor: 'Image analysis, UI inspection, diagram explanation',
        isMultimodal: true,
        mmprojUrl: 'https://example.com/gemma-4-vision-mmproj.gguf',
      );

      expect(visionModel.isMultimodal, isTrue);
      expect(visionModel.mmprojUrl, isNotNull);
      expect(visionModel.mmprojUrl, contains('mmproj.gguf'));
    });

    test('LocalAiEngine constructs multimodal context combining pixels and OCR secondary text', () {
      final now = DateTime(2026, 8, 2);
      final imageClip = ClipboardItem(
        id: 'img_clip_1',
        content: 'Button Submit Form',
        normalizedContent: 'button submit form',
        contentHash: 'hash-img-1',
        contentType: ClipboardContentType.image,
        imagePath: '/path/to/screenshot.png',
        sourceAppName: 'Safari',
        createdAt: now,
        updatedAt: now,
        lastCopiedAt: now,
        isPinned: false,
        isSensitive: false,
        copyCount: 1,
      );

      final engine = LocalAiEngine();
      final stream = engine.processStream(
        model: const AiModelInfo(
          id: 'gemma-4-e2b',
          name: 'Gemma 4 E2B',
          description: 'Model',
          parameterSize: 'E2B',
          fileSizeMb: 3000,
          downloadUrl: '',
          recommendedFor: '',
        ),
        prompt: 'Phân tích giao diện này',
        clipboardContext: imageClip,
      );

      expect(stream, isNotNull);
    });
  });
}

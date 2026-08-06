import 'package:clipflow/features/ai/domain/ai_model_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('vision capability must reflect a real projector', () {
    test('a model without mmprojUrl is not treated as vision capable', () {
      // gemma-4-e2b/e4b declare the image modality but ship no projector, so
      // llama.cpp cannot read pixels. Claiming vision made image questions
      // fall back to OCR silently and look like the AI was broken.
      for (final id in const ['gemma-4-e2b', 'gemma-4-e4b']) {
        final model = AiModelInfo.findById(id);
        expect(model.mmprojUrl, isNull, reason: '$id unexpectedly has mmproj');
        expect(
          model.isMultimodalVision,
          isFalse,
          reason: '$id must not claim vision without a projector',
        );
      }
    });

    test('models shipping a projector remain vision capable', () {
      for (final id in const ['gemma-4-12b-vision', 'qwen2.5-vl-7b']) {
        final model = AiModelInfo.findById(id);
        expect(model.mmprojUrl, isNotNull);
        expect(model.isMultimodalVision, isTrue);
      }
    });

    test('every vision model exposes a downloadable projector', () {
      final visionModels = AiModelInfo.thinkingModels.where(
        (model) => model.isMultimodalVision,
      );
      expect(visionModels, isNotEmpty);
      for (final model in visionModels) {
        expect(
          model.mmprojUrl,
          isNotNull,
          reason: '${model.id} claims vision but cannot fetch a projector',
        );
        expect(model.supportedModalities, contains(AiModality.image));
      }
    });
  });
}


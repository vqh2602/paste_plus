sealed class AiFeatureRequest {
  const AiFeatureRequest();
}

class AiTranslateRequest extends AiFeatureRequest {
  const AiTranslateRequest({
    required this.targetLocaleTag,
    this.sourceLocaleTag,
  });

  final String targetLocaleTag;
  final String? sourceLocaleTag;
}

enum AiRewriteStyle { concise, professional, friendly, formal }

extension AiRewriteStylePrompt on AiRewriteStyle {
  String get promptValue => switch (this) {
    AiRewriteStyle.concise => 'concise',
    AiRewriteStyle.professional => 'professional',
    AiRewriteStyle.friendly => 'friendly',
    AiRewriteStyle.formal => 'formal',
  };
}

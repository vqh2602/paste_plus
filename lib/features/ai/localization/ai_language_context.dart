import 'package:flutter/widgets.dart';

enum AiResponseLanguageMode { matchUser, appLanguage, fixed }

class AiLanguageContext {
  const AiLanguageContext({
    required this.appLocale,
    required this.responseMode,
    this.detectedInputTag,
    this.explicitResponseTag,
    this.translationTargetTag,
    this.fixedResponseTag,
  });

  final Locale appLocale;
  final AiResponseLanguageMode responseMode;
  final String? detectedInputTag;
  final String? explicitResponseTag;
  final String? translationTargetTag;
  final String? fixedResponseTag;
}

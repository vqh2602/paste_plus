import 'package:flutter/cupertino.dart';

import '../localization/ai_locale_spec.dart';

enum AiFeatureGroup {
  rewrite,
  grammar,
  summary,
  translate,
  smartReply,
  generate,
  qa,
  codeExplain,
  extractInfo,
  titlesTags,
  classify,
  ocrRefine,
}

extension AiFeatureGroupX on AiFeatureGroup {
  String get title {
    return switch (this) {
      AiFeatureGroup.rewrite => 'Rewrite Content',
      AiFeatureGroup.grammar => 'Fix Spelling & Grammar',
      AiFeatureGroup.summary => 'Summarize Content',
      AiFeatureGroup.translate => 'Translate Text',
      AiFeatureGroup.smartReply => 'Smart Reply',
      AiFeatureGroup.generate => 'Generate Content',
      AiFeatureGroup.qa => 'Q&A with Clipboard',
      AiFeatureGroup.codeExplain => 'Explain Code & Errors',
      AiFeatureGroup.extractInfo => 'Extract Information',
      AiFeatureGroup.titlesTags => 'Titles & Tags',
      AiFeatureGroup.classify => 'Smart Classification',
      AiFeatureGroup.ocrRefine => 'Refine Image Text',
    };
  }

  String get subtitle {
    return switch (this) {
      AiFeatureGroup.rewrite =>
        'Rewrite in natural, professional, concise, or polite tone...',
      AiFeatureGroup.grammar =>
        'Fix spelling, grammar, awkward phrasing while preserving meaning.',
      AiFeatureGroup.summary =>
        'Condense long paragraphs into brief summaries, key points, or TODO lists.',
      AiFeatureGroup.translate =>
        'Translate between English, Vietnamese or auto-detect source language.',
      AiFeatureGroup.smartReply =>
        'Generate context-aware responses (Agree, Polite decline, Request info...).',
      AiFeatureGroup.generate =>
        'Draft emails, messages, posts, descriptions, task lists...',
      AiFeatureGroup.qa =>
        'Ask direct questions about meaning, solutions, or actions for content.',
      AiFeatureGroup.codeExplain =>
        'Explain code, analyze error logs, suggest causes & fixes.',
      AiFeatureGroup.extractInfo =>
        'Extract Names, Phones, Emails, Dates, URLs into JSON / Tables.',
      AiFeatureGroup.titlesTags =>
        'Generate short titles, search keywords, collection tags.',
      AiFeatureGroup.classify =>
        'Auto-detect categories: Work, Personal, Code, Email, Shopping...',
      AiFeatureGroup.ocrRefine =>
        'Clean up OCR recognition errors, fix typos and summarize text from images.',
    };
  }

  IconData get icon {
    return switch (this) {
      AiFeatureGroup.rewrite => CupertinoIcons.pencil_outline,
      AiFeatureGroup.grammar => CupertinoIcons.checkmark_seal,
      AiFeatureGroup.summary => CupertinoIcons.doc_text_search,
      AiFeatureGroup.translate => CupertinoIcons.globe,
      AiFeatureGroup.smartReply => CupertinoIcons.reply,
      AiFeatureGroup.generate => CupertinoIcons.sparkles,
      AiFeatureGroup.qa => CupertinoIcons.question_circle,
      AiFeatureGroup.codeExplain =>
        CupertinoIcons.chevron_left_slash_chevron_right,
      AiFeatureGroup.extractInfo => CupertinoIcons.list_bullet_indent,
      AiFeatureGroup.titlesTags => CupertinoIcons.tag,
      AiFeatureGroup.classify => CupertinoIcons.folder_badge_plus,
      AiFeatureGroup.ocrRefine => CupertinoIcons.camera_viewfinder,
    };
  }

  List<String> get options {
    return switch (this) {
      AiFeatureGroup.rewrite => [
        'More natural',
        'More professional',
        'More concise',
        'More polite',
        'Easier to understand',
        'Send Email',
        'Social Media Post',
      ],
      AiFeatureGroup.grammar => [
        'Fix all errors',
        'Fix spelling only',
        'Optimize punctuation',
        'Simplify sentences',
      ],
      AiFeatureGroup.summary => [
        'Brief summary',
        'Key points',
        'Action items',
        'Extract key information',
      ],
      AiFeatureGroup.translate => AiLanguageRegistry.languages.keys.toList(),
      AiFeatureGroup.smartReply => [
        'Agree',
        'Polite decline',
        'Request more information',
      ],
      AiFeatureGroup.generate => [
        'Email',
        'Message',
        'Social post',
        'Task list',
      ],
      AiFeatureGroup.qa => ['Ask about this content'],
      AiFeatureGroup.codeExplain => [
        'Explain code',
        'Find the error',
        'Suggest a fix',
      ],
      AiFeatureGroup.extractInfo => ['JSON', 'Table'],
      AiFeatureGroup.titlesTags => ['Title and tags'],
      AiFeatureGroup.classify => ['Auto classify'],
      AiFeatureGroup.ocrRefine => ['Clean OCR text'],
    };
  }

  String optionLabel(String value) {
    if (this != AiFeatureGroup.translate) return value;
    final language = AiLanguageRegistry.languages[value];
    return language == null
        ? value
        : '${language.nativeName} (${language.englishName})';
  }
}

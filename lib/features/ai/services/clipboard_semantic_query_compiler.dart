import '../domain/clipboard_search_query_draft.dart';

/// Fast deterministic compiler used before any semantic/embedding search.
/// A utility-model JSON draft can be passed through the same validator, while
/// this compiler guarantees the common multilingual app commands offline.
class ClipboardSemanticQueryCompiler {
  const ClipboardSemanticQueryCompiler();

  ClipboardSearchQueryDraft compile(String request) {
    final raw = request.trim();
    final lower = raw.toLowerCase();
    final contentTypes = <String>[];
    var containsUrl = _has(lower, _urlWords) ? true : null;
    String? urlKind;
    final isImagePhrase = _has(lower, _imageWords);
    final isFilePhrase = _has(lower, _fileWords);
    if (isImagePhrase && containsUrl == true) {
      urlKind = 'image';
    } else if (isImagePhrase) {
      contentTypes.add('image');
    }
    if (_has(lower, _codeWords)) contentTypes.add('code');
    if (_has(lower, _jsonWords)) contentTypes.add('json');
    if (_has(lower, _emailWords)) contentTypes.add('email');
    if (_has(lower, _phoneWords)) contentTypes.add('phone');
    if (isFilePhrase && !isImagePhrase) contentTypes.add('file');
    if (containsUrl == true && urlKind == null && _onlyUrlType(lower)) {
      // URL is a feature filter, not a literal text query.
      containsUrl = true;
    }

    final hosts = <String>[];
    if (lower.contains('github')) hosts.add('github.com');
    if (lower.contains('gitlab')) hosts.add('gitlab.com');
    final explicitHosts = RegExp(
      r'\b(?:https?://)?(?:www\.)?([a-z0-9-]+(?:\.[a-z0-9-]+)+)\b',
      caseSensitive: false,
    ).allMatches(lower);
    for (final match in explicitHosts) {
      final host = match.group(1);
      if (host != null && !hosts.contains(host)) hosts.add(host);
    }

    String? datePreset;
    if (_has(lower, _yesterdayWords)) {
      datePreset = 'yesterday';
    } else if (_has(lower, _todayWords)) {
      datePreset = 'today';
    } else if (_has(lower, _last7Words)) {
      datePreset = 'last_7_days';
    } else if (_has(lower, _last30Words)) {
      datePreset = 'last_30_days';
    }

    final sourceApps = <String>[];
    for (final app in const ['Chrome', 'Safari', 'Firefox', 'Edge', 'Arc', 'Slack', 'Discord', 'Xcode', 'Android Studio']) {
      if (lower.contains(app.toLowerCase())) sourceApps.add(app);
    }
    final extensions = <String>[];
    for (final match in RegExp(r'\b(?:file\s+)?(?:\.|\*)([a-z0-9]{2,8})\b').allMatches(lower)) {
      final extension = match.group(1);
      if (extension != null && _knownExtensions.contains(extension)) extensions.add(extension);
    }
    if (isFilePhrase && isImagePhrase) {
      contentTypes
        ..remove('image')
        ..add('file');
      extensions.addAll(const ['png', 'jpg', 'jpeg', 'webp', 'gif']);
      containsUrl = null;
      urlKind = null;
    }

    final pinned = _has(lower, _pinnedWords) ? true : null;
    final textQuery = _extractSubject(
      raw,
      sourceApps: sourceApps,
      hosts: hosts,
    );
    return ClipboardSearchQueryDraft(
      contentTypes: contentTypes.toSet().toList(),
      containsUrl: containsUrl,
      urlHosts: hosts,
      urlKind: urlKind,
      textQuery: textQuery,
      sourceApps: sourceApps,
      fileExtensions: extensions.toSet().toList(),
      datePreset: datePreset,
      pinned: pinned,
      sort: 'newest',
      limit: 30,
      confidence: 0.94,
    );
  }

  bool looksLikeClipboardSearch(String request) {
    final lower = request.toLowerCase();
    // Never steal general conversation: an explain/define question is chat,
    // even when it mentions a clipboard type word such as "link" or "code".
    if (_has(lower, _explanationWords)) return false;
    // Composition/transformation verbs mean the user wants new content, not a
    // lookup ("viết cho tôi một email", "write me an email").
    if (_has(lower, _compositionWords)) return false;

    final hasHost =
        lower.contains('github') || lower.contains('gitlab');
    final hasFilter = _has(lower, _typeWords) ||
        _has(lower, _pinnedWords) ||
        _has(lower, _todayWords) ||
        _has(lower, _yesterdayWords) ||
        hasHost;
    final hasClipboardNoun = _has(lower, _clipboardWords);

    // Explicit command: "tìm ảnh", "show links", "search clipboard".
    if (_has(lower, _searchWords) && (hasClipboardNoun || hasFilter)) {
      return true;
    }

    // Verb-less retrieval is still a search when the user names a clipboard
    // filter together with a retrieval marker ("các link tôi đã copy",
    // "liệt kê link", "lấy hết url ra", "links?").
    if ((hasFilter || hasClipboardNoun) &&
        (hasHost || _has(lower, _retrievalMarkers))) {
      return true;
    }
    return false;
  }

  String? _extractSubject(
    String raw, {
    required List<String> sourceApps,
    required List<String> hosts,
  }) {
    var value = raw;
    final removable = <RegExp>[
      ..._semanticPhrases.map((phrase) => RegExp(RegExp.escape(phrase), caseSensitive: false)),
      RegExp(r'\b(?:github|gitlab)(?:\.com)?\b', caseSensitive: false),
      RegExp(r'\b(?:today|yesterday|hôm nay|hôm qua|gestern|heute)\b', caseSensitive: false),
      RegExp(r'\b(?:last|past)\s+(?:7|seven|30|thirty)\s+days?\b', caseSensitive: false),
      RegExp(r'\b(?:tuần trước|7 ngày qua|30 ngày qua|letzte woche)\b', caseSensitive: false),
    ];
    for (final app in sourceApps) {
      removable.add(RegExp(RegExp.escape(app), caseSensitive: false));
    }
    for (final host in hosts) {
      removable.add(RegExp(RegExp.escape(host), caseSensitive: false));
    }
    for (final pattern in removable) {
      value = value.replaceAll(pattern, ' ');
    }
    value = value
        .replaceAll(RegExp(r"""[、。,.!?;:："'()]"""), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Phrase removal can leave orphan fragments (for example the plural "s" of
    // "links"), so keep only tokens that can plausibly be real subject matter.
    final tokens = value.split(RegExp(r'\s+')).where((token) {
      final normalized = token.toLowerCase().trim();
      if (normalized.isEmpty) return false;
      if (_fillerTokens.contains(normalized)) return false;
      final isLatin = RegExp(r'^[a-zà-ỹ]+$', caseSensitive: false)
          .hasMatch(normalized);
      if (isLatin && normalized.length <= 2) return false;
      // A lone Hangul/kana character left behind by phrase removal is a
      // grammatical particle, not a searchable subject.
      if (normalized.length == 1 &&
          RegExp(r'[\u3040-\u30ff\uac00-\ud7af]').hasMatch(normalized)) {
        return false;
      }
      return RegExp(r'[a-z0-9à-ỹ\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]',
              caseSensitive: false)
          .hasMatch(normalized);
    }).toList();
    if (tokens.isEmpty) return null;
    return tokens.join(' ');
  }

  bool _onlyUrlType(String lower) => _has(lower, _urlWords);
  bool _has(String value, Iterable<String> terms) => terms.any(value.contains);

  static const _searchWords = [
    'tìm', 'kiếm', 'cho tôi', 'hiển thị', 'show', 'find', 'search', 'list',
    '探して', '検索', '見せて', '찾아', '검색', '보여', 'finden', 'suche', 'zeig',
  ];
  static const _clipboardWords = [
    'clipboard', 'clip ', 'history', 'lịch sử', 'đã copy', 'copied',
    'コピー', 'クリップボード', '클립보드', '복사', 'zwischenablage', 'kopiert',
  ];
  static const _imageWords = [
    'ảnh', 'hình', 'image', 'picture', 'photo', '画像', '写真', '이미지', '사진',
    'bild', 'foto',
  ];
  static const _urlWords = [
    'link', 'url', 'đường dẫn', 'website', 'liên kết',
    'リンク', '링크', 'verknüpfung', 'verlinkung',
  ];
  static const _codeWords = ['code', 'mã nguồn', 'đoạn mã', 'コード', '코드', 'quellcode'];
  static const _jsonWords = ['json'];
  static const _fileWords = ['file', 'tệp', 'ファイル', '파일', 'datei'];
  static const _emailWords = ['email', 'e-mail', 'メール', '이메일'];
  static const _phoneWords = ['phone', 'số điện thoại', '電話', '전화번호', 'telefonnummer'];
  static const _pinnedWords = ['đã ghim', 'pinned', 'ピン留め', '고정', 'angeheftet'];
  /// Retrieval markers that make a verb-less request a clipboard lookup.
  static const _retrievalMarkers = [
    'các', 'những', 'mấy', 'hết', 'tất cả', 'nào', 'bao nhiêu', 'liệt kê',
    'đã copy', 'vừa copy', 'đã lưu', 'lấy', 'kê',
    'all', 'any', 'how many', 'list', 'copied', 'saved', 'my',
    '一覧', 'すべて', 'いくつ', 'コピーした',
    '전체', '모두', '몇', '복사한', '목록',
    'alle', 'wie viele', 'liste', 'kopiert', 'meine',
  ];
  /// Question words that mean the user wants an explanation, not a lookup.
  static const _compositionWords = [
    'viết', 'soạn', 'tạo giúp', 'dịch', 'tóm tắt', 'sửa lại', 'viết lại',
    'write', 'compose', 'draft', 'translate', 'summarize', 'rewrite', 'fix',
    '書いて', '作成', '翻訳', '要約',
    '작성', '번역', '요약',
    'schreibe', 'verfasse', 'übersetze', 'zusammenfassen',
  ];
  static const _explanationWords = [
    'là gì', 'nghĩa là', 'giải thích', 'tại sao', 'vì sao', 'cách nào',
    'làm sao', 'hướng dẫn',
    'what is', 'what are', 'explain', 'why', 'how do', 'how to',
    'meaning of', 'define',
    'とは', 'なぜ', '説明', 'どうやって',
    '무엇', '왜', '설명', '어떻게',
    'was ist', 'warum', 'erkläre', 'erklären', 'wie kann',
  ];
  static const _todayWords = ['hôm nay', 'today', '今日', '오늘', 'heute'];
  static const _yesterdayWords = ['hôm qua', 'yesterday', '昨日', '어제', 'gestern'];
  static const _last7Words = ['7 ngày qua', 'tuần trước', 'last 7 days', 'past week', '過去7日', '지난 7일', 'letzte woche'];
  static const _last30Words = ['30 ngày qua', 'last 30 days', '過去30日', '지난 30일', 'letzten 30 tage'];
  static const _typeWords = [
    ..._imageWords, ..._urlWords, ..._codeWords, ..._jsonWords, ..._fileWords,
    ..._emailWords, ..._phoneWords,
  ];
  static const _semanticPhrases = [
    ..._searchWords,
    ..._clipboardWords,
    ..._typeWords,
    ..._pinnedWords,
    ..._retrievalMarkers,
    'có chứa', 'chứa', 'có chữ', 'có', 'với', 'từ', 'các', 'những', 'mục',
    'containing', 'contains', 'with', 'from', 'items', 'copied',
    'を含む', 'から', 'の', 'を', 'が', '있는', '포함', '에서',
    'mit', 'enthält', 'aus', 'die', 'der', 'das',
  ];
  static const _knownExtensions = {
    'pdf', 'png', 'jpg', 'jpeg', 'webp', 'gif', 'svg', 'txt', 'md', 'json',
    'dart', 'js', 'ts', 'zip', 'csv',
  };
  /// Tokens that only express an app operation or grammar, never subject matter.
  static const _fillerTokens = {
    'me', 'my', 'the', 'a', 'an', 'all', 'any', 'some', 'please', 'give',
    'copied', 'copy', 'item', 'items', 'entry', 'entries', 'recent',
    'tôi', 'của', 'giúp', 'hãy', 'nào', 'đã', 'cái', 'gì',
    'mir', 'mich', 'bitte', 'zeige', 'meine', 'kopierte', 'kopierten',
    '된', '있는', '해줘', '주세요', 'して', 'ください',
  };
}

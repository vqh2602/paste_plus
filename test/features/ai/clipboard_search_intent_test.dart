import 'package:clipflow/features/ai/services/clipboard_semantic_query_compiler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const compiler = ClipboardSemanticQueryCompiler();

  group('clipboard lookups reach the deterministic agent', () {
    const lookups = [
      'tìm ảnh',
      'tìm clipboard có link',
      'cho tôi các link',
      // Verb-less retrieval: the earlier gate required an explicit search verb
      // and sent all of these to the generic LLM path instead.
      'các link tôi đã copy',
      'link nào tôi vừa copy',
      'liệt kê link',
      'có bao nhiêu link',
      'lấy hết url ra',
      'url github',
      'copy link nào có github',
      'show links',
      'all links I copied',
      'how many links do I have',
      'コピーしたリンク一覧',
      '복사한 링크 전체',
      'alle kopierten Links',
    ];

    for (final prompt in lookups) {
      test('"$prompt" is treated as a clipboard search', () {
        expect(compiler.looksLikeClipboardSearch(prompt), isTrue);
      });
    }

    test('url lookups never leak a literal keyword into textQuery', () {
      for (final prompt in lookups) {
        final draft = compiler.compile(prompt);
        final text = draft.textQuery?.toLowerCase();
        if (text == null) continue;
        for (final noise in const [
          'link',
          'url',
          'liệt',
          'bao nhiêu',
          'lấy',
          'hết',
          'copy',
        ]) {
          expect(
            text,
            isNot(contains(noise)),
            reason: 'navigation word "$noise" leaked from "$prompt"',
          );
        }
      }
    });
  });

  group('ordinary conversation is never hijacked', () {
    const chat = [
      'xin chào',
      'cảm ơn bạn',
      'link là gì',
      'giải thích cho tôi url hoạt động thế nào',
      'what is a link',
      'why do links break',
      'explain how urls work',
      'dịch đoạn này sang tiếng Anh',
      'viết cho tôi một email',
      'write me an email',
      'tóm tắt nội dung này',
      'code này bị lỗi gì',
      'リンクとは何ですか',
      '링크가 무엇인가요',
      'was ist ein Link',
    ];

    for (final prompt in chat) {
      test('"$prompt" stays on the chat path', () {
        expect(compiler.looksLikeClipboardSearch(prompt), isFalse);
      });
    }
  });
}


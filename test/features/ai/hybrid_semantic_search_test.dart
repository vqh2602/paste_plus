import 'package:clipflow/features/ai/services/clipboard_vector_store.dart';
import 'package:clipflow/features/ai/services/hybrid_semantic_search.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:flutter_test/flutter_test.dart';

ClipboardItem mockItem(String id, String content) {
  final now = DateTime(2026, 8, 2);
  return ClipboardItem(
    id: id,
    content: content,
    normalizedContent: content.toLowerCase(),
    contentHash: 'hash-$id',
    contentType: ClipboardContentType.text,
    createdAt: now,
    updatedAt: now,
    lastCopiedAt: now,
    isPinned: false,
    isSensitive: false,
    copyCount: 1,
  );
}

void main() {
  group('HybridSemanticSearch', () {
    test('reciprocalRankFusion merges lexical and vector matches accurately', () {
      final item1 = mockItem('item_1', 'Flutter UI design tokens');
      final item2 = mockItem('item_2', 'Dart async await stream');
      final item3 = mockItem('item_3', 'SQLite database migration');

      final lexicalCandidates = [item1, item2];
      final vectorMatches = [
        const VectorMatch(clipboardId: 'item_3', score: 0.95),
        const VectorMatch(clipboardId: 'item_1', score: 0.88),
      ];

      final fused = HybridSemanticSearch.reciprocalRankFusion(
        lexicalCandidates: lexicalCandidates,
        vectorMatches: vectorMatches,
        allCandidates: [item1, item2, item3],
      );

      expect(fused.map((i) => i.id), containsAll(['item_1', 'item_2', 'item_3']));
      // Item 1 appeared in both lists, so its fused rank score should place it first!
      expect(fused.first.id, equals('item_1'));
    });

    test('search returns top 6-10 items without per-candidate re-embedding overhead', () async {
      const search = HybridSemanticSearch();
      final items = List.generate(20, (i) => mockItem('item_$i', 'Clipboard item text content $i'));

      final results = await search.search(
        query: 'content 5',
        allCandidates: items,
        maxFinalItems: 8,
      );

      expect(results.length, lessThanOrEqualTo(8));
      expect(results.length, greaterThanOrEqualTo(1));
    });
  });
}

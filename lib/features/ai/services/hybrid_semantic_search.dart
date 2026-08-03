import '../../../core/database/app_database.dart';
import '../../clipboard_history/domain/clipboard_item.dart';
import 'ai_clipboard_relevance_ranker.dart';
import 'clipboard_vector_store.dart';

/// Implements Hybrid RAG retrieval: Lexical FTS5 + Pre-computed Vector Search + RRF + Reranker.
class HybridSemanticSearch {
  const HybridSemanticSearch([
    this._vectorStore,
    this._database,
    this._ranker = const AiClipboardRelevanceRanker(),
  ]);

  final ClipboardVectorStore? _vectorStore;
  final AppDatabase? _database;
  final AiClipboardRelevanceRanker _ranker;

  /// Executes hybrid candidate retrieval and returns the top 6 to 10 candidates.
  Future<List<ClipboardItem>> search({
    required String query,
    required List<ClipboardItem> allCandidates,
    List<double>? queryVector,
    String modelId = 'gemma-4-e2b',
    int maxFinalItems = 10,
  }) async {
    if (allCandidates.isEmpty) return const [];

    // 1. Lexical candidate selection (Top 50) using FTS5 if available
    final lexicalCandidates = await _lexicalSearch(query, allCandidates, limit: 50);

    // 2. Vector candidate selection (Top 30) using pre-computed vector store
    List<VectorMatch> vectorMatches = const [];
    if (_vectorStore != null && queryVector != null && queryVector.isNotEmpty) {
      vectorMatches = await _vectorStore.findVectorMatches(
        queryVector: queryVector,
        modelId: modelId,
        limit: 30,
      );
    }

    // 3. Reciprocal Rank Fusion (RRF)
    final fusedCandidates = reciprocalRankFusion(
      lexicalCandidates: lexicalCandidates,
      vectorMatches: vectorMatches,
      allCandidates: allCandidates,
    );

    // 4. Final Reranking to select top 6-10 items for LLM context
    final reranked = _ranker.rank(
      prompt: query,
      items: fusedCandidates,
    ).take(maxFinalItems.clamp(6, 10)).toList();

    return reranked;
  }

  Future<List<ClipboardItem>> _lexicalSearch(
    String query,
    List<ClipboardItem> items, {
    int limit = 50,
  }) async {
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) return items.take(limit).toList();

    final db = _database?.database;
    if (db != null) {
      try {
        final sanitizedQuery = lowerQuery
            .split(RegExp(r'[^\p{L}\p{N}_]+', unicode: true))
            .where((w) => w.isNotEmpty)
            .map((w) => '"${w.replaceAll('"', '""')}"*')
            .join(' OR ');

        if (sanitizedQuery.isNotEmpty) {
          final ftsRows = await db.rawQuery(
            'SELECT clipboard_id FROM clipboard_items_fts WHERE clipboard_items_fts MATCH ? LIMIT ?',
            [sanitizedQuery, limit],
          );

          final itemMap = {for (final item in items) item.id: item};
          final matches = <ClipboardItem>[];
          for (final row in ftsRows) {
            final id = row['clipboard_id'] as String?;
            if (id != null && itemMap.containsKey(id)) {
              matches.add(itemMap[id]!);
            }
          }
          if (matches.isNotEmpty) return matches;
        }
      } catch (_) {
        // Fall back to in-memory matching if FTS search encounters edge case syntax error or missing module
      }
    }

    final queryWords = lowerQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();

    final scored = items.map((item) {
      final content = item.normalizedContent;
      var score = 0.0;
      for (final word in queryWords) {
        if (content.contains(word)) score += 1.0;
      }
      return (item: item, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.item).toList();
  }

  /// Merges lexical ranks and vector ranks using Reciprocal Rank Fusion formula:
  /// RRF_score(d) = 1 / (60 + r_fts(d)) + 1 / (60 + r_vec(d))
  static List<ClipboardItem> reciprocalRankFusion({
    required List<ClipboardItem> lexicalCandidates,
    required List<VectorMatch> vectorMatches,
    required List<ClipboardItem> allCandidates,
  }) {
    final itemMap = {for (final item in allCandidates) item.id: item};
    final rrfScores = <String, double>{};
    const k = 60.0;

    for (var index = 0; index < lexicalCandidates.length; index++) {
      final id = lexicalCandidates[index].id;
      final rank = index + 1;
      rrfScores[id] = (rrfScores[id] ?? 0.0) + (1.0 / (k + rank));
    }

    for (var index = 0; index < vectorMatches.length; index++) {
      final id = vectorMatches[index].clipboardId;
      final rank = index + 1;
      rrfScores[id] = (rrfScores[id] ?? 0.0) + (1.0 / (k + rank));
    }

    final sortedEntries = rrfScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final results = <ClipboardItem>[];
    for (final entry in sortedEntries) {
      if (itemMap.containsKey(entry.key)) {
        results.add(itemMap[entry.key]!);
      }
    }

    return results.isNotEmpty ? results : lexicalCandidates;
  }
}

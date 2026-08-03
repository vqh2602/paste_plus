import 'dart:async';

import '../../clipboard_history/domain/clipboard_item.dart';
import 'clipboard_vector_store.dart';

/// Background queue indexer for clipboard item vector embeddings.
class ClipboardEmbeddingIndexer {
  ClipboardEmbeddingIndexer({
    required ClipboardVectorStore vectorStore,
    required Future<List<double>> Function(String text) embedder,
    required String modelId,
  }) : _vectorStore = vectorStore,
       _embedder = embedder,
       _modelId = modelId;

  final ClipboardVectorStore _vectorStore;
  final Future<List<double>> Function(String text) _embedder;
  final String _modelId;
  final List<ClipboardItem> _queue = [];
  bool _isProcessing = false;

  /// Enqueues a newly stored or updated [ClipboardItem] for vector indexing.
  Future<void> enqueue(ClipboardItem item) async {
    if (item.isSensitive || item.content.trim().isEmpty) return;

    // Fast check: Check if embedding vector for identical content hash is already cached in SQLite
    final existing = await _vectorStore.findByHash(
      contentHash: item.contentHash,
      modelId: _modelId,
    );

    if (existing != null) {
      await _vectorStore.attachExistingVector(
        clipboardId: item.id,
        contentHash: item.contentHash,
        modelId: _modelId,
        existingVector: existing,
      );
      return;
    }

    _queue.add(item);
    await _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;

    try {
      while (_queue.isNotEmpty) {
        final item = _queue.removeAt(0);
        await _vectorStore.indexClipboardItem(
          item: item,
          modelId: _modelId,
          embedder: _embedder,
        );
      }
    } catch (_) {
      // Background indexing non-blocking error handler
    } finally {
      _isProcessing = false;
    }
  }
}

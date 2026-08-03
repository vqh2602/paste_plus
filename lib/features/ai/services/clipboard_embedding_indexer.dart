import 'dart:async';

import '../../clipboard_history/domain/clipboard_item.dart';
import 'clipboard_vector_store.dart';

/// Background queue indexer for clipboard item vector embeddings.
class ClipboardEmbeddingIndexer {
  ClipboardEmbeddingIndexer({
    required ClipboardVectorStore vectorStore,
  }) : _vectorStore = vectorStore;

  final ClipboardVectorStore _vectorStore;
  final List<ClipboardItem> _queue = [];
  bool _isProcessing = false;

  /// Enqueues a newly stored or updated [ClipboardItem] for vector indexing.
  Future<void> enqueue(ClipboardItem item, {String modelId = 'gemma-4-e2b'}) async {
    if (item.isSensitive || item.content.trim().isEmpty) return;

    // Fast check: Check if embedding vector for identical content hash is already cached in SQLite
    final existing = await _vectorStore.findByHash(
      contentHash: item.contentHash,
      modelId: modelId,
    );

    if (existing != null) {
      await _vectorStore.attachExistingVector(
        clipboardId: item.id,
        contentHash: item.contentHash,
        modelId: modelId,
        existingVector: existing,
      );
      return;
    }

    _queue.add(item);
    _processQueue(modelId);
  }

  void _processQueue(String modelId) async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;

    try {
      while (_queue.isNotEmpty) {
        final item = _queue.removeAt(0);
        final existing = await _vectorStore.findByHash(
          contentHash: item.contentHash,
          modelId: modelId,
        );
        if (existing != null) {
          await _vectorStore.attachExistingVector(
            clipboardId: item.id,
            contentHash: item.contentHash,
            modelId: modelId,
            existingVector: existing,
          );
        }
      }
    } catch (_) {
      // Background indexing non-blocking error handler
    } finally {
      _isProcessing = false;
    }
  }
}

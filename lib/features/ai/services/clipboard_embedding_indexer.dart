import 'dart:async';

import '../../clipboard_history/domain/clipboard_item.dart';
import 'clipboard_vector_store.dart';

/// Background queue indexer for clipboard item vector embeddings.
class ClipboardEmbeddingIndexer {
  ClipboardEmbeddingIndexer({
    required ClipboardVectorStore vectorStore,
    required Future<List<double>> Function(String text) embedder,
    required String modelId,
    bool Function()? isBusy,
  }) : _vectorStore = vectorStore,
       _embedder = embedder,
       _modelId = modelId,
       _isBusy = isBusy ?? _neverBusy;

  final ClipboardVectorStore _vectorStore;
  final Future<List<double>> Function(String text) _embedder;
  final String _modelId;
  final bool Function() _isBusy;
  final List<ClipboardItem> _queue = [];
  bool _isProcessing = false;
  Timer? _retryTimer;

  static bool _neverBusy() => false;

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
    if (_isBusy()) {
      _retryTimer ??= Timer(const Duration(seconds: 2), () {
        _retryTimer = null;
        unawaited(_processQueue());
      });
      return;
    }
    _isProcessing = true;

    try {
      while (_queue.isNotEmpty) {
        if (_isBusy()) break;
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
      if (_queue.isNotEmpty) unawaited(_processQueue());
    }
  }
}

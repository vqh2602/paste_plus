import '../../settings/domain/app_settings.dart';
import 'clipboard_content_type.dart';
import 'clipboard_item.dart';
import 'clipboard_payload.dart';
import 'search_query.dart';

abstract interface class ClipboardRepository {
  Future<List<ClipboardItem>> getItems({
    bool pinnedOnly = false,
    ClipboardContentType? type,
    String? collectionId,
    int limit = 2000,
  });

  Future<ClipboardItem?> store(ClipboardPayload payload, AppSettings settings);

  Future<void> markCopied(String id);
  Future<void> setPinned(String id, bool pinned);
  Future<void> updateMetadata(String id, String metadataJson);
  Future<void> updateNote(String id, String? note);
  Future<void> deleteItem(String id);
  Future<void> clearHistory({bool includePinned = false});
  Future<List<ClipboardCollection>> getCollections();
  Future<ClipboardCollection> createCollection(String name);
  Future<void> upsertCollection(ClipboardCollection collection);
  Future<void> renameCollection(String id, String name);
  Future<void> deleteCollection(String id);
  Future<void> addToCollection(String itemId, String collectionId);
  Future<void> removeFromCollection(String itemId, String collectionId);
  Future<Set<String>> collectionIdsForItem(String itemId);
  Future<void> cleanup(AppSettings settings);
  Future<int> approximateStorageBytes();
}

class ClipboardSearchPage {
  const ClipboardSearchPage({
    required this.items,
    required this.total,
    required this.hasMore,
  });

  final List<ClipboardItem> items;
  final int total;
  final bool hasMore;
}

/// Optional capability implemented by repositories that can execute deep-agent
/// queries without loading the whole history into Dart.
abstract interface class StructuredClipboardRepository {
  Future<ClipboardSearchPage> search(ClipboardSearchQuery query);
  Future<List<ClipboardItem>> getItemsByIds(List<String> ids);
  Future<void> setPinnedMany(List<String> ids, bool pinned);
  Future<void> deleteItems(List<String> ids);
  Future<void> addItemsToCollection(List<String> itemIds, String collectionId);
  Future<ClipboardCollection?> findCollectionByName(String name);
}

extension DeepClipboardRepository on ClipboardRepository {
  Future<ClipboardSearchPage> searchStructured(ClipboardSearchQuery query) async {
    if (this is StructuredClipboardRepository) {
      return (this as StructuredClipboardRepository).search(query);
    }
    final range = query.dateRange?.resolve(DateTime.now());
    final all = await getItems(limit: 2000);
    var items = all.where((item) {
      if (!query.includeSensitive && item.isSensitive) return false;
      if (query.contentTypes.isNotEmpty &&
          !query.contentTypes.contains(item.contentType)) {
        return false;
      }
      if (query.containsUrl == true && !item.containsUrl &&
          !RegExp(r'https?://|www\.', caseSensitive: false).hasMatch(item.content)) {
        return false;
      }
      if (query.urlHosts.isNotEmpty) {
        final host = item.urlHost?.toLowerCase();
        if (host == null ||
            !query.urlHosts.any((wanted) => host == wanted || host.endsWith('.$wanted'))) {
          return false;
        }
      }
      if (query.sourceApps.isNotEmpty &&
          !query.sourceApps.any((app) =>
              (item.sourceAppName ?? '').toLowerCase().contains(app.toLowerCase()))) {
        return false;
      }
      if (query.fileExtensions.isNotEmpty &&
          !query.fileExtensions.contains(item.fileExtension?.toLowerCase())) {
        return false;
      }
      if (query.pinned != null && item.isPinned != query.pinned) return false;
      if (range?.from != null && item.createdAt.isBefore(range!.from!)) return false;
      if (range?.to != null && !item.createdAt.isBefore(range!.to!)) return false;
      final text = query.textQuery?.trim().toLowerCase();
      if (text?.isNotEmpty == true) {
        final haystack = item.searchableText.isNotEmpty
            ? item.searchableText
            : '${item.content} ${item.note ?? ''} ${item.sourceAppName ?? ''}'.toLowerCase();
        if (!text!.split(RegExp(r'\s+')).every(haystack.contains)) return false;
      }
      return true;
    }).toList();
    items.sort((a, b) => switch (query.sort) {
      ClipboardSort.oldest => a.createdAt.compareTo(b.createdAt),
      ClipboardSort.mostCopied => b.copyCount.compareTo(a.copyCount),
      ClipboardSort.recentlyCopied => b.lastCopiedAt.compareTo(a.lastCopiedAt),
      ClipboardSort.newest => b.createdAt.compareTo(a.createdAt),
    });
    final total = items.length;
    items = items.skip(query.offset).take(query.limit).toList(growable: false);
    return ClipboardSearchPage(
      items: items,
      total: total,
      hasMore: query.offset + items.length < total,
    );
  }

  Future<List<ClipboardItem>> resolveItemsByIds(List<String> ids) async {
    if (this is StructuredClipboardRepository) {
      return (this as StructuredClipboardRepository).getItemsByIds(ids);
    }
    final wanted = ids.toSet();
    final items = await getItems(limit: 2000);
    final byId = {for (final item in items) item.id: item};
    return [for (final id in ids) if (wanted.contains(id) && byId[id] != null) byId[id]!];
  }

  Future<void> setPinnedBatch(List<String> ids, bool pinned) async {
    if (this is StructuredClipboardRepository) {
      return (this as StructuredClipboardRepository).setPinnedMany(ids, pinned);
    }
    for (final id in ids) {
      await setPinned(id, pinned);
    }
  }

  Future<void> deleteBatch(List<String> ids) async {
    if (this is StructuredClipboardRepository) {
      return (this as StructuredClipboardRepository).deleteItems(ids);
    }
    for (final id in ids) {
      await deleteItem(id);
    }
  }

  Future<void> addBatchToCollection(List<String> ids, String collectionId) async {
    if (this is StructuredClipboardRepository) {
      return (this as StructuredClipboardRepository)
          .addItemsToCollection(ids, collectionId);
    }
    for (final id in ids) {
      await addToCollection(id, collectionId);
    }
  }

  Future<ClipboardCollection?> resolveCollectionByName(String name) async {
    if (this is StructuredClipboardRepository) {
      return (this as StructuredClipboardRepository).findCollectionByName(name);
    }
    final normalized = name.trim().toLowerCase();
    final collections = await getCollections();
    for (final collection in collections) {
      if (collection.name.trim().toLowerCase() == normalized ||
          collection.id.toLowerCase() == normalized) {
        return collection;
      }
    }
    return null;
  }
}

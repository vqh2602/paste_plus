import '../../settings/domain/app_settings.dart';
import 'clipboard_content_type.dart';
import 'clipboard_item.dart';
import 'clipboard_payload.dart';

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

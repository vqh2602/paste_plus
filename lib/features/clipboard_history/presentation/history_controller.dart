import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/services/clipboard_watcher.dart';
import '../../../core/services/cloud_upload_service.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/services/translation_service.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/clipboard_content_type.dart';
import '../domain/clipboard_item.dart';
import '../domain/clipboard_payload.dart';
import '../domain/clipboard_repository.dart';
import '../domain/search_query.dart';
import '../domain/url_preview_metadata.dart';
import '../services/url_preview_service.dart';

enum HistorySection { all, pinned, images, links, code, collection }

class ClipboardHistoryState {
  const ClipboardHistoryState({
    this.items = const [],
    this.isLoading = true,
    this.errorMessage,
    this.query = '',
    this.section = HistorySection.all,
    this.collectionId,
    this.typeFilters = const {},
    this.selectedItemId,
    this.hasExplicitSelection = false,
  });

  final List<ClipboardItem> items;
  final bool isLoading;
  final String? errorMessage;
  final String query;
  final HistorySection section;
  final String? collectionId;
  final Set<ClipboardContentType> typeFilters;
  final String? selectedItemId;
  final bool hasExplicitSelection;

  List<ClipboardItem> get visibleItems {
    final parsed = ClipboardSearchQuery.parse(query);
    return items
        .where((item) {
          return (typeFilters.isEmpty ||
                  typeFilters.contains(item.contentType)) &&
              parsed.matches(item);
        })
        .toList(growable: false);
  }

  ClipboardHistoryState copyWith({
    List<ClipboardItem>? items,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? query,
    HistorySection? section,
    String? collectionId,
    bool clearCollection = false,
    Set<ClipboardContentType>? typeFilters,
    bool clearTypeFilter = false,
    String? selectedItemId,
    bool clearSelection = false,
    bool? hasExplicitSelection,
  }) {
    return ClipboardHistoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      query: query ?? this.query,
      section: section ?? this.section,
      collectionId: clearCollection ? null : collectionId ?? this.collectionId,
      typeFilters: clearTypeFilter
          ? const {}
          : Set.unmodifiable(typeFilters ?? this.typeFilters),
      selectedItemId: clearSelection
          ? null
          : selectedItemId ?? this.selectedItemId,
      hasExplicitSelection: clearSelection
          ? false
          : hasExplicitSelection ?? this.hasExplicitSelection,
    );
  }
}

class ClipboardHistoryController extends StateNotifier<ClipboardHistoryState> {
  ClipboardHistoryController(
    this._repository,
    this._watcher,
    this._readSettings, {
    this.onItemStored,
    this.onItemMetadataChanged,
    this.onCollectionsChanged,
    this.onVaultExit,
    this.urlPreviewService,
  }) : super(const ClipboardHistoryState()) {
    _subscription = _watcher.watch().listen(
      _capture,
      onError: (Object _) {
        state = state.copyWith(
          errorMessage: 'Không thể đọc một định dạng clipboard.',
        );
      },
    );
    unawaited(initialize());
  }

  final ClipboardRepository _repository;
  final ClipboardWatcher _watcher;
  final AppSettings Function() _readSettings;
  final Future<void> Function(ClipboardItem item)? onItemStored;
  final Future<void> Function(ClipboardItem item)? onItemMetadataChanged;
  final Future<void> Function()? onCollectionsChanged;
  final void Function()? onVaultExit;
  final UrlPreviewService? urlPreviewService;
  final Map<String, Future<UrlPreviewMetadata?>> _urlPreviewLoads = {};
  ClipboardPayload? _suppressedRemotePayload;
  DateTime? _suppressRemoteUntil;
  late final StreamSubscription<ClipboardPayload> _subscription;

  Future<void> initialize() async {
    final settings = _readSettings();
    try {
      await _repository.cleanup(settings);
      await reload();
      if (settings.monitoringEnabled) await _watcher.start();
    } on Object {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể mở cơ sở dữ liệu ClipFlow.',
      );
    }
  }

  Future<void> reload() async {
    try {
      ClipboardContentType? type;
      if (state.typeFilters.isEmpty) {
        switch (state.section) {
          case HistorySection.images:
            type = ClipboardContentType.image;
          case HistorySection.links:
            type = ClipboardContentType.url;
          case HistorySection.code:
            type = ClipboardContentType.code;
          case HistorySection.all ||
              HistorySection.pinned ||
              HistorySection.collection:
            type = null;
        }
      }
      final items = await _repository.getItems(
        pinnedOnly: state.section == HistorySection.pinned,
        type: type,
        collectionId: state.section == HistorySection.collection
            ? state.collectionId
            : null,
      );
      state = state.copyWith(
        items: items,
        isLoading: false,
        clearError: true,
        selectedItemId: items.any((item) => item.id == state.selectedItemId)
            ? state.selectedItemId
            : items.firstOrNull?.id,
        hasExplicitSelection:
            items.any((item) => item.id == state.selectedItemId) &&
            state.hasExplicitSelection,
        clearSelection: items.isEmpty,
      );
    } on Object {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải lịch sử clipboard.',
      );
    }
  }

  Future<void> _capture(ClipboardPayload payload) async {
    final suppressionActive =
        _suppressRemoteUntil?.isAfter(DateTime.now()) ?? false;
    if (suppressionActive && _samePayload(payload, _suppressedRemotePayload)) {
      _suppressedRemotePayload = null;
      _suppressRemoteUntil = null;
      return;
    }
    _suppressedRemotePayload = null;
    _suppressRemoteUntil = null;
    await _storeAndQueue(payload);
    await _repository.cleanup(_readSettings());
    await reload();
  }

  Future<void> receiveRemote(
    ClipboardPayload payload, {
    bool isPinned = false,
    List<ClipboardCollection> collections = const [],
    bool writeToSystemClipboard = true,
    bool metadataAuthoritative = false,
  }) async {
    if (writeToSystemClipboard) {
      _suppressedRemotePayload = payload;
      _suppressRemoteUntil = DateTime.now().add(const Duration(seconds: 2));
      await _watcher.write(payload);
    }
    final item = await _repository.store(payload, _readSettings());
    if (item != null) {
      if (isPinned || metadataAuthoritative) {
        await _repository.setPinned(item.id, isPinned);
      }
      if (collections.isNotEmpty) {
        for (final collection in collections) {
          await _repository.upsertCollection(collection);
          await _repository.addToCollection(item.id, collection.id);
        }
        await onCollectionsChanged?.call();
      }
    }
    await _repository.cleanup(_readSettings());
    await reload();
  }

  bool _samePayload(ClipboardPayload current, ClipboardPayload? expected) {
    if (expected == null || current.text != expected.text) return false;
    final a = current.imageBytes;
    final b = expected.imageBytes;
    if (a == null || b == null) return a == null && b == null;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _storeAndQueue(ClipboardPayload payload) async {
    final item = await _repository.store(payload, _readSettings());
    if (item != null) await onItemStored?.call(item);
  }

  Future<bool> captureCurrent() async {
    final payload = await _watcher.readCurrent();
    if (payload == null) return false;
    await _capture(payload);
    return true;
  }

  void search(String value) => state = state.copyWith(query: value);

  Future<void> setTypeFilters(Set<ClipboardContentType> types) async {
    state = types.isEmpty
        ? state.copyWith(clearTypeFilter: true)
        : state.copyWith(typeFilters: types);
    await reload();
  }

  Future<void> toggleTypeFilter(ClipboardContentType type) async {
    final next = {...state.typeFilters};
    if (!next.add(type)) next.remove(type);
    state = next.isEmpty
        ? state.copyWith(clearTypeFilter: true)
        : state.copyWith(typeFilters: next);
    await reload();
  }

  Future<void> toggleQuickTypeFilter(ClipboardContentType type) async {
    final next = {...state.typeFilters};
    if (next.isEmpty) {
      final sectionType = switch (state.section) {
        HistorySection.images => ClipboardContentType.image,
        HistorySection.links => ClipboardContentType.url,
        HistorySection.code => ClipboardContentType.code,
        _ => null,
      };
      if (sectionType != null) next.add(sectionType);
    }
    if (!next.add(type)) next.remove(type);
    state = state.copyWith(
      section: HistorySection.all,
      clearCollection: true,
      typeFilters: next,
      clearTypeFilter: next.isEmpty,
      clearSelection: true,
    );
    await reload();
  }

  Future<void> selectSection(
    HistorySection section, {
    String? collectionId,
    bool preserveTypeFilter = false,
  }) async {
    final leavingVault =
        state.section == HistorySection.collection &&
        state.collectionId == ClipboardCollection.vaultId &&
        (section != HistorySection.collection ||
            collectionId != ClipboardCollection.vaultId);
    if (leavingVault) onVaultExit?.call();
    state = state.copyWith(
      section: section,
      collectionId: collectionId,
      clearCollection: section != HistorySection.collection,
      clearTypeFilter: !preserveTypeFilter,
      clearSelection: true,
    );
    await reload();
  }

  Future<void> onCollectionDeleted(String id) async {
    if (state.section == HistorySection.collection &&
        state.collectionId == id) {
      await selectSection(HistorySection.all);
    } else {
      await reload();
    }
  }

  void select(String id) =>
      state = state.copyWith(selectedItemId: id, hasExplicitSelection: true);

  Future<void> copy(ClipboardItem item) async {
    final imageFile = item.imagePath == null ? null : File(item.imagePath!);
    final payload = ClipboardPayload(
      text: item.content.isEmpty ? null : item.content,
      imageBytes: imageFile != null && await imageFile.exists()
          ? await imageFile.readAsBytes()
          : null,
    );
    _suppressVaultRecapture(payload);
    await _watcher.write(payload);
    await _repository.markCopied(item.id);
    final copiedAt = DateTime.now();
    state = state.copyWith(
      items: [
        for (final current in state.items)
          if (current.id == item.id)
            current.copyWith(
              lastCopiedAt: copiedAt,
              copyCount: current.copyCount + 1,
            )
          else
            current,
      ],
    );
  }

  Future<bool> copyAsPlainText(ClipboardItem item) async {
    if (item.content.trim().isEmpty) return false;
    final payload = ClipboardPayload(text: item.content);
    _suppressVaultRecapture(payload);
    await _watcher.write(payload);
    await _repository.markCopied(item.id);
    final copiedAt = DateTime.now();
    state = state.copyWith(
      items: [
        for (final current in state.items)
          if (current.id == item.id)
            current.copyWith(
              lastCopiedAt: copiedAt,
              copyCount: current.copyCount + 1,
            )
          else
            current,
      ],
    );
    return true;
  }

  void _suppressVaultRecapture(ClipboardPayload payload) {
    if (state.section != HistorySection.collection ||
        state.collectionId != ClipboardCollection.vaultId) {
      return;
    }
    _suppressedRemotePayload = payload;
    _suppressRemoteUntil = DateTime.now().add(const Duration(seconds: 2));
  }

  Future<void> togglePinned(ClipboardItem item) async {
    final vaultOperation = _isViewingVault;
    final newPinState = !item.isPinned;
    await _repository.setPinned(item.id, newPinState);
    if (!vaultOperation) {
      await onItemMetadataChanged?.call(item.copyWith(isPinned: newPinState));
    }
    await reload();
  }

  Future<void> updateNote(ClipboardItem item, String? note) async {
    final vaultOperation = _isViewingVault;
    final trimmed = note?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    final updated = item.copyWith(note: value, clearNote: value == null);
    await _repository.updateNote(item.id, value);
    state = state.copyWith(
      items: [
        for (final current in state.items)
          if (current.id == item.id) updated else current,
      ],
    );
    if (!vaultOperation) await onItemMetadataChanged?.call(updated);
  }

  Future<ClipboardItem?> updateItemContent(
    ClipboardItem item, {
    required String content,
    Uint8List? imageBytes,
  }) async {
    if (_repository is! EditableClipboardRepository) return null;
    final vaultOperation = _isViewingVault;
    final repository = _repository as EditableClipboardRepository;
    final updated = await repository.updateItemContent(
      item,
      content: content,
      imageBytes: imageBytes,
    );
    state = state.copyWith(
      items: [
        for (final current in state.items)
          if (current.id == item.id) updated else current,
      ],
    );
    if (!vaultOperation) await onItemMetadataChanged?.call(updated);
    return updated;
  }

  Future<void> delete(ClipboardItem item) async {
    await _repository.deleteItem(item.id);
    await reload();
  }

  Future<void> clearHistory({bool includePinned = false}) async {
    await _repository.clearHistory(includePinned: includePinned);
    await reload();
  }

  Future<void> setMonitoring(bool enabled) async {
    if (enabled) {
      await _watcher.start();
    } else {
      await _watcher.stop();
    }
  }

  Future<void> addToCollection(String itemId, String collectionId) async {
    await _repository.addToCollection(itemId, collectionId);
    if (collectionId == ClipboardCollection.vaultId) {
      await reload();
      return;
    }
    final item = state.items
        .where((current) => current.id == itemId)
        .firstOrNull;
    if (item != null) await onItemMetadataChanged?.call(item);
    await reload();
  }

  Future<Set<String>> collectionIdsForItem(String itemId) {
    return _repository.collectionIdsForItem(itemId);
  }

  bool get _isViewingVault =>
      state.section == HistorySection.collection &&
      state.collectionId == ClipboardCollection.vaultId;

  Future<String?> addTextItem(String text) async {
    final payload = ClipboardPayload(text: text);
    await _watcher.write(payload);
    await _storeAndQueue(payload);
    await _repository.cleanup(_readSettings());
    await reload();
    return text;
  }

  Future<String?> performOcr(ClipboardItem item) async {
    if (item.imagePath == null) return null;
    if (item.metadataJson?.isNotEmpty == true) {
      try {
        final metadata = jsonDecode(item.metadataJson!) as Map<String, dynamic>;
        final cachedText = metadata['ocrText'] as String?;
        if (cachedText?.trim().isNotEmpty == true) return cachedText!.trim();
      } on Object {
        // Ignore malformed legacy metadata and refresh OCR below.
      }
    }
    const ocrService = OcrService();
    final extractedText = await ocrService.extractTextFromImage(
      item.imagePath!,
    );
    if (extractedText == null || extractedText.trim().isEmpty) return null;
    Map<String, dynamic> metadata = {};
    try {
      metadata = item.metadataJson?.isNotEmpty == true
          ? jsonDecode(item.metadataJson!) as Map<String, dynamic>
          : {};
    } on Object {
      metadata = {};
    }
    metadata['ocrText'] = extractedText.trim();
    metadata['ocrUpdatedAt'] = DateTime.now().toIso8601String();
    await _repository.updateMetadata(item.id, jsonEncode(metadata));
    await addTextItem(extractedText);
    return extractedText;
  }

  Future<UrlPreviewMetadata?> ensureUrlPreview(
    ClipboardItem item, {
    bool force = false,
  }) async {
    if (item.contentType != ClipboardContentType.url || _isViewingVault) {
      return UrlPreviewMetadata.fromClipboardMetadata(item.metadataJson);
    }
    final cached = UrlPreviewMetadata.fromClipboardMetadata(item.metadataJson);
    if (!force && cached != null && cached.isFresh(DateTime.now().toUtc())) {
      return cached;
    }
    final service = urlPreviewService;
    if (service == null) return cached;
    final activeLoad = _urlPreviewLoads[item.id];
    if (activeLoad != null) return activeLoad;

    final load = _loadUrlPreview(item, service, cached);
    _urlPreviewLoads[item.id] = load;
    try {
      return await load;
    } finally {
      _urlPreviewLoads.remove(item.id);
    }
  }

  Future<UrlPreviewMetadata?> _loadUrlPreview(
    ClipboardItem item,
    UrlPreviewService service,
    UrlPreviewMetadata? fallback,
  ) async {
    final value = item.primaryUrl?.trim().isNotEmpty == true
        ? item.primaryUrl!
        : item.content;
    final preview = await service.fetch(value);
    if (preview == null) return fallback;
    final current = state.items
        .where((entry) => entry.id == item.id)
        .firstOrNull;
    final sourceItem = current ?? item;
    final metadataJson = preview.mergeIntoClipboardMetadata(
      sourceItem.metadataJson,
    );
    await _repository.updateMetadata(item.id, metadataJson);
    final updated = sourceItem.copyWith(metadataJson: metadataJson);
    state = state.copyWith(
      items: [
        for (final current in state.items)
          if (current.id == item.id) updated else current,
      ],
    );
    await onItemMetadataChanged?.call(updated);
    return preview;
  }

  Future<String?> translateItem(ClipboardItem item, String targetLang) async {
    if (item.content.trim().isEmpty) return null;
    const translationService = TranslationService();
    final translated = await translationService.translate(
      text: item.content,
      targetLanguage: targetLang,
    );
    if (translated == null || translated.trim().isEmpty) return null;
    await addTextItem(translated);
    return translated;
  }

  Future<String?> uploadImageToCloud(ClipboardItem item) async {
    final path = item.imagePath ?? item.content;
    if (path.isEmpty) return null;
    const uploadService = CloudUploadService();
    final url = await uploadService.uploadImage(
      imagePath: path,
      settings: _readSettings(),
    );
    if (url == null || url.trim().isEmpty) return null;
    await addTextItem(url);
    return url;
  }

  @override
  void dispose() {
    _subscription.cancel();
    _watcher.stop();
    super.dispose();
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class CollectionsController
    extends StateNotifier<AsyncValue<List<ClipboardCollection>>> {
  CollectionsController(this._repository, {this.onChanged})
    : super(const AsyncValue.loading()) {
    unawaited(reload());
  }

  final ClipboardRepository _repository;
  final Future<void> Function(ClipboardCollection collection, {bool deleted})?
  onChanged;

  Future<void> reload() async {
    state = await AsyncValue.guard(_repository.getCollections);
  }

  Future<void> create(String name) async {
    if (name.trim().isEmpty) return;
    final collection = await _repository.createCollection(name);
    await onChanged?.call(collection);
    await reload();
  }

  Future<void> rename(String id, String name) async {
    if (name.trim().isEmpty) return;
    await _repository.renameCollection(id, name);
    final collections = await _repository.getCollections();
    final collection = collections.where((item) => item.id == id).firstOrNull;
    if (collection != null) await onChanged?.call(collection);
    await reload();
  }

  Future<void> delete(String id) async {
    final collection = state.value?.where((item) => item.id == id).firstOrNull;
    await _repository.deleteCollection(id);
    if (collection != null) await onChanged?.call(collection, deleted: true);
    await reload();
  }
}

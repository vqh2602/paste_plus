import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/clipboard_watcher.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/clipboard_content_type.dart';
import '../domain/clipboard_item.dart';
import '../domain/clipboard_payload.dart';
import '../domain/clipboard_repository.dart';
import '../domain/search_query.dart';

enum HistorySection { all, pinned, images, links, code, collection }

class ClipboardHistoryState {
  const ClipboardHistoryState({
    this.items = const [],
    this.isLoading = true,
    this.errorMessage,
    this.query = '',
    this.section = HistorySection.all,
    this.collectionId,
    this.typeFilter,
    this.selectedItemId,
  });

  final List<ClipboardItem> items;
  final bool isLoading;
  final String? errorMessage;
  final String query;
  final HistorySection section;
  final String? collectionId;
  final ClipboardContentType? typeFilter;
  final String? selectedItemId;

  List<ClipboardItem> get visibleItems {
    final parsed = ClipboardSearchQuery.parse(query);
    return items
        .where((item) {
          return (typeFilter == null || item.contentType == typeFilter) &&
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
    ClipboardContentType? typeFilter,
    bool clearTypeFilter = false,
    String? selectedItemId,
    bool clearSelection = false,
  }) {
    return ClipboardHistoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      query: query ?? this.query,
      section: section ?? this.section,
      collectionId: clearCollection ? null : collectionId ?? this.collectionId,
      typeFilter: clearTypeFilter ? null : typeFilter ?? this.typeFilter,
      selectedItemId: clearSelection
          ? null
          : selectedItemId ?? this.selectedItemId,
    );
  }
}

class ClipboardHistoryController extends StateNotifier<ClipboardHistoryState> {
  ClipboardHistoryController(
    this._repository,
    this._watcher,
    this._readSettings,
  ) : super(const ClipboardHistoryState()) {
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
    await _repository.store(payload, _readSettings());
    await _repository.cleanup(_readSettings());
    await reload();
  }

  Future<bool> captureCurrent() async {
    final payload = await _watcher.readCurrent();
    if (payload == null) return false;
    await _capture(payload);
    return true;
  }

  void search(String value) => state = state.copyWith(query: value);

  void filterByType(ClipboardContentType? type) {
    state = type == null
        ? state.copyWith(clearTypeFilter: true)
        : state.copyWith(typeFilter: type);
  }

  Future<void> selectSection(
    HistorySection section, {
    String? collectionId,
  }) async {
    state = state.copyWith(
      section: section,
      collectionId: collectionId,
      clearCollection: section != HistorySection.collection,
      clearSelection: true,
    );
    await reload();
  }

  void select(String id) => state = state.copyWith(selectedItemId: id);

  Future<void> copy(ClipboardItem item) async {
    final imageFile = item.imagePath == null ? null : File(item.imagePath!);
    await _watcher.write(
      ClipboardPayload(
        text: item.content.isEmpty ? null : item.content,
        imageBytes: imageFile != null && await imageFile.exists()
            ? await imageFile.readAsBytes()
            : null,
      ),
    );
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

  Future<void> togglePinned(ClipboardItem item) async {
    await _repository.setPinned(item.id, !item.isPinned);
    await reload();
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
  }

  Future<Set<String>> collectionIdsForItem(String itemId) {
    return _repository.collectionIdsForItem(itemId);
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
  CollectionsController(this._repository) : super(const AsyncValue.loading()) {
    unawaited(reload());
  }

  final ClipboardRepository _repository;

  Future<void> reload() async {
    state = await AsyncValue.guard(_repository.getCollections);
  }

  Future<void> create(String name) async {
    if (name.trim().isEmpty) return;
    await _repository.createCollection(name);
    await reload();
  }

  Future<void> rename(String id, String name) async {
    if (name.trim().isEmpty) return;
    await _repository.renameCollection(id, name);
    await reload();
  }

  Future<void> delete(String id) async {
    await _repository.deleteCollection(id);
    await reload();
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:clipflow/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

import '../core/database/app_database.dart';
import '../core/platform/desktop_integration_service.dart';
import '../core/services/clipboard_watcher.dart';
import '../core/services/ai_debug_service.dart';
import '../core/services/logging_service.dart';
import '../features/ai/presentation/ai_controller.dart';
import '../features/ai/data/ai_conversation_repository.dart';
import '../features/ai/domain/ai_model_info.dart';
import '../features/ai/localization/ai_language_detector.dart';
import '../features/ai/services/ai_model_downloader_service.dart';
import '../features/ai/services/clipboard_embedding_indexer.dart';
import '../features/ai/services/clipboard_vector_store.dart';
import '../features/ai/services/hybrid_semantic_search.dart';
import '../features/ai/services/local_ai_engine.dart';
import '../features/clipboard_history/data/sqlite_clipboard_repository.dart';
import '../features/clipboard_history/domain/clipboard_item.dart';
import '../features/clipboard_history/domain/clipboard_payload.dart';
import '../features/clipboard_history/domain/clipboard_repository.dart';
import '../features/clipboard_history/presentation/history_controller.dart';
import '../features/device_sync/domain/local_sharing_state.dart';
import '../features/device_sync/data/item_sync_state_repository.dart';
import '../features/device_sync/presentation/local_sharing_controller.dart';
import '../features/device_sync/services/local_sharing_service.dart';
import '../features/device_sync/services/clipboard_sync_coordinator.dart';
import '../features/device_sync/services/mdns_tls_local_sharing_service.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/settings/presentation/settings_controller.dart';

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('AppDatabase must be overridden in main.'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError(
    'SettingsRepository must be overridden in main.',
  ),
);

final loggingServiceProvider = Provider((ref) => const LoggingService());

final aiDebugControllerProvider =
    StateNotifierProvider<AiDebugController, AiDebugState>((ref) {
      return AiDebugController();
    });

final quickPanelModeProvider = StateProvider<bool>((ref) => false);
final aiWindowModeProvider = StateProvider<bool>((ref) => false);

final clipboardRepositoryProvider = Provider<ClipboardRepository>((ref) {
  return SqliteClipboardRepository(ref.watch(appDatabaseProvider));
});

final clipboardWatcherProvider = Provider<ClipboardWatcher>((ref) {
  final watcher = Platform.isMacOS
      ? MacOSClipboardWatcher()
      : Platform.isWindows
      ? WindowsClipboardWatcher()
      : FlutterClipboardWatcher();
  ref.onDispose(watcher.dispose);
  return watcher;
});

final desktopIntegrationProvider = Provider<DesktopIntegrationService>((ref) {
  final service = DesktopIntegrationService(
    ref.watch(loggingServiceProvider),
    () => lookupAppLocalizations(
      Locale(ref.read(settingsControllerProvider).language),
    ),
  );
  ref.onDispose(service.dispose);
  return service;
});

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
      return SettingsController(ref.watch(settingsRepositoryProvider));
    });

final localSharingServiceProvider = Provider<LocalSharingService>((ref) {
  final service = MdnsTlsLocalSharingService();
  ref.onDispose(service.dispose);
  return service;
});

final itemSyncStateRepositoryProvider = Provider<ItemSyncStateRepository>((
  ref,
) {
  return ItemSyncStateRepository(ref.watch(appDatabaseProvider));
});

final clipboardSyncCoordinatorProvider = Provider<ClipboardSyncCoordinator>((
  ref,
) {
  return ClipboardSyncCoordinator(
    transport: ref.watch(localSharingServiceProvider),
    syncStates: ref.watch(itemSyncStateRepositoryProvider),
    clipboardRepository: ref.watch(clipboardRepositoryProvider),
    readSettings: () => ref.read(settingsControllerProvider),
  );
});

final localSharingControllerProvider =
    StateNotifierProvider<LocalSharingController, LocalSharingState>((ref) {
      final controller = LocalSharingController(
        ref.watch(localSharingServiceProvider),
        ref.read(settingsControllerProvider),
      );
      ref.listen<AppSettings>(settingsControllerProvider, (_, next) {
        controller.updateConfiguration(next);
      });
      return controller;
    });

final historyControllerProvider =
    StateNotifierProvider<ClipboardHistoryController, ClipboardHistoryState>((
      ref,
    ) {
      late final ClipboardHistoryController controller;
      controller = ClipboardHistoryController(
        ref.watch(clipboardRepositoryProvider),
        ref.watch(clipboardWatcherProvider),
        () => ref.read(settingsControllerProvider),
        onItemStored: (item) async {
          unawaited(ref.read(clipboardEmbeddingIndexerProvider).enqueue(item));
          final settings = ref.read(settingsControllerProvider);
          if (!settings.localSharingEnabled ||
              settings.allConnectionsPaused ||
              !settings.autoSyncClipboard ||
              (settings.syncPinnedItemsOnly && !item.isPinned)) {
            return;
          }
          await ref
              .read(clipboardSyncCoordinatorProvider)
              .itemStored(item, ref.read(localSharingControllerProvider));
        },
        onItemMetadataChanged: (item) async {
          final settings = ref.read(settingsControllerProvider);
          if (!settings.localSharingEnabled ||
              settings.allConnectionsPaused ||
              !settings.autoSyncClipboard) {
            return;
          }
          await ref
              .read(clipboardSyncCoordinatorProvider)
              .itemMetadataChanged(
                item,
                ref.read(localSharingControllerProvider),
              );
        },
        onCollectionsChanged: () =>
            ref.read(collectionsControllerProvider.notifier).reload(),
      );
      final incomingSubscription = ref
          .watch(localSharingServiceProvider)
          .receivedPayloads
          .listen((payload) {
            unawaited(
              controller.receiveRemote(
                ClipboardPayload(
                  text: payload.text,
                  imageBytes: payload.imageBytes,
                ),
                isPinned: payload.isPinned,
                collections: payload.collections
                    .map(
                      (collection) => ClipboardCollection(
                        id: collection.collectionId,
                        name: collection.name,
                        icon: collection.icon,
                        createdAt: collection.createdAt,
                        updatedAt: collection.updatedAt,
                        sortOrder: collection.sortOrder,
                      ),
                    )
                    .toList(growable: false),
                writeToSystemClipboard: payload.writeToSystemClipboard,
                metadataAuthoritative: payload.metadataAuthoritative,
              ),
            );
          });
      final incomingCollectionsSubscription = ref
          .watch(localSharingServiceProvider)
          .receivedCollections
          .listen((payload) {
            unawaited(() async {
              final repository = ref.read(clipboardRepositoryProvider);
              if (payload.deleted) {
                await repository.deleteCollection(payload.collectionId);
              } else {
                await repository.upsertCollection(
                  ClipboardCollection(
                    id: payload.collectionId,
                    name: payload.name,
                    icon: payload.icon,
                    createdAt: payload.createdAt,
                    updatedAt: payload.updatedAt,
                    sortOrder: payload.sortOrder,
                  ),
                );
              }
              await ref.read(collectionsControllerProvider.notifier).reload();
              await controller.reload();
            }());
          });
      ref.listen<LocalSharingState>(localSharingControllerProvider, (_, next) {
        final settings = ref.read(settingsControllerProvider);
        if (settings.localSharingEnabled && !settings.allConnectionsPaused) {
          unawaited(
            ref
                .read(clipboardSyncCoordinatorProvider)
                .drainConnectedPeers(next),
          );
        }
      });
      ref.onDispose(() {
        unawaited(incomingSubscription.cancel());
        unawaited(incomingCollectionsSubscription.cancel());
      });
      return controller;
    });

final collectionsControllerProvider =
    StateNotifierProvider<
      CollectionsController,
      AsyncValue<List<ClipboardCollection>>
    >((ref) {
      final repository = ref.watch(clipboardRepositoryProvider);
      late final CollectionsController controller;
      controller = CollectionsController(
        repository,
        onChanged: (collection, {deleted = false}) async {
          final settings = ref.read(settingsControllerProvider);
          if (!settings.localSharingEnabled ||
              settings.allConnectionsPaused ||
              !settings.autoSyncClipboard) {
            return;
          }
          await ref
              .read(clipboardSyncCoordinatorProvider)
              .collectionChanged(
                collection,
                ref.read(localSharingControllerProvider),
                deleted: deleted,
              );
        },
      );
      return controller;
    });

final aiModelDownloaderProvider = Provider<AiModelDownloaderService>((ref) {
  return AiModelDownloaderService();
});

final clipboardVectorStoreProvider = Provider<ClipboardVectorStore>((ref) {
  return ClipboardVectorStore(ref.watch(appDatabaseProvider));
});

final hybridSemanticSearchProvider = Provider<HybridSemanticSearch>((ref) {
  return HybridSemanticSearch(
    ref.watch(clipboardVectorStoreProvider),
    ref.watch(appDatabaseProvider),
  );
});

final clipboardEmbeddingIndexerProvider = Provider<ClipboardEmbeddingIndexer>((
  ref,
) {
  final model = AiModelInfo.findById(
    ref.watch(settingsControllerProvider).selectedAiModel,
  );
  return ClipboardEmbeddingIndexer(
    vectorStore: ref.watch(clipboardVectorStoreProvider),
    modelId: model.id,
    embedder: (text) =>
        ref.read(localAiEngineProvider).embedText(model: model, text: text),
  );
});

final localAiEngineProvider = Provider<LocalAiEngine>((ref) {
  final engine = LocalAiEngine(
    ref.watch(aiModelDownloaderProvider),
    ref.read(aiDebugControllerProvider.notifier),
    null,
    ref.watch(hybridSemanticSearchProvider),
    ref.watch(clipboardRepositoryProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final aiConversationRepositoryProvider = Provider<AiConversationRepository>((
  ref,
) {
  return const AiConversationRepository();
});

final aiLanguageDetectorProvider = Provider<AiLanguageDetector>((ref) {
  return CallbackAiLanguageDetector((text) {
    final modelId = ref.read(settingsControllerProvider).selectedAiModel;
    return ref
        .read(localAiEngineProvider)
        .detectLanguageTag(model: AiModelInfo.findById(modelId), text: text);
  });
});

final aiControllerProvider = StateNotifierProvider<AiController, AiState>((
  ref,
) {
  return AiController(
    ref.watch(aiModelDownloaderProvider),
    ref.watch(localAiEngineProvider),
    ref.watch(aiConversationRepositoryProvider),
    ref.watch(aiLanguageDetectorProvider),
    ref,
  );
});

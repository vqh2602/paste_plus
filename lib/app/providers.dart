import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/database/app_database.dart';
import '../core/platform/desktop_integration_service.dart';
import '../core/services/clipboard_watcher.dart';
import '../core/services/ai_debug_service.dart';
import '../core/services/logging_service.dart';
import '../features/ai/presentation/ai_controller.dart';
import '../features/ai/data/ai_conversation_repository.dart';
import '../features/ai/services/ai_model_downloader_service.dart';
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
  final service = DesktopIntegrationService(ref.watch(loggingServiceProvider));
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
      ClipboardSyncCoordinator? syncCoordinator;
      ClipboardSyncCoordinator coordinator() {
        return syncCoordinator ??= ClipboardSyncCoordinator(
          transport: ref.read(localSharingServiceProvider),
          syncStates: ref.read(itemSyncStateRepositoryProvider),
          clipboardRepository: ref.read(clipboardRepositoryProvider),
          readSettings: () => ref.read(settingsControllerProvider),
        );
      }

      late final ClipboardHistoryController controller;
      controller = ClipboardHistoryController(
        ref.watch(clipboardRepositoryProvider),
        ref.watch(clipboardWatcherProvider),
        () => ref.read(settingsControllerProvider),
        onItemStored: (item) async {
          final settings = ref.read(settingsControllerProvider);
          if (!settings.localSharingEnabled ||
              settings.allConnectionsPaused ||
              !settings.autoSyncClipboard ||
              (settings.syncPinnedItemsOnly && !item.isPinned)) {
            return;
          }
          await coordinator().itemStored(
            item,
            ref.read(localSharingControllerProvider),
          );
        },
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
              ),
            );
          });
      ref.listen<LocalSharingState>(localSharingControllerProvider, (_, next) {
        final settings = ref.read(settingsControllerProvider);
        if (settings.localSharingEnabled && !settings.allConnectionsPaused) {
          unawaited(coordinator().drainConnectedPeers(next));
        }
      });
      ref.onDispose(() => unawaited(incomingSubscription.cancel()));
      return controller;
    });

final collectionsControllerProvider =
    StateNotifierProvider<
      CollectionsController,
      AsyncValue<List<ClipboardCollection>>
    >((ref) {
      return CollectionsController(ref.watch(clipboardRepositoryProvider));
    });

final aiModelDownloaderProvider = Provider<AiModelDownloaderService>((ref) {
  return AiModelDownloaderService();
});

final localAiEngineProvider = Provider<LocalAiEngine>((ref) {
  final engine = LocalAiEngine(
    ref.watch(aiModelDownloaderProvider),
    ref.read(aiDebugControllerProvider.notifier),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final aiConversationRepositoryProvider = Provider<AiConversationRepository>((
  ref,
) {
  return const AiConversationRepository();
});

final aiControllerProvider = StateNotifierProvider<AiController, AiState>((
  ref,
) {
  return AiController(
    ref.watch(aiModelDownloaderProvider),
    ref.watch(localAiEngineProvider),
    ref.watch(aiConversationRepositoryProvider),
    ref,
  );
});

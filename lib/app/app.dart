import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:clipflow/l10n/app_localizations.dart';

import '../core/platform/desktop_integration_service.dart';
import '../core/services/update_download_provider.dart';
import '../core/ui/ai_debug_overlay.dart';
import '../features/clipboard_history/domain/clipboard_item.dart';
import '../features/clipboard_history/presentation/history_controller.dart';
import 'providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class ClipFlowApp extends ConsumerStatefulWidget {
  const ClipFlowApp({super.key});

  @override
  ConsumerState<ClipFlowApp> createState() => _ClipFlowAppState();
}

class _ClipFlowAppState extends ConsumerState<ClipFlowApp>
    with WindowListener, WidgetsBindingObserver {
  late final router = createRouter(
    hasCompletedOnboarding: ref
        .read(settingsControllerProvider)
        .hasCompletedOnboarding,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      windowManager.addListener(this);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsControllerProvider);
      ref
          .read(desktopIntegrationProvider)
          .initialize(
            runInTray: settings.runInTray,
            openAtLogin: settings.openAtLogin,
            showInDock: settings.showInDock,
            openPanelShortcut: settings.openPanelShortcut,
            onQuickPanelRequested: () {
              router.go('/');
              // Preserve AI mode when the clipboard panel is opened beside it.
              ref.read(quickPanelModeProvider.notifier).state = true;
              if (ref.read(desktopIntegrationProvider).windowMode ==
                  DesktopWindowMode.quickPanel) {
                ref.read(aiWindowModeProvider.notifier).state = false;
              }
            },
            onMainWindowRequested: () {
              router.go('/');
              ref.read(aiWindowModeProvider.notifier).state = false;
              ref.read(quickPanelModeProvider.notifier).state = false;
            },
            onQuickPanelDismissed: () {
              ref.read(quickPanelModeProvider.notifier).state = false;
            },
            onAiWindowRequested: () {
              router.go('/');
              ref.read(quickPanelModeProvider.notifier).state = false;
              ref.read(aiWindowModeProvider.notifier).state = true;
            },
            onCheckUpdatesRequested: () {
              router.go('/settings?page=about');
              final updates = ref.read(updateDownloadProvider.notifier);
              updates.reset();
              unawaited(updates.checkOnly());
            },
            onTrayStatusChanged: (enabled) {
              unawaited(
                ref
                    .read(settingsControllerProvider.notifier)
                    .update((current) => current.copyWith(runInTray: enabled)),
              );
            },
            onOpenAtLoginStatusChanged: (enabled) {
              unawaited(
                ref
                    .read(settingsControllerProvider.notifier)
                    .update(
                      (current) => current.copyWith(openAtLogin: enabled),
                    ),
              );
            },
          );
      unawaited(
        ref
            .read(desktopIntegrationProvider)
            .setCaptureProtection(settings.hideDuringScreenSharing),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      windowManager.removeListener(this);
    }
    router.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      await ref.read(desktopIntegrationProvider).handleWindowClose();
    }
  }

  @override
  void onWindowBlur() {
    if (_shouldKeepWindowDuringDeviceAuthentication()) return;
    _lockVault();
    unawaited(ref.read(desktopIntegrationProvider).handleWindowBlur());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        !_shouldKeepWindowDuringDeviceAuthentication()) {
      _lockVault();
    }
  }

  bool _shouldKeepWindowDuringDeviceAuthentication() {
    final vault = ref.read(vaultControllerProvider);
    final desktop = ref.read(desktopIntegrationProvider);
    return vault.deviceAuthenticationInProgress ||
        desktop.shouldIgnoreWindowBlur;
  }

  void _lockVault() {
    ref.read(vaultControllerProvider.notifier).lock();
    final history = ref.read(historyControllerProvider);
    if (history.section == HistorySection.collection &&
        history.collectionId == ClipboardCollection.vaultId) {
      unawaited(
        ref
            .read(historyControllerProvider.notifier)
            .selectSection(HistorySection.all),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final theme = AppTheme.theme(
      settings.themeMode,
      accentKey: settings.accentColor,
    );
    return CupertinoApp.router(
      locale: Locale(settings.language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      title: 'ClipFlow',
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) {
        Widget current = child ?? const SizedBox.shrink();
        final brightness = theme.brightness;
        if (brightness != null) {
          final mediaQuery = MediaQuery.of(context);
          current = MediaQuery(
            data: mediaQuery.copyWith(platformBrightness: brightness),
            child: current,
          );
        }
        return CupertinoTheme(
          data: theme,
          child: AiDebugOverlay(child: current),
        );
      },
      routerConfig: router,
    );
  }
}

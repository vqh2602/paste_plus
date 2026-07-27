import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class ClipFlowApp extends ConsumerStatefulWidget {
  const ClipFlowApp({super.key});

  @override
  ConsumerState<ClipFlowApp> createState() => _ClipFlowAppState();
}

class _ClipFlowAppState extends ConsumerState<ClipFlowApp> with WindowListener {
  late final router = createRouter(
    hasCompletedOnboarding: ref
        .read(settingsControllerProvider)
        .hasCompletedOnboarding,
  );

  @override
  void initState() {
    super.initState();
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
              ref.read(quickPanelModeProvider.notifier).state = true;
            },
            onMainWindowRequested: () {
              router.go('/');
              ref.read(quickPanelModeProvider.notifier).state = false;
            },
            onQuickPanelDismissed: () {
              ref.read(quickPanelModeProvider.notifier).state = false;
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
    });
  }

  @override
  void dispose() {
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
    unawaited(ref.read(desktopIntegrationProvider).handleWindowBlur());
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    return CupertinoApp.router(
      title: 'ClipFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(
        settings.themeMode,
        accentKey: settings.accentColor,
      ),
      routerConfig: router,
    );
  }
}

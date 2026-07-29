import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../services/logging_service.dart';
import 'shortcut_config.dart';

class OpenAtLoginResult {
  const OpenAtLoginResult({
    required this.enabled,
    this.needsApproval = false,
    this.errorMessage,
  });

  final bool enabled;
  final bool needsApproval;
  final String? errorMessage;
}

enum DesktopWindowMode { main, quickPanel, aiWindow, aiWithQuickPanel, hidden }

class _MainWindowSnapshot {
  const _MainWindowSnapshot({
    required this.position,
    required this.size,
    required this.wasMaximized,
    required this.wasFullScreen,
  });

  final Offset position;
  final Size size;
  final bool wasMaximized;
  final bool wasFullScreen;
}

class DesktopIntegrationService with TrayListener {
  DesktopIntegrationService(this._logger);

  final LoggingService _logger;
  bool _initialized = false;
  final List<HotKey> _hotKeys = [];
  VoidCallback? _onQuickPanelRequested;
  VoidCallback? _onMainWindowRequested;
  VoidCallback? _onQuickPanelDismissed;
  VoidCallback? _onAiWindowRequested;
  DesktopWindowMode _windowMode = DesktopWindowMode.main;
  _MainWindowSnapshot? _mainWindowSnapshot;
  Rect? _aiWindowBounds;
  DateTime _ignoreBlurUntil = DateTime.fromMillisecondsSinceEpoch(0);
  bool _trayActive = false;

  static const _startupChannel = MethodChannel('launch_at_startup');
  static const _windowChannel = MethodChannel('clipflow/window');

  bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  bool get isTrayActive => _trayActive;

  Future<void> initialize({
    required bool runInTray,
    required bool openAtLogin,
    required bool showInDock,
    String? openPanelShortcut,
    required VoidCallback onQuickPanelRequested,
    required VoidCallback onMainWindowRequested,
    required VoidCallback onQuickPanelDismissed,
    VoidCallback? onAiWindowRequested,
    ValueChanged<bool>? onTrayStatusChanged,
    ValueChanged<bool>? onOpenAtLoginStatusChanged,
  }) async {
    if (!isDesktop || _initialized) return;
    _initialized = true;
    _onQuickPanelRequested = onQuickPanelRequested;
    _onMainWindowRequested = onMainWindowRequested;
    _onQuickPanelDismissed = onQuickPanelDismissed;
    _onAiWindowRequested = onAiWindowRequested;
    await setShowInDock(showInDock);
    launchAtStartup.setup(
      appName: 'ClipFlow',
      appPath: Platform.resolvedExecutable,
    );
    await registerGlobalHotKey(
      decodeShortcut(openPanelShortcut, ShortcutAction.openPanel),
    );
    if (runInTray) {
      final trayReady = await setTrayEnabled(true);
      if (!trayReady) onTrayStatusChanged?.call(false);
    }

    var startupState = await getOpenAtLoginState();
    if (startupState.enabled != openAtLogin ||
        (!openAtLogin && startupState.needsApproval)) {
      startupState = await setOpenAtLogin(openAtLogin);
    }
    if (startupState.enabled != openAtLogin) {
      onOpenAtLoginStatusChanged?.call(startupState.enabled);
    }
  }

  Future<bool> registerDefaultHotKey() {
    return registerGlobalHotKey(defaultShortcut(ShortcutAction.openPanel));
  }

  Future<bool> registerGlobalHotKey(HotKey hotKey) async {
    if (!isDesktop) return false;
    final previousHotKeys = [..._hotKeys];
    for (final hotKey in _hotKeys) {
      await hotKeyManager.unregister(hotKey);
    }
    _hotKeys.clear();

    try {
      final systemHotKey = HotKey(
        key: hotKey.key,
        modifiers: hotKey.modifiers,
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(
        systemHotKey,
        keyDownHandler: (_) => unawaited(toggleQuickPanel()),
      );
      _hotKeys.add(systemHotKey);
      return true;
    } on Object catch (error) {
      _logger.log(
        LogLevel.warning,
        'Could not register a global shortcut',
        error: error,
      );
      for (final previousHotKey in previousHotKeys) {
        try {
          await hotKeyManager.register(
            previousHotKey,
            keyDownHandler: (_) => unawaited(toggleQuickPanel()),
          );
          _hotKeys.add(previousHotKey);
        } on Object catch (restoreError) {
          _logger.log(
            LogLevel.warning,
            'Could not restore the previous global shortcut',
            error: restoreError,
          );
        }
      }
      return false;
    }
  }

  Future<bool> setTrayEnabled(bool enabled) async {
    if (!isDesktop) return false;
    try {
      if (!enabled) {
        trayManager.removeListener(this);
        await trayManager.destroy();
        await windowManager.setPreventClose(false);
        _trayActive = false;
        return true;
      }
      trayManager.removeListener(this);
      trayManager.addListener(this);
      await trayManager.setIcon(
        'assets/tray_icon.png',
        isTemplate: Platform.isMacOS,
      );
      await trayManager.setToolTip('ClipFlow');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(label: 'Mở ClipFlow', onClick: (_) => showMainWindow()),
            MenuItem(
              label: 'Mở bảng clipboard',
              onClick: (_) => toggleQuickPanel(),
            ),
            MenuItem.separator(),
            MenuItem(label: 'Thoát', onClick: (_) => exit(0)),
          ],
        ),
      );
      await windowManager.setPreventClose(true);
      _trayActive = true;
      return true;
    } on Object catch (error) {
      _trayActive = false;
      _logger.log(
        LogLevel.warning,
        'Could not initialize the system tray',
        error: error,
      );
      return false;
    }
  }

  Future<OpenAtLoginResult> getOpenAtLoginState() async {
    if (!isDesktop) return const OpenAtLoginResult(enabled: false);
    try {
      if (Platform.isMacOS) {
        final status = await _startupChannel.invokeMethod<String>(
          'launchAtStartupStatus',
        );
        return OpenAtLoginResult(
          enabled: status == 'enabled',
          needsApproval: status == 'requiresApproval',
        );
      }
      return OpenAtLoginResult(enabled: await launchAtStartup.isEnabled());
    } on Object catch (error) {
      _logger.log(
        LogLevel.warning,
        'Could not read launch at login status',
        error: error,
      );
      return OpenAtLoginResult(enabled: false, errorMessage: '$error');
    }
  }

  Future<OpenAtLoginResult> setOpenAtLogin(bool enabled) async {
    if (!isDesktop) return const OpenAtLoginResult(enabled: false);
    try {
      if (Platform.isMacOS) {
        await _startupChannel.invokeMethod<void>('launchAtStartupSetEnabled', {
          'setEnabledValue': enabled,
        });
      } else if (enabled) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
      return getOpenAtLoginState();
    } on Object catch (error) {
      _logger.log(
        LogLevel.warning,
        'Could not update launch at login status',
        error: error,
      );
      final current = await getOpenAtLoginState();
      return OpenAtLoginResult(
        enabled: current.enabled,
        needsApproval: current.needsApproval,
        errorMessage: '$error',
      );
    }
  }

  Future<void> openLoginItemsSettings() async {
    if (!Platform.isMacOS) return;
    await Process.run('open', [
      'x-apple.systempreferences:com.apple.LoginItems-Settings.extension',
    ]);
  }

  Future<void> toggleQuickPanel() async {
    if (!isDesktop) return;
    if (_windowMode == DesktopWindowMode.aiWithQuickPanel &&
        await windowManager.isVisible()) {
      await _restoreAiWindowAfterQuickPanel();
      return;
    }
    if (_windowMode == DesktopWindowMode.aiWindow &&
        await windowManager.isVisible()) {
      await _showQuickPanelBesideAi();
      return;
    }
    if (_windowMode == DesktopWindowMode.quickPanel &&
        await windowManager.isVisible()) {
      await hideQuickPanel();
      return;
    }

    if (_windowMode == DesktopWindowMode.main &&
        await windowManager.isVisible()) {
      _mainWindowSnapshot = _MainWindowSnapshot(
        position: await windowManager.getPosition(),
        size: await windowManager.getSize(),
        wasMaximized: await windowManager.isMaximized(),
        wasFullScreen: await windowManager.isFullScreen(),
      );
      if (_mainWindowSnapshot!.wasFullScreen) {
        await windowManager.setFullScreen(false);
      }
      if (_mainWindowSnapshot!.wasMaximized) {
        await windowManager.unmaximize();
      }
    }

    _windowMode = DesktopWindowMode.quickPanel;
    _ignoreBlurUntil = DateTime.now().add(const Duration(milliseconds: 450));
    _onQuickPanelRequested?.call();

    final displays = await screenRetriever.getAllDisplays();
    final primary = await screenRetriever.getPrimaryDisplay();
    final cursor = await screenRetriever.getCursorScreenPoint();
    final display = displays.firstWhere((item) {
      final position = item.visiblePosition ?? Offset.zero;
      final size = item.visibleSize ?? item.size;
      return (position & size).contains(cursor);
    }, orElse: () => primary);
    final visibleSize = display.visibleSize ?? display.size;
    final visiblePosition = display.visiblePosition ?? Offset.zero;
    final panelSize = Size(
      (visibleSize.width - 24).clamp(700, 2000).toDouble(),
      (visibleSize.height * 0.34).clamp(300, 390).toDouble(),
    );
    final panelPosition = Offset(
      visiblePosition.dx + (visibleSize.width - panelSize.width) / 2,
      visiblePosition.dy + visibleSize.height - panelSize.height - 12,
    );
    await windowManager.setMinimumSize(const Size(600, 260));
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setResizable(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    if (Platform.isMacOS) {
      await _windowChannel.invokeMethod<void>('setQuickPanelMode', true);
      await windowManager.setVisibleOnAllWorkspaces(
        true,
        visibleOnFullScreen: true,
      );
    }
    await windowManager.setHasShadow(false);
    await windowManager.setBackgroundColor(const Color(0x00000000));
    await windowManager.setSize(panelSize);
    await windowManager.setPosition(panelPosition);
    await windowManager.show();
    await windowManager.focus();
    // Stage Manager can reposition a window while it is being ordered front.
    // Reapplying the desired frame after that transition keeps the panel
    // aligned to the active display instead of the current window set.
    if (Platform.isMacOS) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await windowManager.setSize(panelSize);
      await windowManager.setPosition(panelPosition);
    }
  }

  Future<void> showMainWindow() async {
    if (!isDesktop) return;
    final returningFromAlternateWindow =
        _windowMode == DesktopWindowMode.quickPanel ||
        _windowMode == DesktopWindowMode.aiWindow ||
        _windowMode == DesktopWindowMode.aiWithQuickPanel ||
        _windowMode == DesktopWindowMode.hidden;
    _windowMode = DesktopWindowMode.main;
    _onMainWindowRequested?.call();
    if (Platform.isMacOS) {
      await _windowChannel.invokeMethod<void>('setQuickPanelMode', false);
      await windowManager.setVisibleOnAllWorkspaces(false);
    }
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setHasShadow(true);
    await windowManager.setResizable(true);
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: true,
    );
    await windowManager.setMinimumSize(const Size(820, 560));
    final snapshot = returningFromAlternateWindow ? _mainWindowSnapshot : null;
    if (snapshot == null) {
      await windowManager.setSize(const Size(1180, 760), animate: true);
      await windowManager.center(animate: true);
    } else {
      await windowManager.setSize(snapshot.size);
      await windowManager.setPosition(snapshot.position);
    }
    await windowManager.show();
    if (snapshot?.wasMaximized == true) await windowManager.maximize();
    if (snapshot?.wasFullScreen == true) {
      await windowManager.setFullScreen(true);
    }
    await windowManager.focus();
  }

  Future<void> showAiWindow() async {
    if (!isDesktop) return;
    final currentPosition = await windowManager.getPosition();
    final currentSize = await windowManager.getSize();
    final wasFullScreen = await windowManager.isFullScreen();
    final wasMaximized = await windowManager.isMaximized();
    if (_windowMode == DesktopWindowMode.main &&
        await windowManager.isVisible()) {
      _mainWindowSnapshot = _MainWindowSnapshot(
        position: currentPosition,
        size: currentSize,
        wasMaximized: wasMaximized,
        wasFullScreen: wasFullScreen,
      );
    }
    if (wasFullScreen) await windowManager.setFullScreen(false);
    if (wasMaximized) await windowManager.unmaximize();

    final displays = await screenRetriever.getAllDisplays();
    final primary = await screenRetriever.getPrimaryDisplay();
    final currentCenter =
        currentPosition + Offset(currentSize.width / 2, currentSize.height / 2);
    final display = displays.firstWhere((item) {
      final position = item.visiblePosition ?? Offset.zero;
      final size = item.visibleSize ?? item.size;
      return (position & size).contains(currentCenter);
    }, orElse: () => primary);
    final visibleSize = display.visibleSize ?? display.size;
    final visiblePosition = display.visiblePosition ?? Offset.zero;
    final availableWidth = math.max(0.0, visibleSize.width - 48);
    final availableHeight = math.max(0.0, visibleSize.height - 48);
    final aiSize = Size(
      math.min((visibleSize.width * 0.72).clamp(900, 1180), availableWidth),
      math.min((visibleSize.height * 0.78).clamp(640, 820), availableHeight),
    );
    final aiBounds = Rect.fromLTWH(
      visiblePosition.dx + (visibleSize.width - aiSize.width) / 2,
      visiblePosition.dy + (visibleSize.height - aiSize.height) / 2,
      aiSize.width,
      aiSize.height,
    );
    _aiWindowBounds = aiBounds;

    _windowMode = DesktopWindowMode.aiWindow;
    _onAiWindowRequested?.call();
    if (Platform.isMacOS) {
      await _windowChannel.invokeMethod<void>('setQuickPanelMode', false);
      await windowManager.setVisibleOnAllWorkspaces(false);
    }
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setHasShadow(true);
    await windowManager.setResizable(true);
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: true,
    );
    await windowManager.setMinimumSize(
      Size(math.min(760, aiSize.width), math.min(560, aiSize.height)),
    );
    await windowManager.setBounds(aiBounds);
    await windowManager.show();
    await windowManager.focus();
    // macOS can briefly restore the previous Quick Panel frame while changing
    // the native window level. Reapply the complete frame after that handoff.
    if (Platform.isMacOS) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await windowManager.setBounds(aiBounds);
    }
  }

  Future<void> _showQuickPanelBesideAi() async {
    final currentBounds = await windowManager.getBounds();
    _aiWindowBounds = currentBounds;

    final displays = await screenRetriever.getAllDisplays();
    final primary = await screenRetriever.getPrimaryDisplay();
    final display = displays.firstWhere((item) {
      final position = item.visiblePosition ?? Offset.zero;
      final size = item.visibleSize ?? item.size;
      return (position & size).contains(currentBounds.center);
    }, orElse: () => primary);
    final visibleSize = display.visibleSize ?? display.size;
    final visiblePosition = display.visiblePosition ?? Offset.zero;
    const panelWidth = 620.0;
    final combinedWidth = math.min(
      currentBounds.width + panelWidth,
      math.max(0.0, visibleSize.width - 32),
    );
    final combinedHeight = math.min(
      math.max(currentBounds.height, 640.0),
      math.max(0.0, visibleSize.height - 32),
    );
    final combinedBounds = Rect.fromLTWH(
      visiblePosition.dx + (visibleSize.width - combinedWidth) / 2,
      visiblePosition.dy + (visibleSize.height - combinedHeight) / 2,
      combinedWidth,
      combinedHeight,
    );

    _windowMode = DesktopWindowMode.aiWithQuickPanel;
    _ignoreBlurUntil = DateTime.now().add(const Duration(milliseconds: 450));
    _onQuickPanelRequested?.call();
    if (Platform.isMacOS) {
      await _windowChannel.invokeMethod<void>('setQuickPanelMode', false);
      await windowManager.setVisibleOnAllWorkspaces(false);
    }
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setHasShadow(true);
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(const Size(980, 560));
    await windowManager.setBounds(combinedBounds);
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _restoreAiWindowAfterQuickPanel() async {
    _windowMode = DesktopWindowMode.aiWindow;
    _onQuickPanelDismissed?.call();
    _onAiWindowRequested?.call();
    await windowManager.setMinimumSize(const Size(760, 560));
    final bounds = _aiWindowBounds;
    if (bounds != null) await windowManager.setBounds(bounds);
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideQuickPanel() async {
    if (_windowMode == DesktopWindowMode.aiWithQuickPanel) {
      await _restoreAiWindowAfterQuickPanel();
      return;
    }
    _windowMode = DesktopWindowMode.hidden;
    if (isDesktop) {
      await windowManager.hide();
    }
    _onQuickPanelDismissed?.call();
  }

  Future<bool> checkAccessibilityPermission() async {
    if (!Platform.isMacOS) return true;
    try {
      return await _windowChannel.invokeMethod<bool>(
            'checkAccessibilityPermission',
          ) ??
          true;
    } on Object catch (_) {
      return true;
    }
  }

  Future<bool> setShowInDock(bool showInDock) async {
    if (!Platform.isMacOS) return true;
    try {
      await _windowChannel.invokeMethod<void>('setShowInDock', showInDock);
      return true;
    } on Object catch (error) {
      _logger.log(
        LogLevel.warning,
        'Could not update show in Dock status',
        error: error,
      );
      return false;
    }
  }

  Future<bool> requestAccessibilityPermission() async {
    if (!Platform.isMacOS) return true;
    try {
      return await _windowChannel.invokeMethod<bool>(
            'requestAccessibilityPermission',
          ) ??
          false;
    } on Object catch (_) {
      return false;
    }
  }

  Future<bool> resetAccessibilityPermission() async {
    if (!Platform.isMacOS) return true;
    try {
      return await _windowChannel.invokeMethod<bool>(
            'resetAccessibilityPermission',
          ) ??
          false;
    } on Object catch (_) {
      return false;
    }
  }

  Future<List<Map<String, String>>> getRunningApplications() async {
    if (!Platform.isMacOS) return [];
    try {
      final list = await _windowChannel.invokeListMethod<Map>(
        'getRunningApplications',
      );
      if (list == null) return [];
      return list
          .map((item) => Map<String, String>.from(item.cast<String, String>()))
          .toList();
    } on Object catch (_) {
      return [];
    }
  }

  Future<Map<String, String>?> pickApplicationFile() async {
    if (!Platform.isMacOS) return null;
    try {
      final result = await _windowChannel.invokeMapMethod<String, String>(
        'pickApplicationFile',
      );
      if (result == null) return null;
      return Map<String, String>.from(result);
    } on Object catch (_) {
      return null;
    }
  }

  Future<String?> saveConfigFile({
    String defaultName = 'clipflow_config.clipflow',
  }) async {
    if (!Platform.isMacOS) return null;
    try {
      return await _windowChannel.invokeMethod<String>('saveConfigFile', {
        'defaultName': defaultName,
      });
    } on Object catch (_) {
      return null;
    }
  }

  Future<String?> pickConfigFile() async {
    if (!Platform.isMacOS) return null;
    try {
      return await _windowChannel.invokeMethod<String>('pickConfigFile');
    } on Object catch (_) {
      return null;
    }
  }

  Future<bool> pasteToPreviousApplication() async {
    if (!Platform.isMacOS) return false;
    try {
      return await _windowChannel.invokeMethod<bool>(
            'pasteToPreviousApplication',
          ) ??
          false;
    } on Object catch (error) {
      _logger.log(
        LogLevel.warning,
        'Could not paste into the previously active application',
        error: error,
      );
      return false;
    }
  }

  Future<void> openUrl(String url) async {
    if (url.trim().isEmpty) return;
    if (Platform.isMacOS) {
      try {
        await _windowChannel.invokeMethod<void>('openUrl', {'url': url});
        return;
      } on Object catch (_) {}
    }
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('start', [url], runInShell: true);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    } catch (_) {}
  }

  Future<void> restartApp() async {
    if (Platform.isMacOS) {
      try {
        await _windowChannel.invokeMethod<void>('restartApp');
        return;
      } on Object catch (_) {}
    }
    try {
      final executable = Platform.resolvedExecutable;
      await Process.start(executable, []);
      exit(0);
    } catch (_) {}
  }

  Future<void> handleWindowBlur() async {
    if (_windowMode != DesktopWindowMode.quickPanel) return;
    if (DateTime.now().isBefore(_ignoreBlurUntil)) return;
    await hideQuickPanel();
  }

  Future<void> handleWindowClose() async {
    if (_windowMode == DesktopWindowMode.quickPanel) {
      await hideQuickPanel();
      return;
    }
    if (_windowMode == DesktopWindowMode.main) {
      _mainWindowSnapshot = _MainWindowSnapshot(
        position: await windowManager.getPosition(),
        size: await windowManager.getSize(),
        wasMaximized: await windowManager.isMaximized(),
        wasFullScreen: await windowManager.isFullScreen(),
      );
    }
    _windowMode = DesktopWindowMode.hidden;
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() {
    showMainWindow();
  }

  Future<void> dispose() async {
    if (!isDesktop) return;
    trayManager.removeListener(this);
    for (final hotKey in _hotKeys) {
      await hotKeyManager.unregister(hotKey);
    }
  }
}

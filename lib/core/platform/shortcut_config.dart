import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

enum ShortcutAction { openPanel, focusSearch, togglePin, deleteItem }

HotKey defaultShortcut(ShortcutAction action) {
  final commandModifier = Platform.isMacOS
      ? HotKeyModifier.meta
      : HotKeyModifier.control;
  return switch (action) {
    ShortcutAction.openPanel => HotKey(
      key: PhysicalKeyboardKey.keyV,
      modifiers: Platform.isMacOS
          ? [HotKeyModifier.control]
          : [HotKeyModifier.control, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    ),
    ShortcutAction.focusSearch => HotKey(
      key: PhysicalKeyboardKey.keyF,
      modifiers: [commandModifier],
      scope: HotKeyScope.inapp,
    ),
    ShortcutAction.togglePin => HotKey(
      key: PhysicalKeyboardKey.keyP,
      modifiers: [commandModifier],
      scope: HotKeyScope.inapp,
    ),
    ShortcutAction.deleteItem => HotKey(
      key: PhysicalKeyboardKey.delete,
      scope: HotKeyScope.inapp,
    ),
  };
}

HotKey decodeShortcut(String? source, ShortcutAction action) {
  if (source == null || source.isEmpty) return defaultShortcut(action);
  try {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    final hotKey = HotKey.fromJson(decoded);
    return HotKey(
      key: hotKey.key,
      modifiers: hotKey.modifiers,
      scope: action == ShortcutAction.openPanel
          ? HotKeyScope.system
          : HotKeyScope.inapp,
    );
  } on Object {
    return defaultShortcut(action);
  }
}

String encodeShortcut(HotKey hotKey) => jsonEncode(hotKey.toJson());

String shortcutSignature(HotKey hotKey) {
  final modifiers = [...?hotKey.modifiers]
    ..sort((a, b) => a.index.compareTo(b.index));
  return '${modifiers.map((item) => item.name).join('+')}:'
      '${hotKey.physicalKey.usbHidUsage}';
}

String shortcutLabel(HotKey hotKey) {
  final modifiers = hotKey.modifiers ?? const <HotKeyModifier>[];
  final modifierLabels = modifiers.map((modifier) {
    return switch (modifier) {
      HotKeyModifier.control => Platform.isMacOS ? '⌃' : 'Ctrl+',
      HotKeyModifier.shift => Platform.isMacOS ? '⇧' : 'Shift+',
      HotKeyModifier.alt => Platform.isMacOS ? '⌥' : 'Alt+',
      HotKeyModifier.meta => Platform.isMacOS ? '⌘' : 'Win+',
      HotKeyModifier.capsLock => 'Caps+',
      HotKeyModifier.fn => 'Fn+',
    };
  }).join();
  return '$modifierLabels${hotKey.physicalKey.keyLabel}';
}

bool isValidShortcut(HotKey hotKey, ShortcutAction action) {
  final keyIsModifier = HotKeyModifier.values.any(
    (modifier) => modifier.physicalKeys.contains(hotKey.physicalKey),
  );
  if (keyIsModifier) return false;
  if (action == ShortcutAction.openPanel &&
      (hotKey.modifiers == null || hotKey.modifiers!.isEmpty)) {
    return false;
  }
  return true;
}

SingleActivator shortcutActivator(HotKey hotKey) {
  final modifiers = hotKey.modifiers ?? const <HotKeyModifier>[];
  return SingleActivator(
    hotKey.logicalKey,
    control: modifiers.contains(HotKeyModifier.control),
    shift: modifiers.contains(HotKeyModifier.shift),
    alt: modifiers.contains(HotKeyModifier.alt),
    meta: modifiers.contains(HotKeyModifier.meta),
  );
}

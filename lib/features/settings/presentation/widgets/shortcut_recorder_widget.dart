import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/platform/shortcut_config.dart';
import '../../../../core/ui/cupertino_components.dart';
import 'settings_helpers.dart';

class ShortcutRowWidget extends StatelessWidget {
  const ShortcutRowWidget({
    super.key,
    required this.title,
    required this.shortcut,
    required this.action,
    required this.onChanged,
    required this.onRecordingStarted,
    required this.onRecordingCanceled,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String shortcut;
  final ShortcutAction action;
  final Future<void> Function(HotKey) onChanged;
  final Future<void> Function() onRecordingStarted;
  final Future<void> Function() onRecordingCanceled;

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoTheme.of(context).primaryColor;
    return SettingsTileWidget(
      title: title,
      subtitle: subtitle,
      trailing: CupertinoPressable(
        onPressed: () => _record(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: resolveColor(context, ClipFlowColors.surface),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: resolveColor(context, ClipFlowColors.border),
            ),
          ),
          child: Text(
            shortcut,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _record(BuildContext context) async {
    await onRecordingStarted();
    if (!context.mounted) {
      await onRecordingCanceled();
      return;
    }

    HotKey? selected;
    try {
      selected = await showCupertinoDialog<HotKey>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ShortcutRecorderDialog(action: action),
      );
      if (selected == null) {
        await onRecordingCanceled();
      } else {
        await onChanged(selected);
      }
    } on Object {
      await onRecordingCanceled();
      rethrow;
    }
  }
}

class ShortcutRecorderDialog extends StatefulWidget {
  const ShortcutRecorderDialog({super.key, required this.action});

  final ShortcutAction action;

  @override
  State<ShortcutRecorderDialog> createState() => _ShortcutRecorderDialogState();
}

class _ShortcutRecorderDialogState extends State<ShortcutRecorderDialog> {
  HotKey? _candidate;
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return true;
    }
    if (event is! KeyDownEvent) return true;

    final isModifier = HotKeyModifier.values.any(
      (modifier) => modifier.physicalKeys.contains(event.physicalKey),
    );
    if (isModifier) {
      setState(() => _errorKey = null);
      return true;
    }

    final modifiers = <HotKeyModifier>[
      if (HardwareKeyboard.instance.isMetaPressed) HotKeyModifier.meta,
      if (HardwareKeyboard.instance.isControlPressed) HotKeyModifier.control,
      if (HardwareKeyboard.instance.isAltPressed) HotKeyModifier.alt,
      if (HardwareKeyboard.instance.isShiftPressed) HotKeyModifier.shift,
    ];
    final candidate = HotKey(
      key: event.physicalKey,
      modifiers: modifiers,
      scope: widget.action == ShortcutAction.openPanel
          ? HotKeyScope.system
          : HotKeyScope.inapp,
    );
    setState(() {
      _candidate = candidate;
      _errorKey = isValidShortcut(candidate, widget.action)
          ? null
          : widget.action == ShortcutAction.openPanel && modifiers.isEmpty
          ? 'system_hotkey_needs_modifier'
          : 'choose_non_modifier';
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final candidate = _candidate;
    return CupertinoAlertDialog(
      title: Text('record_shortcut_title'.tr),
      content: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          children: [
            Text('record_shortcut_msg'.tr),
            const SizedBox(height: 14),
            Container(
              key: const Key('shortcut-recording-value'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: CupertinoColors.systemOrange),
              ),
              child: Text(
                candidate == null
                    ? 'press_shortcut'.tr
                    : shortcutLabel(candidate),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_errorKey != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorKey!.tr,
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemRed,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr),
        ),
        CupertinoDialogAction(
          key: const Key('shortcut-recording-confirm'),
          isDefaultAction: true,
          onPressed: candidate != null && _errorKey == null
              ? () => Navigator.pop(context, candidate)
              : null,
          child: Text('save'.tr),
        ),
      ],
    );
  }
}

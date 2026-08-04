import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/platform/shortcut_config.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../domain/app_settings.dart';
import 'settings_helpers.dart';
import 'shortcut_recorder_widget.dart';

class ShortcutSettingsSection extends ConsumerWidget {
  const ShortcutSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final desktop = ref.read(desktopIntegrationProvider);

    Future<void> startRecording() => desktop.suspendGlobalHotKeys();
    Future<void> cancelRecording() => desktop.resumeGlobalHotKeys();

    Future<void> saveInAppShortcut(
      AppSettings Function(AppSettings current) change,
    ) async {
      await updateSettings(ref, change);
      await desktop.resumeGlobalHotKeys();
    }

    Future<void> resetShortcuts() async {
      final openPanel = defaultShortcut(ShortcutAction.openPanel);
      final registered = await desktop.registerGlobalHotKey(openPanel);
      if (!registered) {
        if (context.mounted) {
          showCupertinoNotice(context, context.l10n.shortcut_used_by_other_app);
        }
        return;
      }
      await updateSettings(
        ref,
        (current) => current.copyWith(
          openPanelShortcut: encodeShortcut(openPanel),
          focusSearchShortcut: encodeShortcut(
            defaultShortcut(ShortcutAction.focusSearch),
          ),
          togglePinShortcut: encodeShortcut(
            defaultShortcut(ShortcutAction.togglePin),
          ),
          deleteItemShortcut: encodeShortcut(
            defaultShortcut(ShortcutAction.deleteItem),
          ),
        ),
      );
      if (context.mounted) {
        showCupertinoNotice(context, context.l10n.reset_shortcuts_success);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoSectionLabel(context.l10n.global_shortcut_section),
        SettingsGroupWidget(
          children: [
            ShortcutRowWidget(
              title: context.l10n.toggle_panel_shortcut,
              subtitle: context.l10n.toggle_panel_shortcut_sub,
              shortcut: shortcutLabel(
                decodeShortcut(
                  settings.openPanelShortcut,
                  ShortcutAction.openPanel,
                ),
              ),
              action: ShortcutAction.openPanel,
              onRecordingStarted: startRecording,
              onRecordingCanceled: cancelRecording,
              onChanged: (shortcut) async {
                final registered = await desktop.registerGlobalHotKey(shortcut);
                if (!registered) {
                  if (context.mounted) {
                    showCupertinoNotice(
                      context,
                      context.l10n.shortcut_used_by_other_app,
                    );
                  }
                  return;
                }
                await updateSettings(
                  ref,
                  (current) => current.copyWith(
                    openPanelShortcut: encodeShortcut(shortcut),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel(context.l10n.in_app_shortcuts),
        SettingsGroupWidget(
          children: [
            ShortcutRowWidget(
              title: context.l10n.focus_search_shortcut,
              subtitle: context.l10n.focus_search_sub,
              shortcut: shortcutLabel(
                decodeShortcut(
                  settings.focusSearchShortcut,
                  ShortcutAction.focusSearch,
                ),
              ),
              action: ShortcutAction.focusSearch,
              onRecordingStarted: startRecording,
              onRecordingCanceled: cancelRecording,
              onChanged: (shortcut) => saveInAppShortcut(
                (current) => current.copyWith(
                  focusSearchShortcut: encodeShortcut(shortcut),
                ),
              ),
            ),
            ShortcutRowWidget(
              title: context.l10n.toggle_pin_shortcut,
              subtitle: context.l10n.toggle_pin_sub,
              shortcut: shortcutLabel(
                decodeShortcut(
                  settings.togglePinShortcut,
                  ShortcutAction.togglePin,
                ),
              ),
              action: ShortcutAction.togglePin,
              onRecordingStarted: startRecording,
              onRecordingCanceled: cancelRecording,
              onChanged: (shortcut) => saveInAppShortcut(
                (current) => current.copyWith(
                  togglePinShortcut: encodeShortcut(shortcut),
                ),
              ),
            ),
            ShortcutRowWidget(
              title: context.l10n.delete_item_shortcut,
              subtitle: context.l10n.delete_item_sub,
              shortcut: shortcutLabel(
                decodeShortcut(
                  settings.deleteItemShortcut,
                  ShortcutAction.deleteItem,
                ),
              ),
              action: ShortcutAction.deleteItem,
              onRecordingStarted: startRecording,
              onRecordingCanceled: cancelRecording,
              onChanged: (shortcut) => saveInAppShortcut(
                (current) => current.copyWith(
                  deleteItemShortcut: encodeShortcut(shortcut),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: CupertinoButton(
            key: const Key('restore-default-shortcuts'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onPressed: resetShortcuts,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.arrow_counterclockwise, size: 16),
                const SizedBox(width: 7),
                Text(context.l10n.restore_defaults),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

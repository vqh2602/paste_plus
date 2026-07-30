import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/localization/app_translations.dart';
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
          showCupertinoNotice(context, 'shortcut_used_by_other_app'.tr);
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
        showCupertinoNotice(context, 'reset_shortcuts_success'.tr);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoSectionLabel('global_shortcut_section'.tr),
        SettingsGroupWidget(
          children: [
            ShortcutRowWidget(
              title: 'toggle_panel_shortcut'.tr,
              subtitle: 'toggle_panel_shortcut_sub'.tr,
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
                      'shortcut_used_by_other_app'.tr,
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
        CupertinoSectionLabel('in_app_shortcuts'.tr),
        SettingsGroupWidget(
          children: [
            ShortcutRowWidget(
              title: 'focus_search_shortcut'.tr,
              subtitle: 'focus_search_sub'.tr,
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
              title: 'toggle_pin_shortcut'.tr,
              subtitle: 'toggle_pin_sub'.tr,
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
              title: 'delete_item_shortcut'.tr,
              subtitle: 'delete_item_sub'.tr,
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
                Text('restore_defaults'.tr),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

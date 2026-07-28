import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/platform/shortcut_config.dart';
import '../../../../core/ui/cupertino_components.dart';
import 'settings_helpers.dart';

class ShortcutSettingsSection extends ConsumerWidget {
  const ShortcutSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
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
              onChanged: (shortcut) async {
                await updateSettings(
                  ref,
                  (current) => current.copyWith(
                    openPanelShortcut: encodeShortcut(shortcut),
                  ),
                );
                await ref
                    .read(desktopIntegrationProvider)
                    .registerGlobalHotKey(shortcut);
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
              onChanged: (shortcut) => updateSettings(
                ref,
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
              onChanged: (shortcut) => updateSettings(
                ref,
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
              onChanged: (shortcut) => updateSettings(
                ref,
                (current) => current.copyWith(
                  deleteItemShortcut: encodeShortcut(shortcut),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

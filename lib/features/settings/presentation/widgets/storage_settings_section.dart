import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';
import 'settings_helpers.dart';

class StorageSettingsSection extends ConsumerWidget {
  const StorageSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoSectionLabel('retention_and_limits'.tr),
        SettingsGroupWidget(
          children: [
            NumberRowWidget(
              title: 'retention_period'.tr,
              value: settings.retentionDays,
              suffix: 'days_unit'.tr,
              min: 1,
              max: 365,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(retentionDays: value),
              ),
            ),
            NumberRowWidget(
              title: 'max_items'.tr,
              value: settings.maxItems,
              suffix: 'items_unit'.tr,
              min: 100,
              max: 50000,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(maxItems: value),
              ),
            ),
            NumberRowWidget(
              title: 'max_database_size'.tr,
              value: settings.maxDatabaseMb,
              suffix: 'MB',
              min: 50,
              max: 5000,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(maxDatabaseMb: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel('cleanup_rules'.tr),
        SettingsGroupWidget(
          children: [
            SwitchRowWidget(
              title: 'delete_images_first'.tr,
              subtitle: 'delete_images_first_sub'.tr,
              value: settings.deleteImagesFirst,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(deleteImagesFirst: value),
              ),
            ),
            SwitchRowWidget(
              title: 'protect_pinned'.tr,
              value: settings.protectPinned,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(protectPinned: value),
              ),
            ),
            SwitchRowWidget(
              title: 'protect_collections'.tr,
              value: settings.protectCollections,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(protectCollections: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel('database_cleanup'.tr),
        SettingsGroupWidget(
          children: [
            SettingsTileWidget(
              title: 'export_backup'.tr,
              subtitle: 'export_backup_sub'.tr,
              leading: const Icon(
                CupertinoIcons.share_up,
                color: CupertinoColors.activeBlue,
              ),
              trailing: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () => exportBackupDialog(context, ref),
                child: Text('export'.tr),
              ),
            ),
            SettingsTileWidget(
              title: 'import_backup'.tr,
              subtitle: 'import_backup_sub'.tr,
              leading: const Icon(
                CupertinoIcons.cloud_download,
                color: CupertinoColors.activeGreen,
              ),
              trailing: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () => importBackupDialog(context, ref),
                child: Text('import'.tr),
              ),
            ),
            SettingsTileWidget(
              title: 'clear_unpinned'.tr,
              subtitle: 'clear_unpinned_sub'.tr,
              leading: const Icon(
                CupertinoIcons.trash,
                color: CupertinoColors.systemOrange,
              ),
              trailing: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () async {
                  await ref
                      .read(historyControllerProvider.notifier)
                      .clearHistory(includePinned: false);
                  if (context.mounted) {
                    showCupertinoNotice(context, 'unpinned_cleared'.tr);
                  }
                },
                child: Text('clear'.tr),
              ),
            ),
            SettingsTileWidget(
              title: 'clear_all_history'.tr,
              subtitle: 'clear_all_sub'.tr,
              leading: const Icon(
                CupertinoIcons.delete_solid,
                color: CupertinoColors.systemRed,
              ),
              trailing: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () async {
                  final confirmed = await confirmDeleteDialog(
                    context,
                    title: 'clear_all_confirm_title'.tr,
                    message: 'clear_all_confirm_msg'.tr,
                  );
                  if (confirmed == true) {
                    await ref
                        .read(historyControllerProvider.notifier)
                        .clearHistory(includePinned: true);
                    if (context.mounted) {
                      showCupertinoNotice(context, 'all_cleared'.tr);
                    }
                  }
                },
                child: Text(
                  'clear_all'.tr,
                  style: const TextStyle(color: CupertinoColors.systemRed),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

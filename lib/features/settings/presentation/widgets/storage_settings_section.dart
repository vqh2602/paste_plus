import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
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
        CupertinoSectionLabel(context.l10n.retention_and_limits),
        SettingsGroupWidget(
          children: [
            NumberRowWidget(
              title: context.l10n.retention_period,
              value: settings.retentionDays,
              suffix: context.l10n.days_unit,
              min: 1,
              max: 365,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(retentionDays: value),
              ),
            ),
            NumberRowWidget(
              title: context.l10n.max_items,
              value: settings.maxItems,
              suffix: context.l10n.items_unit,
              min: 100,
              max: 50000,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(maxItems: value),
              ),
            ),
            NumberRowWidget(
              title: context.l10n.max_database_size,
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
        CupertinoSectionLabel(context.l10n.cleanup_rules),
        SettingsGroupWidget(
          children: [
            SwitchRowWidget(
              title: context.l10n.delete_images_first,
              subtitle: context.l10n.delete_images_first_sub,
              value: settings.deleteImagesFirst,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(deleteImagesFirst: value),
              ),
            ),
            SwitchRowWidget(
              title: context.l10n.protect_pinned,
              value: settings.protectPinned,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(protectPinned: value),
              ),
            ),
            SwitchRowWidget(
              title: context.l10n.protect_collections,
              value: settings.protectCollections,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(protectCollections: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel(context.l10n.database_cleanup),
        SettingsGroupWidget(
          children: [
            SettingsTileWidget(
              title: context.l10n.export_backup,
              subtitle: context.l10n.export_backup_sub,
              leading: const Icon(
                CupertinoIcons.share_up,
                color: CupertinoColors.activeBlue,
              ),
              trailing: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () => exportBackupDialog(context, ref),
                child: Text(context.l10n.export),
              ),
            ),
            SettingsTileWidget(
              title: context.l10n.import_backup,
              subtitle: context.l10n.import_backup_sub,
              leading: const Icon(
                CupertinoIcons.cloud_download,
                color: CupertinoColors.activeGreen,
              ),
              trailing: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () => importBackupDialog(context, ref),
                child: Text(context.l10n.import),
              ),
            ),
            SettingsTileWidget(
              title: context.l10n.clear_unpinned,
              subtitle: context.l10n.clear_unpinned_sub,
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
                    showCupertinoNotice(context, context.l10n.unpinned_cleared);
                  }
                },
                child: Text(context.l10n.clear),
              ),
            ),
            SettingsTileWidget(
              title: context.l10n.clear_all_history,
              subtitle: context.l10n.clear_all_sub,
              leading: const Icon(
                CupertinoIcons.delete_solid,
                color: CupertinoColors.systemRed,
              ),
              trailing: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () async {
                  final confirmed = await confirmDeleteDialog(
                    context,
                    title: context.l10n.clear_all_confirm_title,
                    message: context.l10n.clear_all_confirm_msg,
                  );
                  if (confirmed == true) {
                    await ref
                        .read(historyControllerProvider.notifier)
                        .clearHistory(includePinned: true);
                    if (context.mounted) {
                      showCupertinoNotice(context, context.l10n.all_cleared);
                    }
                  }
                },
                child: Text(
                  context.l10n.clear_all,
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

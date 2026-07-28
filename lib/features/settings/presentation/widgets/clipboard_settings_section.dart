import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../../clipboard_history/domain/clipboard_content_type.dart';
import '../../domain/app_settings.dart';
import 'settings_helpers.dart';

class ClipboardSettingsSection extends ConsumerWidget {
  const ClipboardSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupWidget(
          children: [
            SwitchRowWidget(
              title: 'clipboard_monitoring'.tr,
              subtitle: settings.monitoringEnabled
                  ? 'monitoring_active'.tr
                  : 'monitoring_paused'.tr,
              value: settings.monitoringEnabled,
              onChanged: (value) async {
                await updateSettings(
                  ref,
                  (current) => current.copyWith(monitoringEnabled: value),
                );
                await ref
                    .read(historyControllerProvider.notifier)
                    .setMonitoring(value);
              },
            ),
            SwitchRowWidget(
              title: 'ignore_duplicates'.tr,
              value: settings.ignoreDuplicates,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(ignoreDuplicates: value),
              ),
            ),
            PickerRowWidget<DuplicateBehavior>(
              title: 'duplicate_behavior'.tr,
              value: settings.duplicateBehavior,
              items: {
                DuplicateBehavior.bringToTop: 'bring_to_top'.tr,
                DuplicateBehavior.createNew: 'create_new'.tr,
                DuplicateBehavior.keepPosition: 'keep_position'.tr,
              },
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(duplicateBehavior: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel('allowed_content_types'.tr),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ClipboardContentType.values.map((type) {
            final selected = settings.allowedTypes.contains(type.name);
            return CupertinoChoicePill(
              label: typeNameHelper(type),
              selected: selected,
              onPressed: () {
                final next = {...settings.allowedTypes};
                selected ? next.remove(type.name) : next.add(type.name);
                updateSettings(ref, (current) => current.copyWith(allowedTypes: next));
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel('content_limits'.tr),
        SettingsGroupWidget(
          children: [
            NumberRowWidget(
              title: 'min_length'.tr,
              value: settings.minTextLength,
              suffix: 'chars_unit'.tr,
              min: 1,
              max: 1000,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(minTextLength: value),
              ),
            ),
            NumberRowWidget(
              title: 'max_length'.tr,
              value: settings.maxTextLength,
              suffix: 'chars_unit'.tr,
              min: 1000,
              max: 1000000,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(maxTextLength: value),
              ),
            ),
            NumberRowWidget(
              title: 'max_image_size'.tr,
              value: settings.maxImageMb,
              suffix: 'MB',
              min: 1,
              max: 100,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(maxImageMb: value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

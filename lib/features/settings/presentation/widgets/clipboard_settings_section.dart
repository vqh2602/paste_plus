import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
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
              title: context.l10n.clipboard_monitoring,
              subtitle: settings.monitoringEnabled
                  ? context.l10n.monitoring_active
                  : context.l10n.monitoring_paused,
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
              title: context.l10n.ignore_duplicates,
              value: settings.ignoreDuplicates,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(ignoreDuplicates: value),
              ),
            ),
            PickerRowWidget<DuplicateBehavior>(
              title: context.l10n.duplicate_behavior,
              value: settings.duplicateBehavior,
              items: {
                DuplicateBehavior.bringToTop: context.l10n.bring_to_top,
                DuplicateBehavior.createNew: context.l10n.create_new,
                DuplicateBehavior.keepPosition: context.l10n.keep_position,
              },
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(duplicateBehavior: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel(context.l10n.allowed_content_types),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ClipboardContentType.values.map((type) {
            final selected = settings.allowedTypes.contains(type.name);
            return CupertinoChoicePill(
              label: typeNameHelper(context, type),
              selected: selected,
              onPressed: () {
                final next = {...settings.allowedTypes};
                selected ? next.remove(type.name) : next.add(type.name);
                updateSettings(
                  ref,
                  (current) => current.copyWith(allowedTypes: next),
                );
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel(context.l10n.content_limits),
        SettingsGroupWidget(
          children: [
            NumberRowWidget(
              title: context.l10n.min_length,
              value: settings.minTextLength,
              suffix: context.l10n.chars_unit,
              min: 1,
              max: 1000,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(minTextLength: value),
              ),
            ),
            NumberRowWidget(
              title: context.l10n.max_length,
              value: settings.maxTextLength,
              suffix: context.l10n.chars_unit,
              min: 1000,
              max: 1000000,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(maxTextLength: value),
              ),
            ),
            NumberRowWidget(
              title: context.l10n.max_image_size,
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

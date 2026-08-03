import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import 'settings_helpers.dart';

class PrivacySettingsSection extends ConsumerWidget {
  const PrivacySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoTheme.of(
              context,
            ).primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.lock_shield),
              const SizedBox(width: 12),
              Expanded(child: Text(context.l10n.privacy_db_notice)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SettingsGroupWidget(
          children: [
            SettingsTileWidget(
              title: context.l10n.privacy_policy,
              subtitle: context.l10n.privacy_policy_sub,
              leading: const Icon(
                CupertinoIcons.shield_fill,
                color: CupertinoColors.activeGreen,
              ),
              trailing: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () => showPrivacyPolicyDialog(context),
                child: Text(context.l10n.view_policy),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SettingsGroupWidget(
          children: [
            SwitchRowWidget(
              title: context.l10n.ignore_sensitive,
              subtitle: context.l10n.ignore_sensitive_sub,
              value: settings.ignoreSensitive,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(ignoreSensitive: value),
              ),
            ),
            SwitchRowWidget(
              title: context.l10n.ignore_otp,
              subtitle: context.l10n.ignore_otp_sub,
              value: settings.ignoreOtp,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(ignoreOtp: value),
              ),
            ),
            SwitchRowWidget(
              title: context.l10n.ignore_long_token,
              subtitle: context.l10n.ignore_long_token_sub,
              value: settings.ignoreLongToken,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(ignoreLongToken: value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

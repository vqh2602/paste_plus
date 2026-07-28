import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/localization/app_translations.dart';
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
              Expanded(
                child: Text(
                  'privacy_db_notice'.tr,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SettingsGroupWidget(
          children: [
            SettingsTileWidget(
              title: 'privacy_policy'.tr,
              subtitle: 'privacy_policy_sub'.tr,
              leading: const Icon(
                CupertinoIcons.shield_fill,
                color: CupertinoColors.activeGreen,
              ),
              trailing: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () => showPrivacyPolicyDialog(context),
                child: Text('view_policy'.tr),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SettingsGroupWidget(
          children: [
            SwitchRowWidget(
              title: 'ignore_sensitive'.tr,
              subtitle: 'ignore_sensitive_sub'.tr,
              value: settings.ignoreSensitive,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(ignoreSensitive: value),
              ),
            ),
            SwitchRowWidget(
              title: 'ignore_otp'.tr,
              subtitle: 'ignore_otp_sub'.tr,
              value: settings.ignoreOtp,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(ignoreOtp: value),
              ),
            ),
            SwitchRowWidget(
              title: 'ignore_long_token'.tr,
              subtitle: 'ignore_long_token_sub'.tr,
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

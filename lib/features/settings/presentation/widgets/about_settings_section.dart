import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/providers.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/ui/cupertino_components.dart';
import 'settings_helpers.dart';

class AboutSettingsSection extends ConsumerWidget {
  const AboutSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoSurface(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: const DecorationImage(
                    image: AssetImage('assets/branding/clipflow_app_icon.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ClipFlow',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'version_label'.tr.replaceAll(
                        '@v',
                        UpdateService.currentVersion,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: resolveColor(
                          context,
                          ClipFlowColors.secondaryText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'about_tagline'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: resolveColor(
                          context,
                          ClipFlowColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'github_source'.tr,
                    child: CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      onPressed: () => ref
                          .read(desktopIntegrationProvider)
                          .openUrl('https://github.com/vqh2602/paste_plus'),
                      child: const FaIcon(FontAwesomeIcons.github, size: 18),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () async {
                      final update = await const UpdateService()
                          .checkForUpdate();
                      if (!context.mounted) return;
                      if (update != null && update.hasUpdate) {
                        showCupertinoNotice(
                          context,
                          'Có bản cập nhật mới v${update.latestVersion}',
                        );
                      } else {
                        showCupertinoNotice(
                          context,
                          'Bạn đang ở phiên bản mới nhất',
                        );
                      }
                    },
                    child: Text('check_update'.tr),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
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
            SettingsTileWidget(
              title: 'open_source_licenses'.tr,
              subtitle: 'licenses_sub'.tr,
              leading: const Icon(
                CupertinoIcons.doc_plaintext,
                color: CupertinoColors.activeBlue,
              ),
              trailing: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () => showLicensesDialog(context),
                child: Text('view_licenses'.tr),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

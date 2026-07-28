import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';
import 'settings_helpers.dart';

class GeneralSettingsSection extends ConsumerWidget {
  const GeneralSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupWidget(
          children: [
            SwitchRowWidget(
              title: 'launch_at_login'.tr,
              subtitle: 'launch_at_login_sub'.tr,
              value: settings.openAtLogin,
              onChanged: (value) async {
                final result = await ref
                    .read(desktopIntegrationProvider)
                    .setOpenAtLogin(value);
                await updateSettings(
                  ref,
                  (current) => current.copyWith(openAtLogin: result.enabled),
                );
                if (!context.mounted) return;
                if (result.needsApproval) {
                  await ref
                      .read(desktopIntegrationProvider)
                      .openLoginItemsSettings();
                  if (!context.mounted) return;
                  showCupertinoNotice(
                    context,
                    'login_items_hint'.tr,
                  );
                } else {
                  if (result.errorMessage != null || result.enabled != value) {
                    showCupertinoNotice(
                      context,
                      'open_at_login_failed'.tr,
                    );
                    return;
                  }
                  showCupertinoNotice(
                    context,
                    value ? 'open_at_login_on'.tr : 'open_at_login_off'.tr,
                  );
                }
              },
            ),
            SwitchRowWidget(
              title: 'run_in_tray'.tr,
              subtitle: 'run_in_tray_sub'.tr,
              value: settings.runInTray,
              onChanged: (value) async {
                final success = await ref
                    .read(desktopIntegrationProvider)
                    .setTrayEnabled(value);
                if (success) {
                  await updateSettings(
                    ref,
                    (current) => current.copyWith(runInTray: value),
                  );
                }
                if (context.mounted) {
                  showCupertinoNotice(
                    context,
                    success
                        ? (value
                              ? 'tray_on'.tr
                              : 'tray_off'.tr)
                        : 'tray_failed'.tr,
                  );
                }
              },
            ),
            SwitchRowWidget(
              title: 'show_in_dock'.tr,
              subtitle: 'show_in_dock_sub'.tr,
              value: settings.showInDock,
              onChanged: (value) async {
                await ref
                    .read(desktopIntegrationProvider)
                    .setShowInDock(value);
                await updateSettings(
                  ref,
                  (current) => current.copyWith(showInDock: value),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel('sound_enabled'.tr),
        SettingsGroupWidget(
          children: [
            SwitchRowWidget(
              title: 'sound_enabled'.tr,
              subtitle: 'sound_enabled_sub'.tr,
              value: settings.soundEnabled,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(soundEnabled: value),
              ),
            ),
          ],
        ),
        if (Platform.isMacOS) ...[
          const SizedBox(height: 22),
          CupertinoSectionLabel('system_permissions'.tr),
          SettingsGroupWidget(
            children: [
              FutureBuilder<bool>(
                future: ref
                    .read(desktopIntegrationProvider)
                    .checkAccessibilityPermission(),
                builder: (context, snapshot) {
                  final hasPermission = snapshot.data ?? false;
                  return SettingsTileWidget(
                    title: 'accessibility_permission'.tr,
                    subtitle: hasPermission
                        ? 'accessibility_granted'.tr
                        : 'accessibility_required'.tr,
                    leading: Icon(
                      hasPermission
                          ? CupertinoIcons.checkmark_shield
                          : CupertinoIcons.exclamationmark_shield,
                      color: hasPermission
                          ? CupertinoColors.systemGreen
                          : CupertinoColors.systemOrange,
                    ),
                    trailing: hasPermission
                        ? Text(
                            'granted'.tr,
                            style: TextStyle(
                              fontSize: 13,
                              color: resolveColor(
                                context,
                                ClipFlowColors.secondaryText,
                              ),
                            ),
                          )
                        : CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            onPressed: () async {
                              await ref
                                  .read(desktopIntegrationProvider)
                                  .requestAccessibilityPermission();
                            },
                            child: Text('grant_permission'.tr),
                          ),
                  );
                },
              ),
              SettingsTileWidget(
                title: 'restart_app'.tr,
                subtitle: 'restart_app_sub'.tr,
                leading: const Icon(
                  CupertinoIcons.arrow_counterclockwise,
                  color: CupertinoColors.activeBlue,
                ),
                trailing: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  onPressed: () async {
                    await ref
                        .read(desktopIntegrationProvider)
                        .restartApp();
                  },
                  child: Text('restart'.tr),
                ),
              ),
              SettingsTileWidget(
                title: 'reset_permission'.tr,
                subtitle: 'reset_permission_sub'.tr,
                leading: const Icon(
                  CupertinoIcons.refresh_bold,
                  color: CupertinoColors.systemOrange,
                ),
                trailing: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  onPressed: () async {
                    await ref
                        .read(desktopIntegrationProvider)
                        .resetAccessibilityPermission();
                  },
                  child: Text('reset'.tr),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        CupertinoSectionLabel('appearance_and_theme'.tr),
        SettingsGroupWidget(
          children: [
            PickerRowWidget<String>(
              title: 'theme_mode'.tr,
              value: settings.themeMode,
              items: {
                'system': 'theme_system'.tr,
                'light': 'theme_light'.tr,
                'dark': 'theme_dark'.tr,
              },
              onChanged: (value) =>
                  updateSettings(ref, (current) => current.copyWith(themeMode: value)),
            ),
            PickerRowWidget<String>(
              title: 'app_language'.tr,
              value: settings.language,
              items: const {'vi': 'Tiếng Việt', 'en': 'English'},
              onChanged: (value) =>
                  updateSettings(ref, (current) => current.copyWith(language: value)),
            ),
            PickerRowWidget<String>(
              title: 'translation_language'.tr,
              subtitle: 'translation_language_sub'.tr,
              value: settings.targetTranslationLanguage,
              items: const {
                'vi': 'Tiếng Việt',
                'en': 'Tiếng Anh (English)',
                'zh-CN': 'Tiếng Trung (Chinese)',
                'ja': 'Tiếng Nhật (Japanese)',
                'ko': 'Tiếng Hàn (Korean)',
                'fr': 'Tiếng Pháp (French)',
                'de': 'Tiếng Đức (German)',
                'es': 'Tiếng Tây Ban Nha (Spanish)',
                'ru': 'Tiếng Nga (Russian)',
                'th': 'Tiếng Thái (Thai)',
              },
              onChanged: (value) => updateSettings(
                ref,
                (current) =>
                    current.copyWith(targetTranslationLanguage: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel('cloud_hosting_section'.tr),
        SettingsGroupWidget(
          children: [
            PickerRowWidget<String>(
              title: 'cloud_provider'.tr,
              subtitle: 'cloud_provider_sub'.tr,
              value: settings.cloudImageHost,
              items: {
                'freeimage': 'cloud_in_use'.tr,
                'gdrive': 'cloud_coming_soon'.tr,
              },
              onChanged: (value) {
                if (value == 'gdrive') return;
                updateSettings(ref, (current) => current.copyWith(cloudImageHost: value));
              },
            ),
            TextRowWidget(
              title: 'FreeImage API Key',
              value: settings.freeImageApiKey,
              placeholder: 'api_key_placeholder'.tr,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(freeImageApiKey: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        CupertinoSurface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'accent_color'.tr,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppTheme.accentColors.entries.map((entry) {
                  final key = entry.key;
                  final color = entry.value;
                  final selected = settings.accentColor == key;
                  final name = switch (key) {
                    'indigo' => 'Indigo Mac',
                    'blue' => 'Ocean Blue',
                    'mint' => 'Emerald Mint',
                    'orange' => 'Sunset Orange',
                    'rose' => 'Rose Pink',
                    'violet' => 'Cyber Violet',
                    'slate' => 'Monochrome Slate',
                    'pastel_lavender' => 'Lavender Bloom 🪻',
                    'pastel_periwinkle' => 'Periwinkle Sky 🌌',
                    'pastel_sky' => 'Mây Trời ☁️',
                    'pastel_cyan' => 'Gió Biển 🌊',
                    'pastel_mint' => 'Bạc Hà Tươi 🌿',
                    'pastel_sage' => 'Trà Xanh Sage 🍵',
                    'pastel_emerald' => 'Ngọc Bích 🍃',
                    'pastel_lime' => 'Chanh Mềm 🍐',
                    'pastel_butter' => 'Mật Ong 🍯',
                    'pastel_apricot' => 'Cam Mơ 🍑',
                    'pastel_peach' => 'Đào Hoàng Hôn 🌅',
                    'pastel_coral' => 'San Hộ 🪸',
                    'pastel_rose' => 'Hoa Hồng 🎀',
                    'pastel_sakura' => 'Anh Đào Sakura 🌸',
                    'pastel_lilac' => 'Tử Đinh Hương 🪻',
                    'pastel_plum' => 'Mận Chín 🍇',
                    'pastel_mocha' => 'Cà Phê Mocha ☕',
                    'pastel_slate' => 'Đá Trôi 🪨',
                    _ => key,
                  };
                  return CupertinoPressable(
                    onPressed: () => updateSettings(
                      ref,
                      (current) => current.copyWith(accentColor: key),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: selected ? 0.18 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? color
                              : resolveColor(context, ClipFlowColors.border),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: selected
                                ? const Icon(
                                    CupertinoIcons.checkmark,
                                    size: 10,
                                    color: CupertinoColors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w400,
                              color: selected ? color : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

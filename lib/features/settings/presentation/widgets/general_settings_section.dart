import 'package:clipflow/core/localization/localization_extensions.dart';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';

import '../../../../core/ui/cupertino_components.dart';
import '../../../../l10n/app_localizations.dart';
import 'settings_helpers.dart';

const appLanguageNativeNames = <String, String>{
  'vi': 'Tiếng Việt',
  'en': 'English',
  'ja': '日本語',
  'ko': '한국어',
  'de': 'Deutsch',
  'zh': '简体中文',
};

Map<String, String> supportedAppLanguageItems() => {
  for (final locale in AppLocalizations.supportedLocales)
    locale.languageCode:
        appLanguageNativeNames[locale.languageCode] ?? locale.toLanguageTag(),
};

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
              title: context.l10n.launch_at_login,
              subtitle: context.l10n.launch_at_login_sub,
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
                  showCupertinoNotice(context, context.l10n.login_items_hint);
                } else {
                  if (result.errorMessage != null || result.enabled != value) {
                    showCupertinoNotice(
                      context,
                      context.l10n.open_at_login_failed,
                    );
                    return;
                  }
                  showCupertinoNotice(
                    context,
                    value
                        ? context.l10n.open_at_login_on
                        : context.l10n.open_at_login_off,
                  );
                }
              },
            ),
            SwitchRowWidget(
              title: context.l10n.run_in_tray,
              subtitle: context.l10n.run_in_tray_sub,
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
                        ? (value ? context.l10n.tray_on : context.l10n.tray_off)
                        : context.l10n.tray_failed,
                  );
                }
              },
            ),
            SwitchRowWidget(
              title: context.l10n.show_in_dock,
              subtitle: context.l10n.show_in_dock_sub,
              value: settings.showInDock,
              onChanged: (value) async {
                await ref.read(desktopIntegrationProvider).setShowInDock(value);
                await updateSettings(
                  ref,
                  (current) => current.copyWith(showInDock: value),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel(context.l10n.sound_enabled),
        SettingsGroupWidget(
          children: [
            SwitchRowWidget(
              title: context.l10n.sound_enabled,
              subtitle: context.l10n.sound_enabled_sub,
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
          CupertinoSectionLabel(context.l10n.system_permissions),
          SettingsGroupWidget(
            children: [
              FutureBuilder<bool>(
                future: ref
                    .read(desktopIntegrationProvider)
                    .checkAccessibilityPermission(),
                builder: (context, snapshot) {
                  final hasPermission = snapshot.data ?? false;
                  return SettingsTileWidget(
                    title: context.l10n.accessibility_permission,
                    subtitle: hasPermission
                        ? context.l10n.accessibility_granted
                        : context.l10n.accessibility_required,
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
                            context.l10n.granted,
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
                            child: Text(context.l10n.grant_permission),
                          ),
                  );
                },
              ),
              SettingsTileWidget(
                title: context.l10n.restart_app,
                subtitle: context.l10n.restart_app_sub,
                leading: const Icon(
                  CupertinoIcons.arrow_counterclockwise,
                  color: CupertinoColors.activeBlue,
                ),
                trailing: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  onPressed: () async {
                    await ref.read(desktopIntegrationProvider).restartApp();
                  },
                  child: Text(context.l10n.restart),
                ),
              ),
              SettingsTileWidget(
                title: context.l10n.reset_permission,
                subtitle: context.l10n.reset_permission_sub,
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
                  child: Text(context.l10n.reset),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        CupertinoSectionLabel(context.l10n.appearance_and_theme),
        SettingsGroupWidget(
          children: [
            PickerRowWidget<String>(
              title: context.l10n.theme_mode,
              value: settings.themeMode,
              items: {
                'system': context.l10n.theme_system,
                'light': context.l10n.theme_light,
                'dark': context.l10n.theme_dark,
              },
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(themeMode: value),
              ),
            ),
            PickerRowWidget<String>(
              title: context.l10n.app_language,
              value: settings.language,
              items: supportedAppLanguageItems(),
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(language: value),
              ),
            ),
            PickerRowWidget<String>(
              title: context.l10n.translation_language,
              subtitle: context.l10n.translation_language_sub,
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
                (current) => current.copyWith(targetTranslationLanguage: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel(context.l10n.cloud_hosting_section),
        SettingsGroupWidget(
          children: [
            PickerRowWidget<String>(
              title: context.l10n.cloud_provider,
              subtitle: context.l10n.cloud_provider_sub,
              value: settings.cloudImageHost,
              items: {
                'freeimage': context.l10n.cloud_provider_freeimage,
                'imgbb': context.l10n.cloud_provider_imgbb,
                'gdrive': context.l10n.cloud_coming_soon,
              },
              onChanged: (value) {
                if (value == 'gdrive') return;
                updateSettings(
                  ref,
                  (current) => current.copyWith(cloudImageHost: value),
                );
              },
            ),
            if (settings.cloudImageHost == 'imgbb')
              TextRowWidget(
                title: context.l10n.imgbb_api_key,
                value: settings.imgBbApiKey,
                placeholder: context.l10n.api_key_placeholder,
                onChanged: (value) => updateSettings(
                  ref,
                  (current) => current.copyWith(imgBbApiKey: value),
                ),
              )
            else
              TextRowWidget(
                title: context.l10n.freeimage_api_key,
                value: settings.freeImageApiKey,
                placeholder: context.l10n.api_key_placeholder,
                onChanged: (value) => updateSettings(
                  ref,
                  (current) => current.copyWith(freeImageApiKey: value),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: CupertinoSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.accent_color,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
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
                          color: color.withValues(
                            alpha: selected ? 0.18 : 0.08,
                          ),
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
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
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
        ),
      ],
    );
  }
}

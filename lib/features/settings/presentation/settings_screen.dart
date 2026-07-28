import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showLicensePage, LinearProgressIndicator;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/platform/shortcut_config.dart';
import '../../../core/services/update_service.dart';
import '../../../core/ui/cupertino_components.dart';
import '../../../features/ai/domain/ai_model_info.dart';
import '../../../features/ai/services/ai_model_downloader_service.dart';
import '../../clipboard_history/domain/clipboard_content_type.dart';
import '../domain/app_settings.dart';
import '../services/settings_backup_service.dart';

enum _SettingsPage { general, clipboard, privacy, storage, shortcuts, ai, about }

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  var _page = _SettingsPage.general;

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 720;
    final panel = CupertinoSurface(
      borderRadius: compact ? BorderRadius.zero : BorderRadius.circular(22),
      child: SizedBox(
        width: compact ? size.width : 940,
        height: compact ? size.height : size.height.clamp(600, 720),
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Text(
                    'settings_title'.tr,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  CupertinoIconControl(
                    icon: CupertinoIcons.xmark,
                    onPressed: () => _close(context),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            const CupertinoDivider(),
            Expanded(
              child: compact
                  ? Column(
                      children: [
                        SizedBox(
                          height: 56,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.all(8),
                            children: _SettingsPage.values.map((page) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: CupertinoChoicePill(
                                  label: _label(page),
                                  icon: _icon(page),
                                  selected: _page == page,
                                  onPressed: () => setState(() => _page = page),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const CupertinoDivider(),
                        Expanded(child: _SettingsContent(page: _page)),
                      ],
                    )
                  : Row(
                      children: [
                        SizedBox(
                          width: 220,
                          child: ColoredBox(
                            color: resolveColor(context, ClipFlowColors.sidebar),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  for (final page in _SettingsPage.values)
                                    _SettingsNavTile(
                                      icon: _icon(page),
                                      label: _label(page),
                                      selected: _page == page,
                                      onTap: () => setState(() => _page = page),
                                    ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.lock_shield,
                                        size: 15,
                                        color: resolveColor(context, ClipFlowColors.secondaryText),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        'local_data_saved'.tr,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: resolveColor(context, ClipFlowColors.secondaryText),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 1,
                          child: ColoredBox(color: resolveColor(context, ClipFlowColors.border)),
                        ),
                        Expanded(child: _SettingsContent(page: _page)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => _close(context),
      },
      child: Focus(
        autofocus: true,
        child: CupertinoPageScaffold(
          backgroundColor: const Color(0x00000000),
          child: Center(
            child: Padding(
              padding: compact ? EdgeInsets.zero : const EdgeInsets.all(24),
              child: panel,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  const _SettingsNavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoTheme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: CupertinoPressable(
        onPressed: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? primary : const Color(0x00000000),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? CupertinoColors.white : null,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? CupertinoColors.white : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({required this.page});

  final _SettingsPage page;

  @override
  Widget build(BuildContext context) {
    final content = switch (page) {
      _SettingsPage.general => const _GeneralSettings(),
      _SettingsPage.clipboard => const _ClipboardSettings(),
      _SettingsPage.privacy => const _PrivacySettings(),
      _SettingsPage.storage => const _StorageSettings(),
      _SettingsPage.shortcuts => const _ShortcutSettings(),
      _SettingsPage.ai => const _AiSettings(),
      _SettingsPage.about => const _AboutSettings(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 16),
          child: Text(
            _label(page),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
            child: content,
          ),
        ),
      ],
    );
  }
}

class _GeneralSettings extends ConsumerWidget {
  const _GeneralSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsGroup(
          children: [
            _SwitchRow(
              title: 'launch_at_login'.tr,
              subtitle: 'launch_at_login_sub'.tr,
              value: settings.openAtLogin,
              onChanged: (value) async {
                final result = await ref
                    .read(desktopIntegrationProvider)
                    .setOpenAtLogin(value);
                await _update(
                  ref,
                  (current) => current.copyWith(openAtLogin: result.enabled),
                );
                if (!context.mounted) return;
                if (result.needsApproval) {
                  await ref
                      .read(desktopIntegrationProvider)
                      .openLoginItemsSettings();
                  if (!context.mounted) return;
                  if (context.mounted) {
                    showCupertinoNotice(
                      context,
                      'login_items_hint'.tr,
                    );
                  }
                } else {
                  if (!context.mounted) return;
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
            _SwitchRow(
              title: 'run_in_tray'.tr,
              subtitle: 'run_in_tray_sub'.tr,
              value: settings.runInTray,
              onChanged: (value) async {
                final success = await ref
                    .read(desktopIntegrationProvider)
                    .setTrayEnabled(value);
                if (success) {
                  await _update(
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
            _SwitchRow(
              title: 'show_in_dock'.tr,
              subtitle: 'show_in_dock_sub'.tr,
              value: settings.showInDock,
              onChanged: (value) async {
                await ref
                    .read(desktopIntegrationProvider)
                    .setShowInDock(value);
                await _update(
                  ref,
                  (current) => current.copyWith(showInDock: value),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel('sound_enabled'.tr),
        _SettingsGroup(
          children: [
            _SwitchRow(
              title: 'sound_enabled'.tr,
              subtitle: 'sound_enabled_sub'.tr,
              value: settings.soundEnabled,
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(soundEnabled: value),
              ),
            ),
          ],
        ),
        if (Platform.isMacOS) ...[
          const SizedBox(height: 22),
          CupertinoSectionLabel('system_permissions'.tr),
          _SettingsGroup(
            children: [
              FutureBuilder<bool>(
                future: ref
                    .read(desktopIntegrationProvider)
                    .checkAccessibilityPermission(),
                builder: (context, snapshot) {
                  final hasPermission = snapshot.data ?? false;
                  return _SettingsTile(
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
                              color: resolveColor(context, ClipFlowColors.secondaryText),
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
              _SettingsTile(
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
              _SettingsTile(
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
        _SettingsGroup(
          children: [
            _PickerRow<String>(
              title: 'theme_mode'.tr,
              value: settings.themeMode,
              items: {
                'system': 'theme_system'.tr,
                'light': 'theme_light'.tr,
                'dark': 'theme_dark'.tr,
              },
              onChanged: (value) =>
                  _update(ref, (current) => current.copyWith(themeMode: value)),
            ),
            _PickerRow<String>(
              title: 'app_language'.tr,
              value: settings.language,
              items: const {'vi': 'Tiếng Việt', 'en': 'English'},
              onChanged: (value) =>
                  _update(ref, (current) => current.copyWith(language: value)),
            ),
            _PickerRow<String>(
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
              onChanged: (value) => _update(
                ref,
                (current) =>
                    current.copyWith(targetTranslationLanguage: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel('cloud_hosting_section'.tr),
        _SettingsGroup(
          children: [
            _PickerRow<String>(
              title: 'cloud_provider'.tr,
              subtitle: 'cloud_provider_sub'.tr,
              value: settings.cloudImageHost,
              items: {
                'freeimage': 'cloud_in_use'.tr,
                'gdrive': 'cloud_coming_soon'.tr,
              },
              onChanged: (value) {
                if (value == 'gdrive') return;
                _update(ref, (current) => current.copyWith(cloudImageHost: value));
              },
            ),
            _TextRow(
              title: 'FreeImage API Key',
              value: settings.freeImageApiKey,
              placeholder: 'api_key_placeholder'.tr,
              onChanged: (value) => _update(
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
                    onPressed: () => _update(
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

class _ClipboardSettings extends ConsumerWidget {
  const _ClipboardSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsGroup(
          children: [
            _SwitchRow(
              title: 'clipboard_monitoring'.tr,
              subtitle: settings.monitoringEnabled
                  ? 'monitoring_active'.tr
                  : 'monitoring_paused'.tr,
              value: settings.monitoringEnabled,
              onChanged: (value) async {
                await _update(
                  ref,
                  (current) => current.copyWith(monitoringEnabled: value),
                );
                await ref
                    .read(historyControllerProvider.notifier)
                    .setMonitoring(value);
              },
            ),
            _SwitchRow(
              title: 'ignore_duplicates'.tr,
              value: settings.ignoreDuplicates,
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(ignoreDuplicates: value),
              ),
            ),
            _PickerRow<DuplicateBehavior>(
              title: 'duplicate_behavior'.tr,
              value: settings.duplicateBehavior,
              items: {
                DuplicateBehavior.bringToTop: 'bring_to_top'.tr,
                DuplicateBehavior.createNew: 'create_new'.tr,
                DuplicateBehavior.keepPosition: 'keep_position'.tr,
              },
              onChanged: (value) => _update(
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
              label: _typeName(type),
              selected: selected,
              onPressed: () {
                final next = {...settings.allowedTypes};
                selected ? next.remove(type.name) : next.add(type.name);
                _update(ref, (current) => current.copyWith(allowedTypes: next));
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel('content_limits'.tr),
        _SettingsGroup(
          children: [
            _NumberRow(
              title: 'min_length'.tr,
              value: settings.minTextLength,
              suffix: 'chars_unit'.tr,
              min: 1,
              max: 1000,
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(minTextLength: value),
              ),
            ),
            _NumberRow(
              title: 'max_length'.tr,
              value: settings.maxTextLength,
              suffix: 'chars_unit'.tr,
              min: 1000,
              max: 1000000,
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(maxTextLength: value),
              ),
            ),
            _NumberRow(
              title: 'max_image_size'.tr,
              value: settings.maxImageMb,
              suffix: 'MB',
              min: 1,
              max: 100,
              onChanged: (value) => _update(
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

class _PrivacySettings extends ConsumerWidget {
  const _PrivacySettings();

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
        _SettingsGroup(
          children: [
            _SettingsTile(
              title: 'privacy_policy'.tr,
              subtitle: 'privacy_policy_sub'.tr,
              leading: const Icon(
                CupertinoIcons.shield_fill,
                color: CupertinoColors.activeGreen,
              ),
              trailing: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () => _showPrivacyPolicyDialog(context),
                child: Text('view_policy'.tr),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SettingsGroup(
          children: [
            _SwitchRow(
              title: 'ignore_sensitive'.tr,
              value: settings.ignoreSensitive,
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(ignoreSensitive: value),
              ),
            ),
            _SwitchRow(
              title: 'ignore_otp'.tr,
              subtitle: 'ignore_otp_sub'.tr,
              value: settings.ignoreOtp,
              onChanged: settings.ignoreSensitive
                  ? (value) => _update(
                      ref,
                      (current) => current.copyWith(ignoreOtp: value),
                    )
                  : null,
            ),
            _SwitchRow(
              title: 'ignore_long_tokens'.tr,
              value: settings.ignoreLongToken,
              onChanged: settings.ignoreSensitive
                  ? (value) => _update(
                      ref,
                      (current) => current.copyWith(ignoreLongToken: value),
                    )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            CupertinoSectionLabel('excluded_apps'.tr),
            const Spacer(),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onPressed: () => _addExcludedApp(context, ref),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.add, size: 16),
                  const SizedBox(width: 4),
                  Text('add_app'.tr),
                ],
              ),
            ),
          ],
        ),
        _SettingsGroup(
          children: settings.excludedApplications.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('no_excluded_apps'.tr),
                  ),
                ]
              : settings.excludedApplications.map((app) {
                  return _SettingsTile(
                    title: app,
                    leading: const Icon(CupertinoIcons.app, size: 19),
                    trailing: CupertinoIconControl(
                      icon: CupertinoIcons.minus_circle,
                      color: CupertinoColors.systemRed,
                      onPressed: () {
                        final next = [...settings.excludedApplications]
                          ..remove(app);
                        _update(
                          ref,
                          (current) =>
                              current.copyWith(excludedApplications: next),
                        );
                      },
                    ),
                  );
                }).toList(),
        ),
      ],
    );
  }

  Future<void> _addExcludedApp(BuildContext context, WidgetRef ref) async {
    final desktop = ref.read(desktopIntegrationProvider);
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('add_excluded_app_title'.tr),
        message: Text('add_excluded_app_msg'.tr),
        actions: [
          if (Platform.isMacOS) ...[
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 'running'),
              child: Text('select_running_app'.tr),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 'finder'),
              child: Text('select_app_finder'.tr),
            ),
          ],
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'manual'),
            child: Text('enter_app_manual'.tr),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr),
        ),
      ),
    );

    if (action == null || !context.mounted) return;

    String? selectedAppName;
    if (action == 'finder') {
      final picked = await desktop.pickApplicationFile();
      if (picked != null &&
          picked['name'] != null &&
          picked['name']!.isNotEmpty) {
        selectedAppName = picked['name'];
      }
    } else if (action == 'running') {
      final apps = await desktop.getRunningApplications();
      if (!context.mounted) return;
      if (apps.isEmpty) {
        showCupertinoNotice(context, 'running_apps_empty'.tr);
        return;
      }
      selectedAppName = await showCupertinoDialog<String>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('select_running_app_title'.tr),
          content: SizedBox(
            height: 240,
            width: 300,
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 10),
              itemCount: apps.length,
              separatorBuilder: (_, _) => const CupertinoDivider(),
              itemBuilder: (context, index) {
                final app = apps[index];
                final name = app['name'] ?? '';
                return CupertinoPressable(
                  onPressed: () => Navigator.pop(context, name),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.app, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
          ],
        ),
      );
    } else if (action == 'manual') {
      selectedAppName = await _inputDialog(
        context,
        title: 'exclude_app_title'.tr,
        placeholder: 'exclude_app_placeholder'.tr,
      );
    }

    if (selectedAppName == null || selectedAppName.trim().isEmpty) return;
    final current = ref.read(settingsControllerProvider);
    final appName = selectedAppName.trim();
    if (current.excludedApplications.contains(appName)) return;
    await _update(
      ref,
      (settings) => settings.copyWith(
        excludedApplications: [...current.excludedApplications, appName],
      ),
    );
  }
}

class _StorageSettings extends ConsumerWidget {
  const _StorageSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoSectionLabel('history_retention'.tr),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [1, 7, 30, 90, 365, -1].map((days) {
            return CupertinoChoicePill(
              label: days == -1
                  ? 'unlimited'.tr
                  : 'days_ago'.tr.replaceAll('@d', '$days'),
              selected: settings.retentionDays == days,
              onPressed: () async {
                await _update(
                  ref,
                  (current) => current.copyWith(retentionDays: days),
                );
                await ref
                    .read(clipboardRepositoryProvider)
                    .cleanup(ref.read(settingsControllerProvider));
                await ref.read(historyControllerProvider.notifier).reload();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          children: [
            _NumberRow(
              title: 'max_items'.tr,
              value: settings.maxItems,
              suffix: 'items_unit'.tr,
              min: 100,
              max: 100000,
              onChanged: (value) =>
                  _update(ref, (current) => current.copyWith(maxItems: value)),
            ),
            _NumberRow(
              title: 'max_storage'.tr,
              value: settings.maxDatabaseMb,
              suffix: 'MB',
              min: 50,
              max: 10240,
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(maxDatabaseMb: value),
              ),
            ),
            _SwitchRow(
              title: 'delete_images_first'.tr,
              value: settings.deleteImagesFirst,
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(deleteImagesFirst: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel('data_protection'.tr),
        _SettingsGroup(
          children: [
            _SwitchRow(
              title: 'protect_pinned'.tr,
              value: settings.protectPinned,
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(protectPinned: value),
              ),
            ),
            _SwitchRow(
              title: 'protect_collections'.tr,
              value: settings.protectCollections,
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(protectCollections: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel('backup_restore_section'.tr),
        _SettingsGroup(
          children: [
            _SettingsTile(
              title: 'export_config'.tr,
              subtitle: 'export_config_sub'.tr,
              leading: const Icon(
                CupertinoIcons.square_arrow_up,
                color: CupertinoColors.activeBlue,
              ),
              trailing: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () => _exportConfig(context, ref),
                child: Text('export_button'.tr),
              ),
            ),
            _SettingsTile(
              title: 'import_config'.tr,
              subtitle: 'import_config_sub'.tr,
              leading: const Icon(
                CupertinoIcons.square_arrow_down,
                color: CupertinoColors.activeGreen,
              ),
              trailing: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () => _importConfig(context, ref),
                child: Text('import_button'.tr),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        FutureBuilder<int>(
          future: ref
              .read(clipboardRepositoryProvider)
              .approximateStorageBytes(),
          builder: (context, snapshot) {
            final megabytes = (snapshot.data ?? 0) / (1024 * 1024);
            return CupertinoSurface(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.archivebox),
                  const SizedBox(width: 12),
                  Expanded(child: Text('current_storage_usage'.tr)),
                  Text('${megabytes.toStringAsFixed(1)} MB'),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: CupertinoButton(
            color: CupertinoColors.systemRed.withValues(alpha: 0.12),
            onPressed: () => _clearHistory(context, ref),
            child: Text(
              'clear_history'.tr,
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportConfig(BuildContext context, WidgetRef ref) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    final pwd = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text('export_dialog_title'.tr),
          content: Column(
            children: [
              const SizedBox(height: 10),
              Text('export_dialog_msg'.tr),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: passwordController,
                obscureText: true,
                placeholder: 'password'.tr,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: confirmController,
                obscureText: true,
                placeholder: 'confirm_password'.tr,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: Text('cancel'.tr),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final p1 = passwordController.text.trim();
                final p2 = confirmController.text.trim();
                if (p1.isEmpty) {
                  showCupertinoNotice(dialogContext, 'password_empty'.tr);
                  return;
                }
                if (p1 != p2) {
                  showCupertinoNotice(dialogContext, 'password_mismatch'.tr);
                  return;
                }
                Navigator.pop(dialogContext, p1);
              },
              child: Text('export_button'.tr),
            ),
          ],
        );
      },
    );

    if (pwd == null || pwd.isEmpty) return;

    final desktop = ref.read(desktopIntegrationProvider);
    final nowStr = DateTime.now().toString().split(' ').first.replaceAll('-', '');
    final filePath = await desktop.saveConfigFile(
      defaultName: 'clipflow_settings_$nowStr.clipflow',
    );

    if (filePath == null || filePath.isEmpty) return;

    final backupService = const SettingsBackupService();
    final result = await backupService.exportSettings(
      settings: ref.read(settingsControllerProvider),
      password: pwd,
      filePath: filePath,
    );

    if (context.mounted) {
      if (result.isSuccess) {
        showCupertinoNotice(context, 'export_success'.tr);
      } else {
        showCupertinoNotice(context, result.errorMessage ?? 'export_failed'.tr);
      }
    }
  }

  Future<void> _importConfig(BuildContext context, WidgetRef ref) async {
    final desktop = ref.read(desktopIntegrationProvider);
    final filePath = await desktop.pickConfigFile();

    if (filePath == null || filePath.isEmpty) return;

    if (!context.mounted) return;

    final passwordController = TextEditingController();
    final pwd = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text('import_dialog_title'.tr),
          content: Column(
            children: [
              const SizedBox(height: 10),
              Text('import_dialog_msg'.tr),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: passwordController,
                obscureText: true,
                placeholder: 'decrypt_password'.tr,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: Text('cancel'.tr),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final p = passwordController.text.trim();
                if (p.isEmpty) {
                  showCupertinoNotice(dialogContext, 'password_empty'.tr);
                  return;
                }
                Navigator.pop(dialogContext, p);
              },
              child: Text('import_button'.tr),
            ),
          ],
        );
      },
    );

    if (pwd == null || pwd.isEmpty) return;

    final backupService = const SettingsBackupService();
    final result = await backupService.importSettings(
      filePath: filePath,
      password: pwd,
    );

    if (!context.mounted) return;

    if (result.isSuccess && result.settings != null) {
      await ref
          .read(settingsControllerProvider.notifier)
          .update((_) => result.settings!);
      if (context.mounted) {
        showCupertinoNotice(context, 'import_success'.tr);
      }
    } else {
      showCupertinoNotice(
        context,
        result.errorMessage ?? 'import_failed'.tr,
      );
    }
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('clear_history_title'.tr),
        content: Text('clear_history_msg'.tr),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(historyControllerProvider.notifier).clearHistory();
    }
  }
}

class _ShortcutSettings extends ConsumerWidget {
  const _ShortcutSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsGroup(
          children: [
            _ShortcutTile(
              title: 'open_quick_panel'.tr,
              subtitle: 'shortcuts_title'.tr,
              hotKey: decodeShortcut(
                settings.openPanelShortcut,
                ShortcutAction.openPanel,
              ),
              onTap: () =>
                  _editShortcut(context, ref, ShortcutAction.openPanel),
            ),
            _ShortcutTile(
              title: 'focus_search'.tr,
              hotKey: decodeShortcut(
                settings.focusSearchShortcut,
                ShortcutAction.focusSearch,
              ),
              onTap: () =>
                  _editShortcut(context, ref, ShortcutAction.focusSearch),
            ),
            _ShortcutTile(
              title: 'toggle_pin'.tr,
              hotKey: decodeShortcut(
                settings.togglePinShortcut,
                ShortcutAction.togglePin,
              ),
              onTap: () =>
                  _editShortcut(context, ref, ShortcutAction.togglePin),
            ),
            _SettingsTile(
              title: 'select_and_copy'.tr,
              trailing: const _KeyCaps(label: '↑  ↓  Enter'),
            ),
            _ShortcutTile(
              title: 'delete_item'.tr,
              hotKey: decodeShortcut(
                settings.deleteItemShortcut,
                ShortcutAction.deleteItem,
              ),
              onTap: () =>
                  _editShortcut(context, ref, ShortcutAction.deleteItem),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: CupertinoButton(
            onPressed: () => _resetShortcuts(context, ref),
            child: Text('restore_defaults'.tr),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'shortcut_hint'.tr,
          style: TextStyle(color: resolveColor(context, ClipFlowColors.secondaryText), height: 1.5),
        ),
      ],
    );
  }

  Future<void> _editShortcut(
    BuildContext context,
    WidgetRef ref,
    ShortcutAction action,
  ) async {
    final settings = ref.read(settingsControllerProvider);
    final recorded = await showCupertinoDialog<HotKey>(
      context: context,
      builder: (_) => _ShortcutRecorderDialog(
        action: action,
        initialHotKey: decodeShortcut(
          _shortcutSource(settings, action),
          action,
        ),
      ),
    );
    if (recorded == null || !context.mounted) return;
    final signatures = <ShortcutAction, String>{
      for (final candidate in ShortcutAction.values)
        candidate: shortcutSignature(
          decodeShortcut(_shortcutSource(settings, candidate), candidate),
        ),
    }..remove(action);
    if (signatures.containsValue(shortcutSignature(recorded))) {
      showCupertinoNotice(context, 'shortcut_conflict'.tr);
      return;
    }
    if (action == ShortcutAction.openPanel) {
      final registered = await ref
          .read(desktopIntegrationProvider)
          .registerGlobalHotKey(recorded);
      if (!registered) {
        if (context.mounted) {
          showCupertinoNotice(context, 'shortcut_used_by_other_app'.tr);
        }
        return;
      }
    }
    await _update(ref, (current) => _withShortcut(current, action, recorded));
    if (context.mounted) {
      showCupertinoNotice(context, 'saved_shortcut'.tr.replaceAll('@s', shortcutLabel(recorded)));
    }
  }

  Future<void> _resetShortcuts(BuildContext context, WidgetRef ref) async {
    final open = defaultShortcut(ShortcutAction.openPanel);
    final registered = await ref
        .read(desktopIntegrationProvider)
        .registerGlobalHotKey(open);
    if (!registered) {
      if (context.mounted) {
        showCupertinoNotice(context, 'shortcut_used_by_other_app'.tr);
      }
      return;
    }
    await _update(
      ref,
      (current) => current.copyWith(
        shortcut: shortcutLabel(open),
        openPanelShortcut: encodeShortcut(open),
        focusSearchShortcut: encodeShortcut(
          defaultShortcut(ShortcutAction.focusSearch),
        ),
        togglePinShortcut: encodeShortcut(
          defaultShortcut(ShortcutAction.togglePin),
        ),
        deleteItemShortcut: encodeShortcut(
          defaultShortcut(ShortcutAction.deleteItem),
        ),
      ),
    );
    if (context.mounted) {
      showCupertinoNotice(context, 'reset_shortcuts_success'.tr);
    }
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.title,
    required this.hotKey,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final HotKey hotKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _KeyCaps(label: shortcutLabel(hotKey)),
          const SizedBox(width: 7),
          const Icon(CupertinoIcons.pencil, size: 16),
        ],
      ),
    );
  }
}

class _ShortcutRecorderDialog extends StatefulWidget {
  const _ShortcutRecorderDialog({
    required this.action,
    required this.initialHotKey,
  });

  final ShortcutAction action;
  final HotKey initialHotKey;

  @override
  State<_ShortcutRecorderDialog> createState() =>
      _ShortcutRecorderDialogState();
}

class _ShortcutRecorderDialogState extends State<_ShortcutRecorderDialog> {
  HotKey? _recorded;
  String? _error;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    final pressed = HardwareKeyboard.instance.physicalKeysPressed;
    var modifiers = HotKeyModifier.values
        .where((item) => item.physicalKeys.any(pressed.contains))
        .where((item) => !item.physicalKeys.contains(event.physicalKey))
        .toList();
    final value = HotKey(
      key: event.physicalKey,
      modifiers: modifiers,
      scope: widget.action == ShortcutAction.openPanel
          ? HotKeyScope.system
          : HotKeyScope.inapp,
    );
    setState(() {
      _recorded = value;
      _error = null;
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final value = _recorded ?? widget.initialHotKey;
    return CupertinoAlertDialog(
      title: Text('record_shortcut_title'.tr),
      content: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          children: [
            Text('record_shortcut_msg'.tr),
            const SizedBox(height: 14),
            CupertinoSurface(
              padding: const EdgeInsets.all(14),
              color: resolveColor(context, ClipFlowColors.elevatedSurface),
              child: Center(child: _KeyCaps(label: shortcutLabel(value))),
            ),
            if (_error != null) ...[
              const SizedBox(height: 9),
              Text(
                _error!,
                style: const TextStyle(color: CupertinoColors.systemRed),
              ),
            ],
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr),
        ),
        CupertinoDialogAction(
          onPressed: () {
            if (!isValidShortcut(value, widget.action)) {
              setState(() {
                _error = widget.action == ShortcutAction.openPanel
                    ? 'system_hotkey_needs_modifier'.tr
                    : 'choose_non_modifier'.tr;
              });
              return;
            }
            Navigator.pop(context, value);
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

class _AboutSettings extends ConsumerStatefulWidget {
  const _AboutSettings();

  @override
  ConsumerState<_AboutSettings> createState() => _AboutSettingsState();
}

class _AboutSettingsState extends ConsumerState<_AboutSettings> {
  bool _checkingUpdate = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _updateStatus;
  UpdateInfo? _updateInfo;

  Future<void> _checkUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _updateStatus = null;
      _updateInfo = null;
    });

    const service = UpdateService();
    final info = await service.checkForUpdate();

    if (!mounted) return;
    if (info == null) {
      setState(() {
        _checkingUpdate = false;
        _updateStatus = 'update_check_failed'.tr;
      });
      return;
    }

    setState(() {
      _checkingUpdate = false;
      _updateInfo = info;
      _updateStatus = info.hasUpdate
          ? 'update_available_version'.tr.replaceAll('@v', info.latestVersion)
          : 'latest_version_msg'.tr.replaceAll('@v', info.currentVersion);
    });
  }

  Future<void> _downloadAndInstall() async {
    final info = _updateInfo;
    final desktop = ref.read(desktopIntegrationProvider);
    if (info == null) return;

    if (info.downloadUrl == null) {
      await desktop.openUrl(
        info.releasePageUrl ?? 'https://github.com/vqh2602/paste_plus/releases',
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _updateStatus = 'downloading_update'.tr.replaceAll('@p', '0');
    });

    const service = UpdateService();
    final success = await service.downloadAndInstallUpdate(
      downloadUrl: info.downloadUrl!,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
            final percent = (progress * 100).toInt();
            _updateStatus = 'downloading_update'.tr.replaceAll('@p', '$percent');
          });
        }
      },
    );

    if (!mounted) return;
    if (!success) {
      setState(() {
        _isDownloading = false;
        _updateStatus = 'cannot_auto_install'.tr;
      });
      await desktop.openUrl(
        info.releasePageUrl ?? 'https://github.com/vqh2602/paste_plus/releases',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = ref.read(desktopIntegrationProvider);
    final hasUpdate = _updateInfo?.hasUpdate ?? false;
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/branding/clipflow_app_icon.png',
              width: 82,
              height: 82,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'ClipFlow',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            'version_label'.tr.replaceAll('@v', UpdateService.currentVersion),
            style: TextStyle(
              color: resolveColor(context, ClipFlowColors.secondaryText),
            ),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              'app_description'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _SettingsGroup(
              children: [
                _SettingsTile(
                  title: 'github_source'.tr,
                  subtitle: 'github.com/vqh2602/paste_plus',
                  leading: const Icon(
                    CupertinoIcons.square_arrow_up_on_square,
                    color: CupertinoColors.activeBlue,
                  ),
                  trailing: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: () =>
                        desktop.openUrl('https://github.com/vqh2602/paste_plus'),
                    child: Text('visit'.tr),
                  ),
                ),
                _SettingsTile(
                  title: 'check_updates'.tr,
                  subtitle:
                      _updateStatus ??
                      'check_updates'.tr,
                  leading: Icon(
                    hasUpdate
                        ? CupertinoIcons.arrow_down_circle_fill
                        : CupertinoIcons.refresh_circled,
                    color:
                        hasUpdate
                            ? CupertinoColors.activeGreen
                            : CupertinoColors.activeBlue,
                  ),
                  trailing: _checkingUpdate || _isDownloading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isDownloading)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  '${(_downloadProgress * 100).toInt()}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: resolveColor(
                                      context,
                                      ClipFlowColors.secondaryText,
                                    ),
                                  ),
                                ),
                              ),
                            const CupertinoActivityIndicator(radius: 8),
                          ],
                        )
                      : CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          onPressed:
                              hasUpdate ? _downloadAndInstall : _checkUpdate,
                          child: Text(hasUpdate ? 'update_available'.tr : 'check'.tr),
                        ),
                ),
                _SettingsTile(
                  title: 'privacy_policy'.tr,
                  subtitle: 'privacy_policy_sub'.tr,
                  leading: const Icon(
                    CupertinoIcons.shield_fill,
                    color: CupertinoColors.activeGreen,
                  ),
                  trailing: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: () => _showPrivacyPolicyDialog(context),
                    child: Text('view_policy'.tr),
                  ),
                ),
                _SettingsTile(
                  title: 'license'.tr,
                  subtitle: 'license_sub'.tr,
                  leading: const Icon(
                    CupertinoIcons.doc_text_fill,
                    color: CupertinoColors.activeOrange,
                  ),
                  trailing: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: () => _showLicenseDialog(context),
                    child: Text('view_license'.tr),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CupertinoSurface(
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const CupertinoDivider(indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: resolveColor(context, ClipFlowColors.secondaryText),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
    return onTap == null
        ? content
        : CupertinoPressable(onPressed: onTap, child: content);
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: title,
      subtitle: subtitle,
      trailing: CupertinoSwitch(value: value, onChanged: onChanged),
    );
  }
}

class _PickerRow<T> extends StatelessWidget {
  const _PickerRow({
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: title,
      subtitle: subtitle,
      onTap: () => _pick(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            items[value] ?? '',
            style: TextStyle(color: resolveColor(context, ClipFlowColors.secondaryText)),
          ),
          const SizedBox(width: 6),
          const Icon(CupertinoIcons.chevron_right, size: 14),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final selected = await showCupertinoModalPopup<T>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        actions: items.entries.map((entry) {
          return CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, entry.key),
            child: Text(entry.value),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
      ),
    );
    if (selected != null) onChanged(selected);
  }
}

class _NumberRow extends StatefulWidget {
  const _NumberRow({
    required this.title,
    required this.value,
    required this.suffix,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final int value;
  final String suffix;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberRow> createState() => _NumberRowState();
}

class _NumberRowState extends State<_NumberRow> {
  late final controller = TextEditingController(text: '${widget.value}');

  @override
  void didUpdateWidget(covariant _NumberRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        controller.text != '${widget.value}') {
      controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: widget.title,
      trailing: SizedBox(
        width: 145,
        child: CupertinoTextField(
          controller: controller,
          textAlign: TextAlign.end,
          keyboardType: TextInputType.number,
          suffix: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              widget.suffix,
              style: TextStyle(
                fontSize: 12,
                color: resolveColor(context, ClipFlowColors.secondaryText),
              ),
            ),
          ),
          onSubmitted: (source) {
            final parsed = int.tryParse(source);
            if (parsed != null) {
              widget.onChanged(parsed.clamp(widget.min, widget.max));
            }
          },
        ),
      ),
    );
  }
}

class _TextRow extends StatefulWidget {
  const _TextRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.placeholder,
  });

  final String title;
  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;

  @override
  State<_TextRow> createState() => _TextRowState();
}

class _TextRowState extends State<_TextRow> {
  late final controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _TextRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && controller.text != widget.value) {
      controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: widget.title,
      trailing: SizedBox(
        width: 240,
        child: CupertinoTextField(
          controller: controller,
          textAlign: TextAlign.end,
          placeholder: widget.placeholder,
          style: const TextStyle(fontSize: 13),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}

class _KeyCaps extends StatelessWidget {
  const _KeyCaps({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: resolveColor(context, ClipFlowColors.elevatedSurface),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: resolveColor(context, ClipFlowColors.border)),
        boxShadow: const [
          BoxShadow(color: Color(0x15000000), offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

Future<void> _update(
  WidgetRef ref,
  AppSettings Function(AppSettings current) change,
) {
  return ref.read(settingsControllerProvider.notifier).update(change);
}

Future<String?> _inputDialog(
  BuildContext context, {
  required String title,
  required String placeholder,
}) async {
  final controller = TextEditingController();
  final result = await showCupertinoDialog<String>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: controller,
          autofocus: true,
          placeholder: placeholder,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Thêm'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result == null || result.trim().isEmpty) return null;
  return result.trim();
}

String? _shortcutSource(AppSettings settings, ShortcutAction action) {
  return switch (action) {
    ShortcutAction.openPanel => settings.openPanelShortcut,
    ShortcutAction.focusSearch => settings.focusSearchShortcut,
    ShortcutAction.togglePin => settings.togglePinShortcut,
    ShortcutAction.deleteItem => settings.deleteItemShortcut,
  };
}

AppSettings _withShortcut(
  AppSettings settings,
  ShortcutAction action,
  HotKey hotKey,
) {
  final encoded = encodeShortcut(hotKey);
  return switch (action) {
    ShortcutAction.openPanel => settings.copyWith(
      shortcut: shortcutLabel(hotKey),
      openPanelShortcut: encoded,
    ),
    ShortcutAction.focusSearch => settings.copyWith(
      focusSearchShortcut: encoded,
    ),
    ShortcutAction.togglePin => settings.copyWith(togglePinShortcut: encoded),
    ShortcutAction.deleteItem => settings.copyWith(deleteItemShortcut: encoded),
  };
}

String _typeName(ClipboardContentType type) => switch (type) {
  ClipboardContentType.text => 'Văn bản',
  ClipboardContentType.url => 'URL',
  ClipboardContentType.email => 'Email',
  ClipboardContentType.phone => 'Điện thoại',
  ClipboardContentType.code => 'Code',
  ClipboardContentType.color => 'Màu HEX',
  ClipboardContentType.json => 'JSON',
  ClipboardContentType.file => 'Đường dẫn file',
  ClipboardContentType.image => 'Hình ảnh',
};

String _label(_SettingsPage page) => switch (page) {
  _SettingsPage.general => 'tab_general'.tr,
  _SettingsPage.clipboard => 'tab_clipboard'.tr,
  _SettingsPage.privacy => 'tab_privacy'.tr,
  _SettingsPage.storage => 'tab_storage'.tr,
  _SettingsPage.shortcuts => 'tab_shortcuts'.tr,
  _SettingsPage.ai => 'tab_ai'.tr,
  _SettingsPage.about => 'tab_about'.tr,
};

IconData _icon(_SettingsPage page) => switch (page) {
  _SettingsPage.general => CupertinoIcons.settings,
  _SettingsPage.clipboard => CupertinoIcons.doc_on_clipboard,
  _SettingsPage.privacy => CupertinoIcons.hand_raised,
  _SettingsPage.storage => CupertinoIcons.archivebox,
  _SettingsPage.shortcuts => CupertinoIcons.keyboard,
  _SettingsPage.ai => CupertinoIcons.sparkles,
  _SettingsPage.about => CupertinoIcons.info,
};

class _AiSettings extends ConsumerWidget {
  const _AiSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final aiState = ref.watch(aiControllerProvider);
    final aiNotifier = ref.read(aiControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Privacy Callout Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.shield_fill,
                size: 22,
                color: CupertinoTheme.of(context).primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '100% Riêng tư & Ngoại tuyến (Offline)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ai_privacy_notice'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: resolveColor(context, ClipFlowColors.secondaryText),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Toggle Switch for AI Feature
        _SettingsGroup(
          children: [
            _SwitchRow(
              title: 'ai_enabled'.tr,
              subtitle: 'ai_enabled_sub'.tr,
              value: settings.aiEnabled,
              onChanged: (value) {
                _update(
                  ref,
                  (current) => current.copyWith(aiEnabled: value),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Thinking AI Models List Section
        CupertinoSectionLabel('ai_model_selection'.tr),
        Text(
          'ai_model_selection_sub'.tr,
          style: TextStyle(
            fontSize: 12,
            color: resolveColor(context, ClipFlowColors.secondaryText),
          ),
        ),
        const SizedBox(height: 12),

        ...AiModelInfo.thinkingModels.map((model) {
          final isSelected = aiState.selectedModelId == model.id;
          final downloadState =
              aiState.downloadStates[model.id] ?? DownloadState.notDownloaded;
          final progress = aiState.downloadProgresses[model.id];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CupertinoSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CupertinoPressable(
                        onPressed: () => aiNotifier.selectModel(model.id),
                        child: Icon(
                          isSelected
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.circle,
                          color: isSelected
                              ? CupertinoTheme.of(context).primaryColor
                              : resolveColor(context, ClipFlowColors.secondaryText),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    model.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemPurple
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Thinking Model',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.systemPurple,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              model.description,
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
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Kích thước: ${model.fileSizeFormatted} • ${model.parameterSize}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: resolveColor(
                            context,
                            ClipFlowColors.secondaryText,
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Download / Delete Status Buttons
                      if (downloadState == DownloadState.downloaded) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: CupertinoColors.activeGreen
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.checkmark_alt_circle_fill,
                                size: 12,
                                color: CupertinoColors.activeGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ai_downloaded'.tr,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.activeGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          onPressed: () => aiNotifier.deleteModel(model.id),
                          child: Text(
                            'ai_delete_model'.tr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemRed,
                            ),
                          ),
                        ),
                      ] else if (downloadState == DownloadState.downloading) ...[
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          onPressed: () => aiNotifier.cancelDownload(model.id),
                          child: const Text(
                            'Hủy tải',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemOrange,
                            ),
                          ),
                        ),
                      ] else ...[
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          onPressed: () => aiNotifier.startDownload(model),
                          child: Text(
                            'ai_download_model'.tr,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Download Progress Bar
                  if (downloadState == DownloadState.downloading && progress != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.progress,
                        backgroundColor: resolveColor(context, ClipFlowColors.border),
                        valueColor: AlwaysStoppedAnimation(
                          CupertinoTheme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${progress.bytesFormatted} (${progress.percentage}%)',
                          style: TextStyle(
                            fontSize: 11,
                            color: resolveColor(context, ClipFlowColors.secondaryText),
                          ),
                        ),
                        Text(
                          progress.speedFormatted,
                          style: TextStyle(
                            fontSize: 11,
                            color: resolveColor(context, ClipFlowColors.secondaryText),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

void _showPrivacyPolicyDialog(BuildContext context) {
  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.shield_fill,
              color: CupertinoColors.activeGreen,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text('privacy_policy'.tr),
          ],
        ),
      ),
      content: SizedBox(
        width: 440,
        height: 280,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'privacy_policy_sub'.tr,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                '• 100% Local-First: Tất cả lịch sử clipboard được lưu trữ cục bộ trong cơ sở dữ liệu SQLite trên thiết bị của bạn.\n'
                '• Zero Tracking & Analytics: ClipFlow không thu thập bất kỳ dữ liệu cá nhân hay thống kê sử dụng nào.\n'
                '• No Cloud Servers: Không có máy chủ đám mây lưu trữ dữ liệu clipboard của bạn.\n'
                '• Bảo vệ dữ liệu nhạy cảm: Tự động bỏ qua trình quản lý mật khẩu (Bitwarden, 1Password), mã OTP và token bí mật.\n'
                '• Toàn quyền kiểm soát: Người dùng có thể xóa lịch sử hoặc xuất/nhập tệp sao lưu mã hóa bất kỳ lúc nào.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('close'.tr),
        ),
      ],
    ),
  );
}

void _showLicenseDialog(BuildContext context) {
  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.doc_text_fill,
              color: CupertinoColors.activeOrange,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text('license'.tr),
          ],
        ),
      ),
      content: const SizedBox(
        width: 440,
        height: 280,
        child: SingleChildScrollView(
          child: Text(
            'MIT License\n\n'
            'Copyright (c) 2026 ClipFlow Authors\n\n'
            'Permission is hereby granted, free of charge, to any person obtaining a copy '
            'of this software and associated documentation files (the "Software"), to deal '
            'in the Software without restriction, including without limitation the rights '
            'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell '
            'copies of the Software, and to permit persons to whom the Software is '
            'furnished to do so, subject to the following conditions:\n\n'
            'The above copyright notice and this permission notice shall be included in all '
            'copies or substantial portions of the Software.\n\n'
            'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR '
            'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, '
            'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE '
            'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER '
            'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, '
            'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE '
            'SOFTWARE.',
            style: TextStyle(fontSize: 11, fontFamily: 'monospace', height: 1.3),
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () {
            Navigator.of(context).pop();
            showLicensePage(
              context: context,
              applicationName: 'ClipFlow',
              applicationVersion: UpdateService.currentVersion,
              applicationLegalese:
                  'Copyright © 2026 ClipFlow Authors (MIT License)',
            );
          },
          child: const Text('Flutter Licenses'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text('close'.tr),
        ),
      ],
    ),
  );
}

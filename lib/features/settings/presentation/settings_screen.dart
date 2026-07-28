import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../core/localization/app_translations.dart';
import '../../../core/ui/cupertino_components.dart';
import 'widgets/about_settings_section.dart';
import 'widgets/ai_settings_section.dart';
import 'widgets/clipboard_settings_section.dart';
import 'widgets/general_settings_section.dart';
import 'widgets/privacy_settings_section.dart';
import 'widgets/shortcut_settings_section.dart';
import 'widgets/storage_settings_section.dart';

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
      _SettingsPage.general => const GeneralSettingsSection(),
      _SettingsPage.clipboard => const ClipboardSettingsSection(),
      _SettingsPage.privacy => const PrivacySettingsSection(),
      _SettingsPage.storage => const StorageSettingsSection(),
      _SettingsPage.shortcuts => const ShortcutSettingsSection(),
      _SettingsPage.ai => const AiSettingsSection(),
      _SettingsPage.about => const AboutSettingsSection(),
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

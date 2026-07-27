import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../../app/providers.dart';
import '../../../core/platform/shortcut_config.dart';
import '../../../core/ui/cupertino_components.dart';
import '../../clipboard_history/domain/clipboard_content_type.dart';
import '../domain/app_settings.dart';

enum _SettingsPage { general, clipboard, privacy, storage, shortcuts, about }

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
                  const Text(
                    'Cài đặt ClipFlow',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                            color: ClipFlowColors.sidebar,
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
                                  const Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.lock_shield,
                                        size: 15,
                                        color: ClipFlowColors.secondaryText,
                                      ),
                                      SizedBox(width: 7),
                                      Text(
                                        'Dữ liệu lưu cục bộ',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: ClipFlowColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 1,
                          child: ColoredBox(color: ClipFlowColors.border),
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
              title: 'Mở khi đăng nhập',
              subtitle: 'Khởi động ClipFlow cùng hệ điều hành.',
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
                  if (context.mounted) {
                    showCupertinoNotice(
                      context,
                      'Hãy bật ClipFlow trong Login Items.',
                    );
                  }
                } else if (result.errorMessage != null ||
                    result.enabled != value) {
                  showCupertinoNotice(
                    context,
                    'Không thể thay đổi “Mở khi đăng nhập”.',
                  );
                } else {
                  showCupertinoNotice(
                    context,
                    value
                        ? 'ClipFlow sẽ mở khi đăng nhập.'
                        : 'Đã tắt mở cùng hệ thống.',
                  );
                }
              },
            ),
            _SwitchRow(
              title: 'Chạy trong menu bar',
              subtitle: 'Truy cập ClipFlow khi cửa sổ chính đã đóng.',
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
                              ? 'Icon ClipFlow đang ở menu bar.'
                              : 'Đã ẩn icon menu bar.')
                        : 'Không thể cập nhật menu bar.',
                  );
                }
              },
            ),
            _SwitchRow(
              title: 'Hiển thị trong Dock',
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
        const CupertinoSectionLabel('Khi sử dụng item'),
        _SettingsGroup(
          children: [
            _SwitchRow(
              title: 'Âm thanh khi sao chép',
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
          const CupertinoSectionLabel('Quyền hệ thống'),
          _SettingsGroup(
            children: [
              FutureBuilder<bool>(
                future: ref
                    .read(desktopIntegrationProvider)
                    .checkAccessibilityPermission(),
                builder: (context, snapshot) {
                  final hasPermission = snapshot.data ?? false;
                  return _SettingsTile(
                    title: 'Quyền Trợ năng (Accessibility)',
                    subtitle: hasPermission
                        ? 'Đã cấp quyền. ClipFlow tự động dán (paste) khi bạn chọn item.'
                        : 'Cần cấp quyền để ClipFlow tự động điền giá trị vào ô soạn thảo.',
                    leading: Icon(
                      hasPermission
                          ? CupertinoIcons.checkmark_shield
                          : CupertinoIcons.exclamationmark_shield,
                      color: hasPermission
                          ? CupertinoColors.systemGreen
                          : CupertinoColors.systemOrange,
                    ),
                    trailing: hasPermission
                        ? const Text(
                            'Đã cấp',
                            style: TextStyle(
                              fontSize: 13,
                              color: ClipFlowColors.secondaryText,
                            ),
                          )
                        : CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            onPressed: () async {
                              await ref
                                  .read(desktopIntegrationProvider)
                                  .requestAccessibilityPermission();
                            },
                            child: const Text('Cấp quyền'),
                          ),
                  );
                },
              ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        const CupertinoSectionLabel('Giao diện'),
        _SettingsGroup(
          children: [
            _PickerRow<String>(
              title: 'Chủ đề',
              value: settings.themeMode,
              items: const {
                'system': 'Theo hệ thống',
                'light': 'Sáng',
                'dark': 'Tối',
              },
              onChanged: (value) =>
                  _update(ref, (current) => current.copyWith(themeMode: value)),
            ),
            _PickerRow<String>(
              title: 'Ngôn ngữ',
              value: settings.language,
              items: const {'vi': 'Tiếng Việt', 'en': 'English'},
              onChanged: (value) =>
                  _update(ref, (current) => current.copyWith(language: value)),
            ),
          ],
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
              title: 'Theo dõi clipboard',
              subtitle: settings.monitoringEnabled
                  ? 'ClipFlow đang ghi nhận nội dung mới.'
                  : 'Lịch sử mới đang tạm dừng.',
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
              title: 'Không lưu nội dung trùng',
              value: settings.ignoreDuplicates,
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(ignoreDuplicates: value),
              ),
            ),
            _PickerRow<DuplicateBehavior>(
              title: 'Khi nội dung đã tồn tại',
              value: settings.duplicateBehavior,
              items: const {
                DuplicateBehavior.bringToTop: 'Đưa lên đầu',
                DuplicateBehavior.createNew: 'Tạo item mới',
                DuplicateBehavior.keepPosition: 'Giữ nguyên vị trí',
              },
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(duplicateBehavior: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const CupertinoSectionLabel('Loại nội dung được lưu'),
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
        const CupertinoSectionLabel('Giới hạn nội dung'),
        _SettingsGroup(
          children: [
            _NumberRow(
              title: 'Độ dài tối thiểu',
              value: settings.minTextLength,
              suffix: 'ký tự',
              min: 1,
              max: 1000,
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(minTextLength: value),
              ),
            ),
            _NumberRow(
              title: 'Độ dài tối đa',
              value: settings.maxTextLength,
              suffix: 'ký tự',
              min: 1000,
              max: 1000000,
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(maxTextLength: value),
              ),
            ),
            _NumberRow(
              title: 'Kích thước ảnh tối đa',
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
          child: const Row(
            children: [
              Icon(CupertinoIcons.lock_shield),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nội dung clipboard chỉ được lưu trong cơ sở dữ liệu trên thiết bị này.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SettingsGroup(
          children: [
            _SwitchRow(
              title: 'Bỏ qua nội dung nhạy cảm',
              value: settings.ignoreSensitive,
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(ignoreSensitive: value),
              ),
            ),
            _SwitchRow(
              title: 'Bỏ qua mã OTP',
              subtitle: 'Chuỗi chỉ gồm 4–8 chữ số.',
              value: settings.ignoreOtp,
              onChanged: settings.ignoreSensitive
                  ? (value) => _update(
                      ref,
                      (current) => current.copyWith(ignoreOtp: value),
                    )
                  : null,
            ),
            _SwitchRow(
              title: 'Bỏ qua token dài',
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
            const CupertinoSectionLabel('Ứng dụng bị loại trừ'),
            const Spacer(),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onPressed: () => _addExcludedApp(context, ref),
              child: const Row(
                children: [
                  Icon(CupertinoIcons.add, size: 16),
                  SizedBox(width: 4),
                  Text('Thêm'),
                ],
              ),
            ),
          ],
        ),
        _SettingsGroup(
          children: settings.excludedApplications.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chưa có ứng dụng nào bị loại trừ.'),
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
    final value = await _inputDialog(
      context,
      title: 'Loại trừ ứng dụng',
      placeholder: 'Ví dụ: Bitwarden',
    );
    if (value == null) return;
    final current = ref.read(settingsControllerProvider);
    await _update(
      ref,
      (settings) => settings.copyWith(
        excludedApplications: [...current.excludedApplications, value],
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
        const CupertinoSectionLabel('Giữ lịch sử'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [1, 7, 30, 90, 365, -1].map((days) {
            return CupertinoChoicePill(
              label: days == -1 ? 'Không giới hạn' : '$days ngày',
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
              title: 'Số item tối đa',
              value: settings.maxItems,
              suffix: 'item',
              min: 100,
              max: 100000,
              onChanged: (value) =>
                  _update(ref, (current) => current.copyWith(maxItems: value)),
            ),
            _NumberRow(
              title: 'Dung lượng tối đa',
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
              title: 'Ưu tiên xóa hình ảnh',
              value: settings.deleteImagesFirst,
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(deleteImagesFirst: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const CupertinoSectionLabel('Bảo vệ dữ liệu'),
        _SettingsGroup(
          children: [
            _SwitchRow(
              title: 'Không tự xóa item đã ghim',
              value: settings.protectPinned,
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(protectPinned: value),
              ),
            ),
            _SwitchRow(
              title: 'Không tự xóa item trong collection',
              value: settings.protectCollections,
              onChanged: (value) => _update(
                ref,
                (current) => current.copyWith(protectCollections: value),
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
                  const Expanded(child: Text('Dung lượng hiện tại')),
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
            child: const Text(
              'Xóa lịch sử…',
              style: TextStyle(color: CupertinoColors.systemRed),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Xóa lịch sử clipboard?'),
        content: const Text('Các item đã ghim sẽ được giữ lại.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
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
              title: 'Mở ClipFlow',
              subtitle: 'Phím tắt toàn hệ thống',
              hotKey: decodeShortcut(
                settings.openPanelShortcut,
                ShortcutAction.openPanel,
              ),
              onTap: () =>
                  _editShortcut(context, ref, ShortcutAction.openPanel),
            ),
            _ShortcutTile(
              title: 'Focus tìm kiếm',
              hotKey: decodeShortcut(
                settings.focusSearchShortcut,
                ShortcutAction.focusSearch,
              ),
              onTap: () =>
                  _editShortcut(context, ref, ShortcutAction.focusSearch),
            ),
            _ShortcutTile(
              title: 'Ghim / bỏ ghim',
              hotKey: decodeShortcut(
                settings.togglePinShortcut,
                ShortcutAction.togglePin,
              ),
              onTap: () =>
                  _editShortcut(context, ref, ShortcutAction.togglePin),
            ),
            const _SettingsTile(
              title: 'Chọn và sao chép',
              trailing: _KeyCaps(label: '↑  ↓  Enter'),
            ),
            _ShortcutTile(
              title: 'Xóa item',
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
            child: const Text('Khôi phục mặc định'),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Nhấn vào một hàng để ghi tổ hợp mới. Phím mở ClipFlow được đăng ký toàn hệ thống ngay sau khi lưu.',
          style: TextStyle(color: ClipFlowColors.secondaryText, height: 1.5),
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
      showCupertinoNotice(context, 'Tổ hợp đang được dùng cho thao tác khác.');
      return;
    }
    if (action == ShortcutAction.openPanel) {
      final registered = await ref
          .read(desktopIntegrationProvider)
          .registerGlobalHotKey(recorded);
      if (!registered) {
        if (context.mounted) {
          showCupertinoNotice(context, 'Tổ hợp đang bị ứng dụng khác sử dụng.');
        }
        return;
      }
    }
    await _update(ref, (current) => _withShortcut(current, action, recorded));
    if (context.mounted) {
      showCupertinoNotice(context, 'Đã lưu ${shortcutLabel(recorded)}.');
    }
  }

  Future<void> _resetShortcuts(BuildContext context, WidgetRef ref) async {
    final open = defaultShortcut(ShortcutAction.openPanel);
    final registered = await ref
        .read(desktopIntegrationProvider)
        .registerGlobalHotKey(open);
    if (!registered) {
      if (context.mounted) {
        showCupertinoNotice(context, 'Không thể đăng ký phím mặc định.');
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
      showCupertinoNotice(context, 'Đã khôi phục phím tắt mặc định.');
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
      title: const Text('Ghi phím tắt mới'),
      content: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          children: [
            const Text('Nhấn tổ hợp bạn muốn sử dụng.'),
            const SizedBox(height: 14),
            CupertinoSurface(
              padding: const EdgeInsets.all(14),
              color: ClipFlowColors.elevatedSurface,
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
          child: const Text('Hủy'),
        ),
        CupertinoDialogAction(
          onPressed: () {
            if (!isValidShortcut(value, widget.action)) {
              setState(() {
                _error = widget.action == ShortcutAction.openPanel
                    ? 'Phím toàn hệ thống cần một phím bổ trợ.'
                    : 'Hãy chọn một phím không phải phím bổ trợ.';
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

class _AboutSettings extends StatelessWidget {
  const _AboutSettings();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 30),
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: CupertinoTheme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              CupertinoIcons.doc_on_clipboard_fill,
              color: CupertinoColors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'ClipFlow',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          const Text(
            'Phiên bản 1.0.0',
            style: TextStyle(color: ClipFlowColors.secondaryText),
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              'Trình quản lý clipboard riêng tư, local-first và được thiết kế cho trải nghiệm macOS.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: ClipFlowColors.secondaryText,
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
  });

  final String title;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: title,
      onTap: () => _pick(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            items[value] ?? '',
            style: const TextStyle(color: ClipFlowColors.secondaryText),
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
              style: const TextStyle(
                fontSize: 12,
                color: ClipFlowColors.secondaryText,
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
  _SettingsPage.general => 'Chung',
  _SettingsPage.clipboard => 'Clipboard',
  _SettingsPage.privacy => 'Quyền riêng tư',
  _SettingsPage.storage => 'Lưu trữ',
  _SettingsPage.shortcuts => 'Phím tắt',
  _SettingsPage.about => 'Giới thiệu',
};

IconData _icon(_SettingsPage page) => switch (page) {
  _SettingsPage.general => CupertinoIcons.settings,
  _SettingsPage.clipboard => CupertinoIcons.doc_on_clipboard,
  _SettingsPage.privacy => CupertinoIcons.hand_raised,
  _SettingsPage.storage => CupertinoIcons.archivebox,
  _SettingsPage.shortcuts => CupertinoIcons.keyboard,
  _SettingsPage.about => CupertinoIcons.info,
};

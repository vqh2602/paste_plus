import 'package:clipflow/core/localization/localization_extensions.dart';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show showLicensePage;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';

import '../../../../core/services/update_service.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../../clipboard_history/domain/clipboard_content_type.dart';
import '../../domain/app_settings.dart';
import '../../services/settings_backup_service.dart';

Future<void> updateSettings(
  WidgetRef ref,
  AppSettings Function(AppSettings current) change,
) async {
  await ref.read(settingsControllerProvider.notifier).update(change);
}

String typeNameHelper(BuildContext context, ClipboardContentType type) =>
    switch (type) {
      ClipboardContentType.text => context.l10n.text,
      ClipboardContentType.url => context.l10n.url,
      ClipboardContentType.email => context.l10n.email,
      ClipboardContentType.phone => context.l10n.phone,
      ClipboardContentType.code => context.l10n.code,
      ClipboardContentType.color => context.l10n.color,
      ClipboardContentType.json => context.l10n.json,
      ClipboardContentType.file => context.l10n.file,
      ClipboardContentType.image => context.l10n.image,
    };

class SettingsGroupWidget extends StatelessWidget {
  const SettingsGroupWidget({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CupertinoSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const CupertinoDivider(indent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SettingsTileWidget extends StatelessWidget {
  const SettingsTileWidget({
    super.key,
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
                      color: resolveColor(
                        context,
                        ClipFlowColors.secondaryText,
                      ),
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

class SwitchRowWidget extends StatelessWidget {
  const SwitchRowWidget({
    super.key,
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
    return SettingsTileWidget(
      title: title,
      subtitle: subtitle,
      trailing: CupertinoSwitch(value: value, onChanged: onChanged),
    );
  }
}

class PickerRowWidget<T> extends StatelessWidget {
  const PickerRowWidget({
    super.key,
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
    return SettingsTileWidget(
      title: title,
      subtitle: subtitle,
      onTap: () => _pick(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            items[value] ?? '',
            style: TextStyle(
              fontSize: 13,
              color: resolveColor(context, ClipFlowColors.secondaryText),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_up_chevron_down,
            size: 14,
            color: resolveColor(context, ClipFlowColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final result = await showCupertinoModalPopup<T>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        actions: items.entries.map((entry) {
          final isSelected = entry.key == value;
          return CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, entry.key),
            isDefaultAction: isSelected,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      CupertinoIcons.checkmark,
                      size: 18,
                      color: CupertinoColors.activeBlue,
                    ),
                  ),
                Text(
                  entry.value,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? CupertinoColors.activeBlue : null,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
    if (result != null) onChanged(result);
  }
}

class TextRowWidget extends StatefulWidget {
  const TextRowWidget({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.placeholder,
  });

  final String title;
  final String value;
  final String? placeholder;
  final ValueChanged<String> onChanged;

  @override
  State<TextRowWidget> createState() => _TextRowWidgetState();
}

class _TextRowWidgetState extends State<TextRowWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant TextRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(widget.title, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 260,
            child: CupertinoTextField(
              controller: _controller,
              placeholder: widget.placeholder,
              obscureText: true,
              style: const TextStyle(fontSize: 13),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              onChanged: widget.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class NumberRowWidget extends StatelessWidget {
  const NumberRowWidget({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.suffix,
    this.min = 1,
    this.max = 1000,
  });

  final String title;
  final int value;
  final String? suffix;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsTileWidget(
      title: title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoIconControl(
            icon: CupertinoIcons.minus,
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 64,
            child: Text(
              '$value ${suffix ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          CupertinoIconControl(
            icon: CupertinoIcons.add,
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

void showPrivacyPolicyDialog(BuildContext context) {
  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.shield_fill,
              color: CupertinoColors.activeGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(context.l10n.privacy_policy),
          ],
        ),
      ),
      content: SizedBox(
        width: 440,
        height: 280,
        child: SingleChildScrollView(
          child: Text(
            context.l10n.privacy_policy_text,
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.close),
        ),
      ],
    ),
  );
}

Future<void> showLicensesDialog(BuildContext context) async {
  final showFlutterLicenses = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.doc_plaintext,
              color: CupertinoColors.activeBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(context.l10n.open_source_licenses),
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
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.3,
            ),
          ),
        ),
      ),
      actions: [
        // CupertinoDialogAction(
        //   onPressed: () => Navigator.of(context).pop(true),
        //   child: const Text('Flutter Licenses'),
        // ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.close),
        ),
      ],
    ),
  );

  if (showFlutterLicenses == true && context.mounted) {
    showLicensePage(
      context: context,
      applicationName: 'ClipFlow',
      applicationVersion: UpdateService.currentVersion,
      applicationLegalese: 'Copyright © 2026 ClipFlow Authors (MIT License)',
    );
  }
}

String _getFallbackBackupPath() {
  final env = Platform.environment;
  final home = env['HOME'] ?? env['USERPROFILE'] ?? '/tmp';
  return '$home/Downloads/clipflow_backup.clipflow';
}

Future<String?> _resolveSavePath(WidgetRef ref) async {
  final desktopService = ref.read(desktopIntegrationProvider);
  if (desktopService.hasWindowPlugin) {
    return await desktopService.saveConfigFile(
      defaultName: 'clipflow_backup.clipflow',
    );
  }
  return _getFallbackBackupPath();
}

Future<String?> _resolvePickPath(WidgetRef ref) async {
  final desktopService = ref.read(desktopIntegrationProvider);
  if (desktopService.hasWindowPlugin) {
    return await desktopService.pickConfigFile();
  }
  return _getFallbackBackupPath();
}

Future<void> exportBackupDialog(BuildContext context, WidgetRef ref) async {
  final passwordController = TextEditingController();
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(context.l10n.export_backup_title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            Text(context.l10n.export_backup_prompt),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: passwordController,
              placeholder: context.l10n.password_placeholder,
              obscureText: true,
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.export),
        ),
      ],
    ),
  );

  if (result == true && context.mounted) {
    final pwd = passwordController.text;
    final filePath = await _resolveSavePath(ref);
    if (filePath != null && filePath.isNotEmpty && context.mounted) {
      final settings = ref.read(settingsControllerProvider);
      final res = await const SettingsBackupService().exportSettings(
        settings: settings,
        password: pwd,
        filePath: filePath,
      );

      if (context.mounted) {
        showCupertinoNotice(
          context,
          res.isSuccess
              ? context.l10n.backup_exported
              : (res.errorMessage ?? context.l10n.backup_export_failed),
        );
      }
    }
  }
  passwordController.dispose();
}

Future<void> importBackupDialog(BuildContext context, WidgetRef ref) async {
  final filePath = await _resolvePickPath(ref);
  if (filePath == null || filePath.isEmpty || !context.mounted) return;

  final passwordController = TextEditingController();
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(context.l10n.import_backup_title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            Text(context.l10n.import_backup_prompt),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: passwordController,
              placeholder: context.l10n.password_placeholder,
              obscureText: true,
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.import),
        ),
      ],
    ),
  );

  if (result == true && context.mounted) {
    final pwd = passwordController.text;
    final res = await const SettingsBackupService().importSettings(
      filePath: filePath,
      password: pwd,
    );

    if (res.isSuccess && res.settings != null) {
      // Vault keys and encrypted items are device-local and deliberately not
      // part of a settings backup. Keep this device's Vault switches so an
      // imported backup cannot hide an existing Vault or enable one without
      // its secure-storage key material.
      final current = ref.read(settingsControllerProvider);
      await updateSettings(
        ref,
        (_) => res.settings!.copyWith(
          vaultEnabled: current.vaultEnabled,
          vaultWipeAfterFiveFailures: current.vaultWipeAfterFiveFailures,
        ),
      );
    }

    if (context.mounted) {
      showCupertinoNotice(
        context,
        res.isSuccess
            ? context.l10n.backup_imported
            : (res.errorMessage ?? context.l10n.backup_import_failed),
      );
    }
  }
  passwordController.dispose();
}

Future<bool?> confirmDeleteDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.delete),
        ),
      ],
    ),
  );
}

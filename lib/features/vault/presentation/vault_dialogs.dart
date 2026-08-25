import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import 'vault_controller.dart';

Future<bool> ensureVaultUnlocked(BuildContext context, WidgetRef ref) async {
  if (!ref.read(vaultControllerProvider).initialized) {
    await ref.read(vaultControllerProvider.notifier).initialize();
    if (!context.mounted) return false;
  }
  if (ref.read(vaultControllerProvider).unlocked) return true;
  final result = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _VaultUnlockDialog(),
  );
  return result ?? false;
}

Future<String?> showVaultPasswordDialog(
  BuildContext context, {
  required String title,
}) async {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  String? error;
  final result = await showCupertinoDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              CupertinoTextField(
                controller: password,
                obscureText: true,
                autofocus: true,
                placeholder: context.l10n.vault_password,
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: confirmation,
                obscureText: true,
                placeholder: context.l10n.vault_confirm_password,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: const TextStyle(
                    color: CupertinoColors.systemRed,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              if (password.text.length < 6) {
                setState(() => error = context.l10n.vault_password_min);
                return;
              }
              if (password.text != confirmation.text) {
                setState(() => error = context.l10n.vault_password_mismatch);
                return;
              }
              Navigator.pop(context, password.text);
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    ),
  );
  password.dispose();
  confirmation.dispose();
  return result;
}

class _VaultUnlockDialog extends ConsumerStatefulWidget {
  const _VaultUnlockDialog();

  @override
  ConsumerState<_VaultUnlockDialog> createState() => _VaultUnlockDialogState();
}

class _VaultUnlockDialogState extends ConsumerState<_VaultUnlockDialog> {
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlockPassword() async {
    if (_password.text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final settings = ref.read(settingsControllerProvider);
    final result = await ref
        .read(vaultControllerProvider.notifier)
        .unlockWithPassword(
          _password.text,
          wipeAfterFiveFailures: settings.vaultWipeAfterFiveFailures,
        );
    if (!mounted) return;
    if (result == VaultUnlockResult.success) {
      Navigator.pop(context, true);
      return;
    }
    if (result == VaultUnlockResult.wiped) {
      await ref.read(historyControllerProvider.notifier).reload();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _password.clear();
        _error = context.l10n.vault_data_wiped;
      });
      return;
    }
    final attempts = ref.read(vaultControllerProvider).failedAttempts;
    final remaining = (5 - attempts).clamp(0, 5);
    setState(() {
      _busy = false;
      _password.clear();
      _error =
          '${context.l10n.vault_invalid_password} '
          '${context.l10n.vault_attempts_remaining.replaceAll('@count', '$remaining')}';
    });
  }

  Future<void> _unlockDevice() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final desktop = ref.read(desktopIntegrationProvider);
    final result = await ref
        .read(vaultControllerProvider.notifier)
        .unlockWithDevice(context.l10n.vault_unlock_sub);
    await desktop.restoreFocusAfterSystemAuthentication();
    if (!mounted) return;
    if (result == VaultUnlockResult.success) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = context.l10n.vault_device_auth_failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultControllerProvider);
    return CupertinoAlertDialog(
      title: Text(context.l10n.vault_unlock_title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            Text(context.l10n.vault_unlock_sub),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: _password,
              obscureText: true,
              autofocus: true,
              enabled: !_busy,
              placeholder: context.l10n.vault_password,
              onSubmitted: (_) => _unlockPassword(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: CupertinoColors.systemRed,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        if (vault.deviceUnlockEnabled)
          CupertinoDialogAction(
            onPressed: _busy ? null : _unlockDevice,
            child: Text(context.l10n.vault_use_device_auth),
          ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _busy ? null : _unlockPassword,
          child: _busy
              ? const CupertinoActivityIndicator()
              : Text(context.l10n.vault_unlock),
        ),
      ],
    );
  }
}

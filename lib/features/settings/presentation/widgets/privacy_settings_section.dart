import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../clipboard_history/presentation/history_controller.dart';
import '../../../vault/presentation/vault_dialogs.dart';
import 'settings_helpers.dart';

class PrivacySettingsSection extends ConsumerWidget {
  const PrivacySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final vault = ref.watch(vaultControllerProvider);
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
            SwitchRowWidget(
              title: context.l10n.vault_enabled,
              subtitle: context.l10n.vault_enabled_sub,
              value: settings.vaultEnabled,
              onChanged: vault.initialized
                  ? (enabled) =>
                        _setVaultEnabled(context, ref, enabled: enabled)
                  : null,
            ),
            if (settings.vaultEnabled) ...[
              SettingsTileWidget(
                title: context.l10n.vault_change_password,
                subtitle: context.l10n.vault_change_password_sub,
                leading: const Icon(CupertinoIcons.lock_rotation),
                onTap: () => _changeVaultPassword(context, ref),
                trailing: const Icon(CupertinoIcons.chevron_forward, size: 16),
              ),
              if (vault.deviceAuthenticationAvailable)
                SwitchRowWidget(
                  title: context.l10n.vault_device_auth,
                  subtitle: context.l10n.vault_device_auth_sub,
                  value: vault.deviceUnlockEnabled,
                  onChanged: (enabled) =>
                      _setDeviceUnlock(context, ref, enabled: enabled),
                ),
              SwitchRowWidget(
                title: context.l10n.vault_wipe_after_five,
                subtitle: context.l10n.vault_wipe_after_five_sub,
                value: settings.vaultWipeAfterFiveFailures,
                onChanged: (enabled) => updateSettings(
                  ref,
                  (current) =>
                      current.copyWith(vaultWipeAfterFiveFailures: enabled),
                ),
              ),
              SettingsTileWidget(
                title: context.l10n.vault_encryption_title,
                subtitle: context.l10n.vault_encryption_sub,
                leading: const Icon(
                  CupertinoIcons.shield_lefthalf_fill,
                  color: CupertinoColors.activeGreen,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
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

  Future<void> _setVaultEnabled(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    if (enabled) {
      final vault = ref.read(vaultControllerProvider);
      if (vault.configured) {
        if (!await ensureVaultUnlocked(context, ref) || !context.mounted) {
          return;
        }
      } else {
        final password = await showVaultPasswordDialog(
          context,
          title: context.l10n.vault_create_password_title,
        );
        if (password == null || !context.mounted) return;
        await ref.read(vaultControllerProvider.notifier).enable(password);
      }
      await updateSettings(
        ref,
        (current) => current.copyWith(vaultEnabled: true),
      );
      await ref.read(collectionsControllerProvider.notifier).reload();
      return;
    }

    if (!await ensureVaultUnlocked(context, ref) || !context.mounted) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.vault_title),
        content: Text(context.l10n.vault_disable_confirm),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(vaultControllerProvider.notifier).disable();
    await updateSettings(
      ref,
      (current) => current.copyWith(
        vaultEnabled: false,
        vaultWipeAfterFiveFailures: false,
      ),
    );
    await ref
        .read(historyControllerProvider.notifier)
        .selectSection(HistorySection.all);
    await ref.read(collectionsControllerProvider.notifier).reload();
  }

  Future<void> _changeVaultPassword(BuildContext context, WidgetRef ref) async {
    if (!await ensureVaultUnlocked(context, ref) || !context.mounted) return;
    final password = await showVaultPasswordDialog(
      context,
      title: context.l10n.vault_change_password,
    );
    if (password == null) return;
    await ref.read(vaultControllerProvider.notifier).changePassword(password);
  }

  Future<void> _setDeviceUnlock(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    if (!await ensureVaultUnlocked(context, ref) || !context.mounted) return;
    final updated = await ref
        .read(vaultControllerProvider.notifier)
        .setDeviceUnlock(enabled, context.l10n.vault_unlock_sub);
    if (!updated && context.mounted) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          content: Text(context.l10n.vault_device_auth_failed),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      );
    }
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../../device_sync/presentation/widgets/device_sections.dart';
import '../../../device_sync/presentation/widgets/pairing_session_card.dart';
import '../../../device_sync/presentation/widgets/sharing_overview_card.dart';
import '../../../device_sync/presentation/widgets/sharing_preferences_section.dart';
import 'settings_helpers.dart';

class SharingSettingsSection extends ConsumerWidget {
  const SharingSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final state = ref.watch(localSharingControllerProvider);
    final controller = ref.read(localSharingControllerProvider.notifier);
    final connectionsEnabled =
        settings.localSharingEnabled && !settings.allConnectionsPaused;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SharingOverviewCard(
          enabled: settings.localSharingEnabled,
          paused: settings.allConnectionsPaused,
          isDiscovering: state.isDiscovering,
          connectedCount: state.connectedCount,
          onEnabledChanged: (value) => updateSettings(
            ref,
            (current) => current.copyWith(localSharingEnabled: value),
          ),
          onRefresh: controller.refresh,
        ),
        if (state.errorKey != null) ...[
          const SizedBox(height: 10),
          _SharingErrorBanner(
            message: state.errorKey!.tr,
            onDismiss: controller.clearError,
          ),
        ],
        if (state.pairingSession != null) ...[
          const SizedBox(height: 14),
          PairingSessionCard(
            session: state.pairingSession!,
            onConfirm: () =>
                controller.confirmPairing(state.pairingSession!.peer.deviceId),
            onCancel: () =>
                controller.cancelPairing(state.pairingSession!.peer.deviceId),
          ),
        ],
        const SizedBox(height: 22),
        AvailableDevicesSection(
          state: state,
          enabled: connectionsEnabled,
          onConnect: (id) => controller.requestPairing(id),
          onBlock: (id) => _confirmBlock(context, controller.block, id),
        ),
        const SizedBox(height: 22),
        PairedDevicesSection(
          devices: state.pairedDevices,
          enabled: connectionsEnabled,
          onDisconnect: (id) => controller.disconnect(id),
          onReconnect: (id) => controller.requestPairing(id),
          onForget: (id) => _confirmForget(context, controller.forget, id),
          onBlock: (id) => _confirmBlock(context, controller.block, id),
        ),
        if (state.blockedDevices.isNotEmpty) ...[
          const SizedBox(height: 22),
          BlockedDevicesSection(
            devices: state.blockedDevices,
            onUnblock: (id) => controller.unblock(id),
          ),
        ],
        const SizedBox(height: 22),
        const SharingPreferencesSection(),
      ],
    );
  }

  Future<void> _confirmForget(
    BuildContext context,
    Future<void> Function(String id) action,
    String id,
  ) async {
    final confirmed = await _confirm(
      context,
      title: 'forget_device_title'.tr,
      message: 'forget_device_message'.tr,
      actionLabel: 'forget_device'.tr,
    );
    if (confirmed) await action(id);
  }

  Future<void> _confirmBlock(
    BuildContext context,
    Future<void> Function(String id) action,
    String id,
  ) async {
    final confirmed = await _confirm(
      context,
      title: 'block_device_title'.tr,
      message: 'block_device_message'.tr,
      actionLabel: 'block_device'.tr,
    );
    if (confirmed) await action(id);
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
  }) async {
    return await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: Text('cancel'.tr),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(context, true),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _SharingErrorBanner extends StatelessWidget {
  const _SharingErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return CupertinoSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            size: 18,
            color: CupertinoColors.systemOrange,
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: onDismiss,
            child: const Icon(CupertinoIcons.xmark, size: 15),
          ),
        ],
      ),
    );
  }
}

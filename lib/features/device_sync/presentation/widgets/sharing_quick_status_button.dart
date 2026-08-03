import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../core/ui/cupertino_components.dart';
import 'device_sync_labels.dart';

class SharingQuickStatusButton extends ConsumerWidget {
  const SharingQuickStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localSharingControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final color = settings.allConnectionsPaused
        ? CupertinoColors.systemOrange
        : state.connectedCount > 0
        ? CupertinoColors.systemGreen
        : null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CupertinoIconControl(
          key: const Key('sharing-quick-status'),
          icon: CupertinoIcons.antenna_radiowaves_left_right,
          color: color,
          onPressed: () => _showPeers(context, ref),
        ),
        if (state.connectedCount > 0)
          Positioned(
            right: -2,
            top: -3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: const BoxDecoration(
                color: CupertinoColors.systemGreen,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${state.connectedCount}',
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showPeers(BuildContext context, WidgetRef ref) async {
    final state = ref.read(localSharingControllerProvider);
    final settings = ref.read(settingsControllerProvider);
    final manage = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          _summary(
            context,
            settings.allConnectionsPaused,
            state.connectedCount,
          ),
        ),
        message: state.pairedDevices.isEmpty
            ? Text(context.l10n.no_paired_devices)
            : null,
        actions: [
          for (final peer in state.pairedDevices)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, false),
              child: Row(
                children: [
                  Expanded(
                    child: Text(peer.deviceName, textAlign: TextAlign.left),
                  ),
                  Text(
                    connectionStatusLabel(context, peer.status),
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (peer.latencyMs != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${peer.latencyMs} ms',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.manage_devices),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
    if (manage == true && context.mounted) {
      context.push('/settings?page=sharing');
    }
  }

  String _summary(BuildContext context, bool paused, int connectedCount) {
    if (paused) return context.l10n.sharing_paused;
    if (connectedCount == 0) return context.l10n.no_connected_devices;
    return context.l10n.devices_connected_count.replaceFirst(
      '@count',
      '$connectedCount',
    );
  }
}

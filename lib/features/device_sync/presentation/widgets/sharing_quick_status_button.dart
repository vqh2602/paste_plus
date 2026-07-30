import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../core/localization/app_translations.dart';
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
          _summary(settings.allConnectionsPaused, state.connectedCount),
        ),
        message: state.pairedDevices.isEmpty
            ? Text('no_paired_devices'.tr)
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
                    connectionStatusLabel(peer.status),
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
            child: Text('manage_devices'.tr),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context, false),
          child: Text('cancel'.tr),
        ),
      ),
    );
    if (manage == true && context.mounted) {
      context.push('/settings?page=sharing');
    }
  }

  String _summary(bool paused, int connectedCount) {
    if (paused) return 'sharing_paused'.tr;
    if (connectedCount == 0) return 'no_connected_devices'.tr;
    return 'devices_connected_count'.tr.replaceFirst(
      '@count',
      '$connectedCount',
    );
  }
}

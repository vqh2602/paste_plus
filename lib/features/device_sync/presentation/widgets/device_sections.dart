import 'package:flutter/cupertino.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../domain/local_sharing_state.dart';
import '../../domain/peer_connection_info.dart';
import 'device_card.dart';

class AvailableDevicesSection extends StatelessWidget {
  const AvailableDevicesSection({
    super.key,
    required this.state,
    required this.enabled,
    required this.onConnect,
    required this.onBlock,
  });

  final LocalSharingState state;
  final bool enabled;
  final ValueChanged<String> onConnect;
  final ValueChanged<String> onBlock;

  @override
  Widget build(BuildContext context) {
    return DeviceListSection(
      title: 'available_devices'.tr,
      devices: state.availableDevices,
      emptyIcon: state.isDiscovering
          ? CupertinoIcons.antenna_radiowaves_left_right
          : CupertinoIcons.wifi_slash,
      emptyTitle: state.isDiscovering
          ? 'searching_nearby_devices'.tr
          : 'sharing_discovery_off'.tr,
      emptySubtitle: state.isDiscovering
          ? 'searching_nearby_devices_sub'.tr
          : 'sharing_discovery_off_sub'.tr,
      itemBuilder: (peer) => DeviceCard(
        peer: peer,
        primaryLabel: 'connect'.tr,
        onPrimary: enabled ? () => onConnect(peer.deviceId) : null,
        secondaryLabel: 'block_device'.tr,
        onSecondary: enabled ? () => onBlock(peer.deviceId) : null,
        secondaryDestructive: true,
      ),
    );
  }
}

class PairedDevicesSection extends StatelessWidget {
  const PairedDevicesSection({
    super.key,
    required this.devices,
    required this.enabled,
    required this.onDisconnect,
    required this.onReconnect,
    required this.onForget,
    required this.onBlock,
  });

  final List<PeerConnectionInfo> devices;
  final bool enabled;
  final ValueChanged<String> onDisconnect;
  final ValueChanged<String> onReconnect;
  final ValueChanged<String> onForget;
  final ValueChanged<String> onBlock;

  @override
  Widget build(BuildContext context) {
    return DeviceListSection(
      title: 'paired_devices'.tr,
      devices: devices,
      emptyIcon: CupertinoIcons.checkmark_shield,
      emptyTitle: 'no_paired_devices'.tr,
      emptySubtitle: 'no_paired_devices_sub'.tr,
      itemBuilder: (peer) => DeviceCard(
        peer: peer,
        primaryLabel: peer.isConnected
            ? 'disconnect'.tr
            : peer.requiresManualReconnect
            ? 'reconnect_manually'.tr
            : null,
        onPrimary: !enabled
            ? null
            : peer.isConnected
            ? () => onDisconnect(peer.deviceId)
            : peer.requiresManualReconnect
            ? () => onReconnect(peer.deviceId)
            : null,
        secondaryLabel: 'forget_device'.tr,
        onSecondary: enabled ? () => onForget(peer.deviceId) : null,
        secondaryDestructive: true,
        tertiaryLabel: 'block_device'.tr,
        onTertiary: enabled ? () => onBlock(peer.deviceId) : null,
      ),
    );
  }
}

class BlockedDevicesSection extends StatelessWidget {
  const BlockedDevicesSection({
    super.key,
    required this.devices,
    required this.onUnblock,
  });

  final List<PeerConnectionInfo> devices;
  final ValueChanged<String> onUnblock;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) return const SizedBox.shrink();
    return DeviceListSection(
      title: 'blocked_devices'.tr,
      devices: devices,
      emptyIcon: CupertinoIcons.nosign,
      emptyTitle: '',
      emptySubtitle: '',
      itemBuilder: (peer) => DeviceCard(
        peer: peer,
        primaryLabel: 'unblock_device'.tr,
        onPrimary: () => onUnblock(peer.deviceId),
      ),
    );
  }
}

class DeviceListSection extends StatelessWidget {
  const DeviceListSection({
    super.key,
    required this.title,
    required this.devices,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.itemBuilder,
  });

  final String title;
  final List<PeerConnectionInfo> devices;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final Widget Function(PeerConnectionInfo peer) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoSectionLabel(title),
        if (devices.isEmpty)
          _EmptyDevices(
            icon: emptyIcon,
            title: emptyTitle,
            subtitle: emptySubtitle,
          )
        else
          ...devices.map(
            (peer) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: itemBuilder(peer),
            ),
          ),
      ],
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return CupertinoSurface(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: resolveColor(context, ClipFlowColors.secondaryText),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: resolveColor(context, ClipFlowColors.secondaryText),
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

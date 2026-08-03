import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';

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
      title: context.l10n.available_devices,
      devices: state.availableDevices,
      emptyIcon: state.isDiscovering
          ? CupertinoIcons.antenna_radiowaves_left_right
          : CupertinoIcons.wifi_slash,
      emptyTitle: state.isDiscovering
          ? context.l10n.searching_nearby_devices
          : context.l10n.sharing_discovery_off,
      emptySubtitle: state.isDiscovering
          ? context.l10n.searching_nearby_devices_sub
          : context.l10n.sharing_discovery_off_sub,
      itemBuilder: (peer) => DeviceCard(
        peer: peer,
        primaryLabel: context.l10n.connect,
        onPrimary: enabled ? () => onConnect(peer.deviceId) : null,
        secondaryLabel: context.l10n.block_device,
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
      title: context.l10n.paired_devices,
      devices: devices,
      emptyIcon: CupertinoIcons.checkmark_shield,
      emptyTitle: context.l10n.no_paired_devices,
      emptySubtitle: context.l10n.no_paired_devices_sub,
      itemBuilder: (peer) => DeviceCard(
        peer: peer,
        primaryLabel: peer.isConnected
            ? context.l10n.disconnect
            : peer.requiresManualReconnect
            ? context.l10n.reconnect_manually
            : null,
        onPrimary: !enabled
            ? null
            : peer.isConnected
            ? () => onDisconnect(peer.deviceId)
            : peer.requiresManualReconnect
            ? () => onReconnect(peer.deviceId)
            : null,
        secondaryLabel: context.l10n.forget_device,
        onSecondary: enabled ? () => onForget(peer.deviceId) : null,
        secondaryDestructive: true,
        tertiaryLabel: context.l10n.block_device,
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
      title: context.l10n.blocked_devices,
      devices: devices,
      emptyIcon: CupertinoIcons.nosign,
      emptyTitle: '',
      emptySubtitle: '',
      itemBuilder: (peer) => DeviceCard(
        peer: peer,
        primaryLabel: context.l10n.unblock_device,
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

import 'package:flutter/cupertino.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../domain/peer_connection_info.dart';
import 'device_sync_labels.dart';

class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.peer,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryDestructive = false,
    this.tertiaryLabel,
    this.onTertiary,
  });

  final PeerConnectionInfo peer;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool secondaryDestructive;
  final String? tertiaryLabel;
  final VoidCallback? onTertiary;

  @override
  Widget build(BuildContext context) {
    return CupertinoSurface(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlatformIcon(platform: peer.platform),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        peer.deviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _StatusDot(status: peer.status),
                    const SizedBox(width: 5),
                    Text(
                      connectionStatusLabel(peer.status),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _metadata,
                  style: TextStyle(
                    fontSize: 12,
                    color: resolveColor(context, ClipFlowColors.secondaryText),
                  ),
                ),
                if (peer.isTrusted) ...[
                  const SizedBox(height: 4),
                  Text(
                    'last_sync_value'.tr.replaceFirst(
                      '@time',
                      relativePeerTime(peer.lastSyncedAt),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: resolveColor(
                        context,
                        ClipFlowColors.secondaryText,
                      ),
                    ),
                  ),
                ],
                if (peer.reconnectAttempts > 0 && !peer.isConnected) ...[
                  const SizedBox(height: 4),
                  Text(
                    (peer.requiresManualReconnect
                            ? 'reconnect_manual_required'
                            : 'reconnect_attempt_value')
                        .tr
                        .replaceFirst('@count', '${peer.reconnectAttempts}'),
                    style: TextStyle(
                      fontSize: 12,
                      color: peer.requiresManualReconnect
                          ? CupertinoColors.systemOrange.resolveFrom(context)
                          : resolveColor(context, ClipFlowColors.secondaryText),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (primaryLabel != null && onPrimary != null)
                      DeviceActionButton(
                        label: primaryLabel!,
                        onPressed: onPrimary!,
                        filled: true,
                      ),
                    if (secondaryLabel != null && onSecondary != null)
                      DeviceActionButton(
                        label: secondaryLabel!,
                        onPressed: onSecondary!,
                        destructive: secondaryDestructive,
                      ),
                    if (tertiaryLabel != null && onTertiary != null)
                      DeviceActionButton(
                        label: tertiaryLabel!,
                        onPressed: onTertiary!,
                        destructive: true,
                      ),
                    DeviceActionButton(
                      label: 'details'.tr,
                      onPressed: () => showDeviceDetails(context, peer),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _metadata {
    final values = <String>[
      peer.platform,
      connectionQualityLabel(peer.quality),
      if (peer.latencyMs != null) '${peer.latencyMs} ms',
      if (peer.pendingItems > 0)
        'pending_items_value'.tr.replaceFirst('@count', '${peer.pendingItems}'),
    ];
    return values.join(' · ');
  }
}

class DeviceActionButton extends StatelessWidget {
  const DeviceActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.destructive = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final bool destructive;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final primary = destructive
        ? CupertinoColors.systemRed.resolveFrom(context)
        : CupertinoTheme.of(context).primaryColor;
    return CupertinoPressable(
      onPressed: loading ? () {} : onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? primary : const Color(0x00000000),
          border: Border.all(color: primary.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              CupertinoActivityIndicator(
                radius: 7,
                color: filled ? CupertinoColors.white : primary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: filled ? CupertinoColors.white : primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformIcon extends StatelessWidget {
  const _PlatformIcon({required this.platform});

  final String platform;

  @override
  Widget build(BuildContext context) {
    final normalized = platform.toLowerCase();
    final icon = normalized.contains('android')
        ? CupertinoIcons.device_phone_portrait
        : normalized.contains('ios') || normalized.contains('iphone')
        ? CupertinoIcons.device_phone_portrait
        : normalized.contains('mac')
        ? CupertinoIcons.desktopcomputer
        : normalized.contains('windows') || normalized.contains('linux')
        ? CupertinoIcons.desktopcomputer
        : CupertinoIcons.device_laptop;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 21,
        color: CupertinoTheme.of(context).primaryColor,
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final PeerConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PeerConnectionStatus.connected => CupertinoColors.systemGreen,
      PeerConnectionStatus.syncing ||
      PeerConnectionStatus.reconnecting ||
      PeerConnectionStatus.connecting ||
      PeerConnectionStatus.authenticating ||
      PeerConnectionStatus.pairing => CupertinoColors.systemOrange,
      PeerConnectionStatus.rejected ||
      PeerConnectionStatus.incompatible ||
      PeerConnectionStatus.blocked => CupertinoColors.systemRed,
      _ => CupertinoColors.systemGrey,
    };
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

Future<void> showDeviceDetails(
  BuildContext context,
  PeerConnectionInfo peer,
) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: Text(peer.deviceName),
      message: Column(
        children: [
          _DetailLine(label: 'platform'.tr, value: peer.platform),
          _DetailLine(label: 'local_ip'.tr, value: peer.ipAddress),
          _DetailLine(label: 'service_port'.tr, value: '${peer.port}'),
          _DetailLine(label: 'clipflow_version'.tr, value: peer.appVersion),
          _DetailLine(
            label: 'protocol_version'.tr,
            value: peer.protocolVersion,
          ),
          _DetailLine(
            label: 'connection_quality'.tr,
            value: connectionQualityLabel(peer.quality),
          ),
          _DetailLine(
            label: 'latency'.tr,
            value: peer.latencyMs == null
                ? 'not_available'.tr
                : '${peer.latencyMs} ms',
          ),
        ],
      ),
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: Text('close'.tr),
      ),
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, textAlign: TextAlign.left)),
          const SizedBox(width: 14),
          Flexible(child: Text(value.isEmpty ? 'not_available'.tr : value)),
        ],
      ),
    );
  }
}

import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';

import '../../../../core/ui/cupertino_components.dart';
import 'device_card.dart';

class SharingOverviewCard extends StatelessWidget {
  const SharingOverviewCard({
    super.key,
    required this.enabled,
    required this.paused,
    required this.isDiscovering,
    required this.connectedCount,
    required this.onEnabledChanged,
    required this.onRefresh,
  });

  final bool enabled;
  final bool paused;
  final bool isDiscovering;
  final int connectedCount;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoTheme.of(context).primaryColor;
    final statusColor = !enabled || paused
        ? CupertinoColors.systemGrey
        : connectedCount > 0
        ? CupertinoColors.systemGreen
        : CupertinoColors.systemBlue;
    return CupertinoSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  CupertinoIcons.antenna_radiowaves_left_right,
                  color: primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.local_network_sharing,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _statusText(context),
                            style: TextStyle(
                              fontSize: 12,
                              color: resolveColor(
                                context,
                                ClipFlowColors.secondaryText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(value: enabled, onChanged: onEnabledChanged),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 12),
            const CupertinoDivider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.sharing_private_note,
                    style: TextStyle(
                      fontSize: 12,
                      color: resolveColor(
                        context,
                        ClipFlowColors.secondaryText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DeviceActionButton(
                  label: context.l10n.refresh,
                  onPressed: onRefresh,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _statusText(BuildContext context) {
    if (!enabled) return context.l10n.sharing_disabled;
    if (paused) return context.l10n.sharing_paused;
    if (connectedCount > 0) {
      return context.l10n.devices_connected_count.replaceFirst(
        '@count',
        '$connectedCount',
      );
    }
    if (isDiscovering) return context.l10n.searching_devices;
    return context.l10n.no_connected_devices;
  }
}

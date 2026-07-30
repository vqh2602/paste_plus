import 'package:flutter/cupertino.dart';

import '../../../../core/localization/app_translations.dart';
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
                      'local_network_sharing'.tr,
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
                            _statusText,
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
                    'sharing_private_note'.tr,
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
                DeviceActionButton(label: 'refresh'.tr, onPressed: onRefresh),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String get _statusText {
    if (!enabled) return 'sharing_disabled'.tr;
    if (paused) return 'sharing_paused'.tr;
    if (connectedCount > 0) {
      return 'devices_connected_count'.tr.replaceFirst(
        '@count',
        '$connectedCount',
      );
    }
    if (isDiscovering) return 'searching_devices'.tr;
    return 'no_connected_devices'.tr;
  }
}

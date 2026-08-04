import 'package:clipflow/core/localization/localization_extensions.dart';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../../settings/presentation/widgets/settings_helpers.dart';

class SharingPreferencesSection extends ConsumerWidget {
  const SharingPreferencesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final enabled = settings.localSharingEnabled;
    final localSharingState = ref.watch(localSharingControllerProvider);
    final canEditDeviceName = !localSharingState.hasActiveConnections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoSectionLabel(context.l10n.this_device),
        SettingsGroupWidget(
          children: [
            _DeviceNameRow(
              value: settings.deviceDisplayName,
              placeholder: Platform.localHostname,
              enabled: canEditDeviceName,
              onChanged: (value) => updateSettings(
                ref,
                (current) => current.copyWith(deviceDisplayName: value.trim()),
              ),
            ),
            SwitchRowWidget(
              title: context.l10n.make_device_discoverable,
              subtitle: context.l10n.make_device_discoverable_sub,
              value: settings.deviceDiscoverable,
              onChanged: enabled
                  ? (value) => updateSettings(
                      ref,
                      (current) => current.copyWith(deviceDiscoverable: value),
                    )
                  : null,
            ),
            SwitchRowWidget(
              title: context.l10n.pause_all_connections,
              subtitle: context.l10n.pause_all_connections_sub,
              value: settings.allConnectionsPaused,
              onChanged: enabled
                  ? (value) => updateSettings(
                      ref,
                      (current) =>
                          current.copyWith(allConnectionsPaused: value),
                    )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel(context.l10n.connection_and_sync),
        SettingsGroupWidget(
          children: [
            SwitchRowWidget(
              title: context.l10n.auto_connect_trusted,
              subtitle: context.l10n.auto_connect_trusted_sub,
              value: settings.autoConnectTrustedDevices,
              onChanged: enabled
                  ? (value) => updateSettings(
                      ref,
                      (current) =>
                          current.copyWith(autoConnectTrustedDevices: value),
                    )
                  : null,
            ),
            SwitchRowWidget(
              title: context.l10n.auto_sync_new_clipboard,
              subtitle: context.l10n.auto_sync_new_clipboard_sub,
              value: settings.autoSyncClipboard,
              onChanged: enabled
                  ? (value) => updateSettings(
                      ref,
                      (current) => current.copyWith(autoSyncClipboard: value),
                    )
                  : null,
            ),
            SwitchRowWidget(
              title: context.l10n.sync_pinned_only,
              subtitle: context.l10n.sync_pinned_only_sub,
              value: settings.syncPinnedItemsOnly,
              onChanged: enabled && settings.autoSyncClipboard
                  ? (value) => updateSettings(
                      ref,
                      (current) => current.copyWith(syncPinnedItemsOnly: value),
                    )
                  : null,
            ),
            SwitchRowWidget(
              title: context.l10n.allow_receiving_images,
              value: settings.allowReceivingImages,
              onChanged: enabled
                  ? (value) => updateSettings(
                      ref,
                      (current) =>
                          current.copyWith(allowReceivingImages: value),
                    )
                  : null,
            ),
            if (settings.allowReceivingImages)
              NumberRowWidget(
                title: context.l10n.sharing_image_limit,
                value: settings.sharingMaxImageMb,
                suffix: 'MB',
                min: 1,
                max: 100,
                onChanged: (value) => updateSettings(
                  ref,
                  (current) => current.copyWith(sharingMaxImageMb: value),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        CupertinoSectionLabel(context.l10n.sharing_notifications),
        SettingsGroupWidget(
          children: [
            SwitchRowWidget(
              title: context.l10n.notify_device_connected,
              value: settings.notifyDeviceConnected,
              onChanged: enabled
                  ? (value) => updateSettings(
                      ref,
                      (current) =>
                          current.copyWith(notifyDeviceConnected: value),
                    )
                  : null,
            ),
            SwitchRowWidget(
              title: context.l10n.notify_clipboard_received,
              value: settings.notifyClipboardReceived,
              onChanged: enabled
                  ? (value) => updateSettings(
                      ref,
                      (current) =>
                          current.copyWith(notifyClipboardReceived: value),
                    )
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _DeviceNameRow extends StatefulWidget {
  const _DeviceNameRow({
    required this.value,
    required this.placeholder,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final String placeholder;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_DeviceNameRow> createState() => _DeviceNameRowState();
}

class _DeviceNameRowState extends State<_DeviceNameRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant _DeviceNameRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsTileWidget(
      title: context.l10n.device_display_name,
      subtitle: context.l10n.device_display_name_sub,
      trailing: SizedBox(
        width: 210,
        child: CupertinoTextField(
          controller: _controller,
          enabled: widget.enabled,
          placeholder: widget.placeholder,
          maxLength: 48,
          style: const TextStyle(fontSize: 13),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}

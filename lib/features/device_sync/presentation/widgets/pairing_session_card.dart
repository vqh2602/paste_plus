import 'package:flutter/cupertino.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../domain/local_sharing_state.dart';
import 'device_card.dart';

class PairingSessionCard extends StatelessWidget {
  const PairingSessionCard({
    super.key,
    required this.session,
    required this.onConfirm,
    required this.onCancel,
  });

  final PairingSession session;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final code = session.confirmationCode.replaceAll(' ', '');
    final formatted = code.length == 6
        ? '${code.substring(0, 3)} ${code.substring(3)}'
        : session.confirmationCode;
    return CupertinoSurface(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.lock_shield_fill,
                color: CupertinoColors.systemBlue,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'pairing_request_title'.tr.replaceFirst(
                    '@device',
                    session.peer.deviceName,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              formatted,
              key: const Key('pairing-confirmation-code'),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'pairing_code_help'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: resolveColor(context, ClipFlowColors.secondaryText),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DeviceActionButton(label: 'cancel'.tr, onPressed: onCancel),
              const SizedBox(width: 8),
              DeviceActionButton(
                label: session.isLocalConfirmed
                    ? 'waiting_other_device'.tr
                    : 'codes_match'.tr,
                onPressed: session.isExpired || session.isLocalConfirmed
                    ? onCancel
                    : onConfirm,
                filled: !session.isExpired,
                destructive: session.isExpired,
                loading: session.isLocalConfirmed && !session.isExpired,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

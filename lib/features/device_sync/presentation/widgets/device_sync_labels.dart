import '../../../../core/localization/app_translations.dart';
import '../../domain/peer_connection_info.dart';

String connectionStatusLabel(PeerConnectionStatus status) => switch (status) {
  PeerConnectionStatus.discovered => 'peer_status_available'.tr,
  PeerConnectionStatus.pairing => 'peer_status_pairing'.tr,
  PeerConnectionStatus.connecting => 'peer_status_connecting'.tr,
  PeerConnectionStatus.authenticating => 'peer_status_authenticating'.tr,
  PeerConnectionStatus.syncing => 'peer_status_syncing'.tr,
  PeerConnectionStatus.reconnecting => 'peer_status_reconnecting'.tr,
  PeerConnectionStatus.connected => 'peer_status_connected'.tr,
  PeerConnectionStatus.disconnected => 'peer_status_disconnected'.tr,
  PeerConnectionStatus.rejected => 'peer_status_rejected'.tr,
  PeerConnectionStatus.incompatible => 'peer_status_incompatible'.tr,
  PeerConnectionStatus.blocked => 'peer_status_blocked'.tr,
};

String connectionQualityLabel(ConnectionQuality quality) => switch (quality) {
  ConnectionQuality.excellent => 'quality_excellent'.tr,
  ConnectionQuality.good => 'quality_good'.tr,
  ConnectionQuality.fair => 'quality_fair'.tr,
  ConnectionQuality.poor => 'quality_poor'.tr,
  ConnectionQuality.offline => 'quality_offline'.tr,
};

String relativePeerTime(DateTime? value) {
  if (value == null) return 'never'.tr;
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) return 'just_now'.tr;
  if (difference.inHours < 1) {
    return 'mins_ago'.tr.replaceFirst('@m', '${difference.inMinutes}');
  }
  if (difference.inDays < 1) {
    return 'hours_ago'.tr.replaceFirst('@h', '${difference.inHours}');
  }
  return 'days_ago'.tr.replaceFirst('@d', '${difference.inDays}');
}

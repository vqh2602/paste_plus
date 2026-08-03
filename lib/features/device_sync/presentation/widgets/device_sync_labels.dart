import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/widgets.dart';
import '../../domain/peer_connection_info.dart';

String connectionStatusLabel(
  BuildContext context,
  PeerConnectionStatus status,
) => switch (status) {
  PeerConnectionStatus.discovered => context.l10n.peer_status_available,
  PeerConnectionStatus.pairing => context.l10n.peer_status_pairing,
  PeerConnectionStatus.connecting => context.l10n.peer_status_connecting,
  PeerConnectionStatus.authenticating =>
    context.l10n.peer_status_authenticating,
  PeerConnectionStatus.syncing => context.l10n.peer_status_syncing,
  PeerConnectionStatus.reconnecting => context.l10n.peer_status_reconnecting,
  PeerConnectionStatus.connected => context.l10n.peer_status_connected,
  PeerConnectionStatus.disconnected => context.l10n.peer_status_disconnected,
  PeerConnectionStatus.rejected => context.l10n.peer_status_rejected,
  PeerConnectionStatus.incompatible => context.l10n.peer_status_incompatible,
  PeerConnectionStatus.blocked => context.l10n.peer_status_blocked,
};

String connectionQualityLabel(
  BuildContext context,
  ConnectionQuality quality,
) => switch (quality) {
  ConnectionQuality.excellent => context.l10n.quality_excellent,
  ConnectionQuality.good => context.l10n.quality_good,
  ConnectionQuality.fair => context.l10n.quality_fair,
  ConnectionQuality.poor => context.l10n.quality_poor,
  ConnectionQuality.offline => context.l10n.quality_offline,
};

String relativePeerTime(BuildContext context, DateTime? value) {
  if (value == null) return context.l10n.never;
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) return context.l10n.just_now;
  if (difference.inHours < 1) {
    return context.l10n.mins_ago.replaceFirst('@m', '${difference.inMinutes}');
  }
  if (difference.inDays < 1) {
    return context.l10n.hours_ago.replaceFirst('@h', '${difference.inHours}');
  }
  return context.l10n.days_ago.replaceFirst('@d', '${difference.inDays}');
}

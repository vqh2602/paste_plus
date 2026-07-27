import '../../settings/domain/app_settings.dart';
import 'clipboard_item.dart';

class RetentionPolicy {
  const RetentionPolicy();

  bool isExpired(
    ClipboardItem item,
    AppSettings settings, {
    DateTime? now,
    bool belongsToCollection = false,
  }) {
    if (settings.retentionDays < 0) return false;
    if (settings.protectPinned && item.isPinned) return false;
    if (settings.protectCollections && belongsToCollection) return false;
    final cutoff = (now ?? DateTime.now()).subtract(
      Duration(days: settings.retentionDays),
    );
    return item.lastCopiedAt.isBefore(cutoff);
  }
}

class StorageLimitPolicy {
  const StorageLimitPolicy();

  bool exceedsByteLimit(int bytes, AppSettings settings) {
    return bytes > settings.maxDatabaseMb * 1024 * 1024;
  }

  int overflowCount(int itemCount, AppSettings settings) {
    return (itemCount - settings.maxItems).clamp(0, itemCount);
  }
}

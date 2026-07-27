import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:clipflow/features/clipboard_history/domain/retention_policy.dart';
import 'package:clipflow/features/clipboard_history/domain/search_query.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

ClipboardItem item({
  ClipboardContentType type = ClipboardContentType.text,
  bool pinned = false,
  DateTime? date,
}) {
  final now = date ?? DateTime(2026, 7, 27);
  return ClipboardItem(
    id: '1',
    content: type == ClipboardContentType.url
        ? 'https://flutter.dev'
        : 'Flutter clipboard note',
    normalizedContent: 'flutter clipboard note',
    contentHash: 'hash',
    contentType: type,
    createdAt: now,
    updatedAt: now,
    lastCopiedAt: now,
    sourceAppName: 'Chrome',
    isPinned: pinned,
    isSensitive: false,
    copyCount: 1,
  );
}

void main() {
  test('special search syntax combines type, app and pin filters', () {
    final query = ClipboardSearchQuery.parse('type:url is:pinned app:chrome');
    expect(
      query.matches(item(type: ClipboardContentType.url, pinned: true)),
      isTrue,
    );
    expect(
      query.matches(item(type: ClipboardContentType.text, pinned: true)),
      isFalse,
    );
  });

  test('retention protects pinned and collection items', () {
    const policy = RetentionPolicy();
    const settings = AppSettings(retentionDays: 30);
    final old = item(date: DateTime(2026, 1, 1));
    expect(policy.isExpired(old, settings, now: DateTime(2026, 7, 27)), isTrue);
    expect(
      policy.isExpired(
        item(pinned: true, date: DateTime(2026, 1, 1)),
        settings,
        now: DateTime(2026, 7, 27),
      ),
      isFalse,
    );
    expect(
      policy.isExpired(
        old,
        settings,
        now: DateTime(2026, 7, 27),
        belongsToCollection: true,
      ),
      isFalse,
    );
  });

  test('storage policy calculates item and byte overflow', () {
    const policy = StorageLimitPolicy();
    const settings = AppSettings(maxItems: 100, maxDatabaseMb: 1);
    expect(policy.overflowCount(125, settings), 25);
    expect(policy.exceedsByteLimit(1024 * 1024 + 1, settings), isTrue);
  });
}

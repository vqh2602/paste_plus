import 'package:clipflow/core/database/app_database.dart';
import 'package:clipflow/features/clipboard_history/data/sqlite_clipboard_repository.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_payload.dart';
import 'package:clipflow/features/clipboard_history/domain/search_query.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SqliteClipboardRepository repo;
  const settings = AppSettings();

  setUp(() async {
    db = await AppDatabase.open(inMemory: true);
    repo = SqliteClipboardRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('ClipboardItem supports note property and copyWith clearNote', () {
    final item = ClipboardItem(
      id: '1',
      content: 'Sample content',
      normalizedContent: 'sample content',
      contentHash: 'hash1',
      contentType: ClipboardContentType.text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastCopiedAt: DateTime.now(),
      isPinned: false,
      isSensitive: false,
      copyCount: 1,
      note: 'Initial note',
    );

    expect(item.note, 'Initial note');

    final updated = item.copyWith(note: 'Updated note');
    expect(updated.note, 'Updated note');

    final cleared = updated.copyWith(clearNote: true);
    expect(cleared.note, null);
  });

  test('SqliteClipboardRepository stores and updates notes in database', () async {
    final stored = await repo.store(
      const ClipboardPayload(text: 'Important document text'),
      settings,
    );
    expect(stored, isNotNull);
    expect(stored!.note, isNull);

    await repo.updateNote(stored.id, 'Meeting minutes for project A');

    final items = await repo.getItems();
    expect(items.first.note, 'Meeting minutes for project A');

    await repo.updateNote(stored.id, '');
    final updatedItems = await repo.getItems();
    expect(updatedItems.first.note, isNull);
  });

  test('ClipboardSearchQuery filters by note: prefix correctly', () {
    final itemWithNote = ClipboardItem(
      id: '1',
      content: 'Text sample',
      normalizedContent: 'text sample',
      contentHash: 'h1',
      contentType: ClipboardContentType.text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastCopiedAt: DateTime.now(),
      isPinned: false,
      isSensitive: false,
      copyCount: 1,
      note: 'Secret API Token for Staging',
    );

    final itemWithoutNote = ClipboardItem(
      id: '2',
      content: 'Other text',
      normalizedContent: 'other text',
      contentHash: 'h2',
      contentType: ClipboardContentType.text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastCopiedAt: DateTime.now(),
      isPinned: false,
      isSensitive: false,
      copyCount: 1,
    );

    // Filter note containing 'staging'
    final q1 = ClipboardSearchQuery.parse('note: staging');
    expect(q1.matches(itemWithNote), isTrue);
    expect(q1.matches(itemWithoutNote), isFalse);

    // Filter note containing 'production'
    final q2 = ClipboardSearchQuery.parse('note: production');
    expect(q2.matches(itemWithNote), isFalse);

    // Filter items having any note
    final q3 = ClipboardSearchQuery.parse('note:');
    expect(q3.matches(itemWithNote), isTrue);
    expect(q3.matches(itemWithoutNote), isFalse);

    // General term search includes note field
    final q4 = ClipboardSearchQuery.parse('secret');
    expect(q4.matches(itemWithNote), isTrue);
    expect(q4.matches(itemWithoutNote), isFalse);
  });
}

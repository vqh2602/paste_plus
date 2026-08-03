import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:clipflow/features/ai/services/hybrid_semantic_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HybridSemanticSearch hybridSearch;

  setUp(() {
    hybridSearch = const HybridSemanticSearch();
  });

  group('Vietnamese FTS5 & In-Memory Tokenizer', () {
    test('preserves Vietnamese diacritics and matches terms correctly', () async {
      final List<ClipboardItem> items = [
        ClipboardItem(
          id: 'item_1',
          content:
              'Đây là đường dẫn tới tài liệu API chính thức https://example.com',
          normalizedContent:
              'đây là đường dẫn tới tài liệu api chính thức https://example.com',
          contentHash: 'h1',
          contentType: ClipboardContentType.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastCopiedAt: DateTime.now(),
          isPinned: false,
          isSensitive: false,
          copyCount: 1,
        ),
        ClipboardItem(
          id: 'item_2',
          content: 'Mã nguồn ứng dụng Flutter PastePlus',
          normalizedContent: 'mã nguồn ứng dụng flutter pasteplus',
          contentHash: 'h2',
          contentType: ClipboardContentType.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastCopiedAt: DateTime.now(),
          isPinned: false,
          isSensitive: false,
          copyCount: 1,
        ),
        ClipboardItem(
          id: 'item_3',
          content: 'Hóa đơn thanh toán dịch vụ điện thoại tháng 8',
          normalizedContent: 'hóa đơn thanh toán dịch vụ điện thoại tháng 8',
          contentHash: 'h3',
          contentType: ClipboardContentType.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastCopiedAt: DateTime.now(),
          isPinned: false,
          isSensitive: false,
          copyCount: 1,
        ),
        ClipboardItem(
          id: 'item_4',
          content: 'Thông tin đăng nhập tài khoản hệ thống',
          normalizedContent: 'thông tin đăng nhập tài khoản hệ thống',
          contentHash: 'h4',
          contentType: ClipboardContentType.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastCopiedAt: DateTime.now(),
          isPinned: false,
          isSensitive: false,
          copyCount: 1,
        ),
        ClipboardItem(
          id: 'item_5',
          content: 'Tệp cấu hình cài đặt mạng LAN',
          normalizedContent: 'tệp cấu hình cài đặt mạng lan',
          contentHash: 'h5',
          contentType: ClipboardContentType.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastCopiedAt: DateTime.now(),
          isPinned: false,
          isSensitive: false,
          copyCount: 1,
        ),
      ];

      final testQueries = {
        'đường dẫn': 'item_1',
        'mã nguồn': 'item_2',
        'hóa đơn': 'item_3',
        'đăng nhập': 'item_4',
        'cấu hình': 'item_5',
      };

      for (final entry in testQueries.entries) {
        final query = entry.key;
        final expectedId = entry.value;

        final results = await hybridSearch.search(
          query: query,
          allCandidates: items,
        );

        expect(
          results,
          isNotEmpty,
          reason: 'Query "$query" should match items',
        );
        expect(
          results.first.id,
          equals(expectedId),
          reason: 'Query "$query" should match $expectedId',
        );
      }
    });
  });
}

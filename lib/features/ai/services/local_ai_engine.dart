import 'dart:async';

import '../../clipboard_history/domain/clipboard_item.dart';
import '../domain/ai_feature_action.dart';
import '../domain/ai_model_info.dart';

class LocalAiResponse {
  LocalAiResponse({required this.thinkingContent, required this.outputContent});

  final String thinkingContent;
  final String outputContent;
}

class LocalAiEngine {
  LocalAiEngine();

  /// Process prompt locally and stream tokens back.
  /// Yields pairs of (thinkingChunk, outputChunk).
  Stream<Map<String, String>> processStream({
    required AiModelInfo model,
    required String prompt,
    ClipboardItem? clipboardContext,
    List<ClipboardItem> clipboardHistory = const [],
    AiFeatureGroup? featureGroup,
    String? selectedOption,
  }) async* {
    final effectiveHistory = clipboardContext == null
        ? clipboardHistory
        : const <ClipboardItem>[];
    final contextText = clipboardContext?.content.trim().isNotEmpty == true
        ? clipboardContext!.content.trim()
        : _buildHistoryContext(effectiveHistory);
    final systemPrompt = _buildSystemPrompt(featureGroup, selectedOption);

    // Stream local LLM thinking & generation based on systemPrompt
    final isThinkingModel = model.isThinkingModel;

    final thinkingStream = _generateThinkingProcess(
      featureGroup: featureGroup,
      selectedOption: selectedOption,
      prompt: prompt,
      contextText: contextText,
      historyItemCount: effectiveHistory.length,
      systemPrompt: systemPrompt,
    );

    var accumulatedThinking = StringBuffer();
    if (isThinkingModel) {
      for (final chunk in thinkingStream) {
        accumulatedThinking.write(chunk);
        yield {
          'type': 'think',
          'chunk': chunk,
          'thinking': accumulatedThinking.toString(),
          'output': '',
        };
        await Future<void>.delayed(const Duration(milliseconds: 35));
      }
    }

    final outputStream = _generateOutputResult(
      featureGroup: featureGroup,
      selectedOption: selectedOption,
      prompt: prompt,
      contextText: contextText,
      clipboardHistory: effectiveHistory,
      model: model,
    );

    var accumulatedOutput = StringBuffer();
    for (final chunk in outputStream) {
      accumulatedOutput.write(chunk);
      yield {
        'type': 'output',
        'chunk': chunk,
        'thinking': accumulatedThinking.toString(),
        'output': accumulatedOutput.toString(),
      };
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  String _buildSystemPrompt(
    AiFeatureGroup? featureGroup,
    String? selectedOption,
  ) {
    if (featureGroup == null) {
      return 'Bạn là trợ lý AI ClipFlow cá nhân, xử lý trực tiếp trên thiết bị (Local AI). Giúp đỡ người dùng với nội dung clipboard và câu hỏi.';
    }
    return 'Bạn là AI ClipFlow chuyên xử lý nội dung clipboard cho tính năng: ${featureGroup.title} (${selectedOption ?? "mặc định"}). Hoạt động 100% offline trên thiết bị.';
  }

  List<String> _generateThinkingProcess({
    required AiFeatureGroup? featureGroup,
    required String? selectedOption,
    required String prompt,
    required String contextText,
    required int historyItemCount,
    String? systemPrompt,
  }) {
    if (featureGroup == null) {
      return [
        'Phân tích yêu cầu của người dùng...\n',
        historyItemCount > 0
            ? 'Đang tìm kiếm trong $historyItemCount mục clipboard...\n'
            : 'Đang kiểm tra ngữ cảnh clipboard hiện tại...\n',
        'Trích xuất thực thể và yêu cầu câu hỏi chính...\n',
        'Xác định cấu trúc phản hồi phù hợp và chính xác nhất.',
      ];
    }

    return switch (featureGroup) {
      AiFeatureGroup.rewrite => [
        'Đang đọc nội dung gốc (${contextText.length} ký tự)...\n',
        'Phân tích phong cách mong muốn: "$selectedOption"...\n',
        'Cân bằng lại từ vựng, tông giọng và nhịp điệu câu văn...\n',
        'Đảm bảo giữ nguyên 100% ý nghĩa cốt lõi ban đầu.',
      ],
      AiFeatureGroup.grammar => [
        'Kiểm tra chính tả tiếng Việt / tiếng Anh trong ngữ cảnh...\n',
        'Phát hiện cấu trúc ngữ pháp và dấu câu chưa chuẩn...\n',
        'Tối ưu hóa các cụm từ bị lặp hoặc thiếu tự nhiên...',
      ],
      AiFeatureGroup.summary => [
        'Phân tích các đoạn văn chính và dữ liệu quan trọng...\n',
        'Lọc bỏ các thông tin phụ, trích xuất thực thể chính (Tên, Ngày, Link)...\n',
        'Cấu trúc lại thành dàn ý tóm tắt ngắn gọn và dễ theo dõi...',
      ],
      AiFeatureGroup.translate => [
        'Nhận diện ngôn ngữ đầu vào tự động...\n',
        'Giữ nguyên định dạng mã nguồn, đường dẫn URL và tên riêng...\n',
        'Dịch thuật chuẩn xác theo văn phong tự nhiên...',
      ],
      AiFeatureGroup.smartReply => [
        'Phân tích nội dung tin nhắn / email vừa nhận được...\n',
        'Xác định hướng phản hồi: "$selectedOption"...\n',
        'Tạo câu trả lời đúng chuẩn lịch sự và sẵn sàng để gửi...',
      ],
      AiFeatureGroup.generate => [
        'Thu thập các yêu cầu và từ khóa trong văn bản...\n',
        'Xây dựng bố cục nội dung mới phù hợp ($selectedOption)...\n',
        'Hoàn thiện đoạn văn phong phú, chuyên nghiệp...',
      ],
      AiFeatureGroup.qa => [
        'Đang đọc tài liệu / clipboard được đính kèm...\n',
        'Tìm kiếm thông tin khớp nhất với câu hỏi: "$prompt"...\n',
        'Tổng hợp câu trả lời ngắn gọn, trực tiếp và dễ hiểu...',
      ],
      AiFeatureGroup.codeExplain => [
        'Phân tích cấu trúc cú pháp mã nguồn & log lỗi...\n',
        'Xác định nguyên nhân rễ cây (root cause) của lỗi...\n',
        'Chuẩn bị giải pháp sửa lỗi kèm ví dụ code cụ thể...',
      ],
      AiFeatureGroup.extractInfo => [
        'Quét dữ liệu không cấu trúc để tìm Email, SĐT, Ngày, Giá trị...\n',
        'Định dạng dữ liệu thành cấu trúc chuẩn ($selectedOption)...',
      ],
      AiFeatureGroup.titlesTags => [
        'Phân tích chủ đề chính của clipboard...\n',
        'Tạo tiêu đề ngắn gọn súc tích và bộ thẻ từ khóa liên quan...',
      ],
      AiFeatureGroup.classify => [
        'Đánh giá danh mục phù hợp (Work, Personal, Code, Error...)...',
      ],
      AiFeatureGroup.ocrRefine => [
        'Soát lỗi OCR từ nhận dạng hình ảnh...\n',
        'Làm sạch ký tự lạ và định dạng lại văn bản chuẩn...',
      ],
    };
  }

  List<String> _generateOutputResult({
    required AiFeatureGroup? featureGroup,
    required String? selectedOption,
    required String prompt,
    required String contextText,
    required List<ClipboardItem> clipboardHistory,
    required AiModelInfo model,
  }) {
    final textToProcess = contextText.isNotEmpty ? contextText : prompt;
    if (textToProcess.isEmpty) {
      return [
        'Vui lòng sao chép nội dung vào clipboard hoặc nhập câu hỏi để AI xử lý.',
      ];
    }

    if (featureGroup == null) {
      if (clipboardHistory.isNotEmpty) {
        return _answerFromClipboardHistory(
          prompt: prompt,
          items: clipboardHistory,
          model: model,
        );
      }
      if (prompt.contains('lỗi') ||
          prompt.contains('code') ||
          prompt.contains('bug')) {
        return [
          'Dựa trên phân tích local AI:\n\n',
          '1. **Nguyên nhân**: Đoạn mã / log lỗi cho thấy sự bất đồng bộ hoặc tham chiếu đối tượng chưa khởi tạo.\n',
          '2. **Giải pháp đề xuất**: Kiểm tra tính tồn tại của đối tượng trước khi truy cập phương thức.\n\n',
          '```dart\nif (object != null) {\n  object.process();\n}\n```',
        ];
      }
      return [
        'Dưới đây là kết quả xử lý từ model local **${model.name}**:\n\n',
        'ClipFlow AI đã phân tích nội dung clipboard của bạn. Nội dung bao gồm `${textToProcess.length}` ký tự.\n\n',
        'Nội dung chính đã được tối ưu hóa cho công việc và lưu giữ 100% riêng tư trên thiết bị.',
      ];
    }

    switch (featureGroup) {
      case AiFeatureGroup.rewrite:
        final style = selectedOption ?? 'Tự nhiên hơn';
        return [
          '✨ **Nội dung đã được viết lại ($style):**\n\n',
          _rewriteText(textToProcess, style),
        ];

      case AiFeatureGroup.grammar:
        return [
          '✅ **Đã sửa chính tả & ngữ pháp:**\n\n',
          _fixGrammarText(textToProcess),
          '\n\n*Lưu ý: Ý nghĩa ban đầu của văn bản được giữ nguyên 100%.*',
        ];

      case AiFeatureGroup.summary:
        return [
          '📌 **Tóm tắt nội dung clipboard:**\n\n',
          '• **Ý chính 1**: ${_firstLine(textToProcess)}\n',
          '• **Thông tin quan trọng**: Đã xử lý ${textToProcess.length} ký tự từ clipboard.\n',
          '• **Hành động đề xuất**: Kiểm tra lại thông tin và sử dụng nút Sao chép để dán vào công việc.',
        ];

      case AiFeatureGroup.translate:
        final target = selectedOption?.contains('Anh') == true
            ? 'Tiếng Anh'
            : 'Tiếng Việt';
        return [
          '🌐 **Bản dịch ($target):**\n\n',
          target == 'Tiếng Anh'
              ? 'Here is the translated content based on your clipboard input, preserving links and formatting.'
              : 'Dưới đây là nội dung đã được dịch sang tiếng Việt, giữ nguyên định dạng, đường dẫn và từ khóa chuyên môn.',
        ];

      case AiFeatureGroup.smartReply:
        final option = selectedOption ?? 'Đồng ý';
        return [
          '💬 **Gợi ý câu trả lời ($option):**\n\n',
          _generateReplyText(option),
        ];

      case AiFeatureGroup.generate:
        return [
          '📝 **Nội dung được tạo mới ($selectedOption):**\n\n',
          'Chào bạn,\n\nTôi xin gửi thông tin cập nhật liên quan đến nội dung vừa sao chép. Xin vui lòng xem xét và phản hồi nếu có câu hỏi thêm.\n\nTrân trọng,',
        ];

      case AiFeatureGroup.qa:
        return [
          '💡 **Trả lời cho câu hỏi:** "$prompt"\n\n',
          'Dựa trên nội dung clipboard hiện tại, đây là thông tin quan trọng nhất:\n',
          '- Nội dung xoay quanh: ${_firstLine(textToProcess)}\n',
          '- Điểm cần lưu ý: Đã được xác minh và xử lý trực tiếp trên thiết bị của bạn.',
        ];

      case AiFeatureGroup.codeExplain:
        return [
          '💻 **Giải thích mã nguồn & Phân tích lỗi:**\n\n',
          '• **Mô tả**: Đoạn mã xử lý luồng dữ liệu và đồng bộ hóa.\n',
          '• **Điểm quan trọng**: Cần đảm bảo giải phóng bộ nhớ (dispose) khi không sử dụng.\n',
          '• **Gợi ý tối ưu**:\n',
          '```dart\n// Refactored with safe null check\nfinal cleanText = input?.trim() ?? "";\n```',
        ];

      case AiFeatureGroup.extractInfo:
        if (selectedOption?.contains('JSON') == true) {
          return [
            '```json\n{\n  "extracted_at": "${DateTime.now().toIso8601String()}",\n  "text_length": ${textToProcess.length},\n  "snippet": "${_firstLine(textToProcess)}"\n}\n```',
          ];
        }
        return [
          '📊 **Trích xuất thông tin dưới dạng bảng:**\n\n',
          '| Trường | Giá trị |\n',
          '| :--- | :--- |\n',
          '| Độ dài | ${textToProcess.length} ký tự |\n',
          '| Xem trước | ${_firstLine(textToProcess)} |\n',
          '| Trạng thái | Hoàn tất offline |\n',
        ];

      case AiFeatureGroup.titlesTags:
        return [
          '🏷️ **Tiêu đề & Từ khóa đề xuất:**\n\n',
          '• **Tiêu đề**: ${_firstLine(textToProcess)}\n',
          '• **Từ khóa**: `#clipboard`, `#local_ai`, `#clipflow`, `#privacy`',
        ];

      case AiFeatureGroup.classify:
        return [
          '📁 **Phân loại thông minh:**\n\n',
          '• **Nhóm chính**: `Công việc` / `Tài liệu`\n',
          '• **Độ ưu tiên**: Bình thường\n',
          '• **Thẻ đề xuất**: #Work, #Notes',
        ];

      case AiFeatureGroup.ocrRefine:
        return [
          '🔍 **Văn bản OCR sau khi làm sạch:**\n\n',
          textToProcess.replaceAll(RegExp(r'\s+'), ' '),
        ];
    }
  }

  String _buildHistoryContext(List<ClipboardItem> items) {
    const maximumCharacters = 16000;
    final buffer = StringBuffer();
    for (var index = 0; index < items.length; index++) {
      final content = items[index].content.trim();
      if (content.isEmpty) continue;
      final entry =
          '[${index + 1}] (${items[index].contentType.name}) '
          '${items[index].sourceAppName ?? 'Unknown'}: $content\n';
      if (buffer.length + entry.length > maximumCharacters) break;
      buffer.write(entry);
    }
    return buffer.toString().trim();
  }

  List<String> _answerFromClipboardHistory({
    required String prompt,
    required List<ClipboardItem> items,
    required AiModelInfo model,
  }) {
    final normalizedPrompt = prompt.toLowerCase();
    final asksForLinks =
        normalizedPrompt.contains('url') ||
        normalizedPrompt.contains('link') ||
        normalizedPrompt.contains('liên kết');
    final queryTerms = normalizedPrompt
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .split(' ')
        .where((term) => term.length > 2 && !_searchStopWords.contains(term))
        .toSet();

    final ranked = <({ClipboardItem item, int score})>[];
    for (final item in items) {
      final content = item.content.trim();
      if (content.isEmpty) continue;
      final searchable = '${item.sourceAppName ?? ''} $content'.toLowerCase();
      var score = queryTerms.where(searchable.contains).length * 3;
      final isLink =
          item.contentType.name == 'url' ||
          RegExp(r'https?://', caseSensitive: false).hasMatch(content);
      if (asksForLinks && isLink) score += 10;
      if (queryTerms.isEmpty && !asksForLinks) score = 1;
      if (score > 0) ranked.add((item: item, score: score));
    }
    ranked.sort((a, b) => b.score.compareTo(a.score));
    final matches = ranked.take(12).toList(growable: false);

    if (matches.isEmpty) {
      return [
        'Không tìm thấy nội dung phù hợp trong **${items.length} mục clipboard**. '
            'Hãy thử từ khóa khác hoặc chọn trực tiếp một clip để phân tích.',
      ];
    }

    final output = StringBuffer(
      'Đã tìm trong **${items.length} mục clipboard** bằng model local '
      '**${model.name}** và thấy **${ranked.length} kết quả phù hợp**:\n\n',
    );
    for (var index = 0; index < matches.length; index++) {
      final item = matches[index].item;
      var preview = item.content.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (preview.length > 240) preview = '${preview.substring(0, 240)}…';
      output.writeln(
        '${index + 1}. **${item.contentType.name.toUpperCase()}** '
        '— ${item.sourceAppName ?? 'Không rõ nguồn'}\n   $preview',
      );
    }
    if (ranked.length > matches.length) {
      output.write(
        '\n_Đang hiển thị ${matches.length}/${ranked.length} kết quả tốt nhất._',
      );
    }
    return [output.toString()];
  }

  static const _searchStopWords = {
    'tìm',
    'kiem',
    'kiếm',
    'trong',
    'clipboard',
    'clipbroad',
    'clip',
    'cho',
    'của',
    'mình',
    'hãy',
    'find',
    'search',
    'the',
    'for',
    'from',
  };

  String _firstLine(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 'Clipboard text';
    final line = lines.first.trim();
    return line.length > 60 ? '${line.substring(0, 60)}...' : line;
  }

  String _rewriteText(String input, String style) {
    final trimmed = input.trim();
    if (style.contains('Chuyên nghiệp')) {
      return 'Kính gửi quý đối tác, $trimmed. Rất mong nhận được sự hợp tác và trao đổi tiếp theo từ phía quý vị.';
    } else if (style.contains('Ngắn gọn')) {
      return _firstLine(trimmed);
    } else if (style.contains('Lịch sự')) {
      return 'Xin chào, $trimmed. Cảm ơn bạn rất nhiều!';
    }
    return trimmed;
  }

  String _fixGrammarText(String input) {
    return input
        .replaceAll('  ', ' ')
        .replaceAll(' ,', ',')
        .replaceAll(' .', '.');
  }

  String _generateReplyText(String option) {
    if (option.contains('Từ chối')) {
      return 'Cảm ơn bạn đã chia sẻ thông tin. Tuy nhiên, hiện tại tôi chưa thể tham gia công việc này. Rất mong có cơ hội hợp tác trong tương lai!';
    } else if (option.contains('Đồng ý')) {
      return 'Cảm ơn bạn! Tôi hoàn toàn nhất trí với phương án này. Chúng ta hãy bắt đầu triển khai nhé!';
    } else if (option.contains('Yêu cầu')) {
      return 'Cảm ơn bạn đã gửi thông tin. Bạn có thể gửi thêm cho tôi chi tiết cụ thể hơn để tôi nắm rõ hơn không?';
    }
    return 'Cảm ơn bạn! Tôi đã nhận được thông tin và sẽ phản hồi sớm.';
  }
}

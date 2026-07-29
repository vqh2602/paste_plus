import 'package:flutter/cupertino.dart';

import '../../../core/localization/app_translations.dart';

enum AiFeatureGroup {
  rewrite,
  grammar,
  summary,
  translate,
  smartReply,
  generate,
  qa,
  codeExplain,
  extractInfo,
  titlesTags,
  classify,
  ocrRefine,
}

extension AiFeatureGroupX on AiFeatureGroup {
  String get title {
    final isEn = AppTranslations.currentLanguage == 'en';
    return switch (this) {
      AiFeatureGroup.rewrite => isEn ? 'Rewrite Content' : 'Viết lại nội dung',
      AiFeatureGroup.grammar =>
        isEn ? 'Fix Spelling & Grammar' : 'Sửa chính tả & ngữ pháp',
      AiFeatureGroup.summary => isEn ? 'Summarize Content' : 'Tóm tắt nội dung',
      AiFeatureGroup.translate => isEn ? 'Translate Text' : 'Dịch văn bản',
      AiFeatureGroup.smartReply => 'Smart Reply',
      AiFeatureGroup.generate =>
        isEn ? 'Generate Content' : 'Sinh nội dung mới',
      AiFeatureGroup.qa =>
        isEn ? 'Q&A with Clipboard' : 'Hỏi đáp với Clipboard',
      AiFeatureGroup.codeExplain =>
        isEn ? 'Explain Code & Errors' : 'Giải thích Code & Lỗi',
      AiFeatureGroup.extractInfo =>
        isEn ? 'Extract Information' : 'Trích xuất thông tin',
      AiFeatureGroup.titlesTags =>
        isEn ? 'Titles & Tags' : 'Tạo tiêu đề & Từ khóa',
      AiFeatureGroup.classify =>
        isEn ? 'Smart Classification' : 'Phân loại thông minh',
      AiFeatureGroup.ocrRefine =>
        isEn ? 'Refine Image Text' : 'Xử lý văn bản từ ảnh',
    };
  }

  String get subtitle {
    final isEn = AppTranslations.currentLanguage == 'en';
    return switch (this) {
      AiFeatureGroup.rewrite => isEn
          ? 'Rewrite in natural, professional, concise, or polite tone...'
          : 'Viết lại theo phong cách tự nhiên, chuyên nghiệp, ngắn gọn, lịch sự...',
      AiFeatureGroup.grammar => isEn
          ? 'Fix spelling, grammar, awkward phrasing while preserving meaning.'
          : 'Sửa lỗi chính tả, ngữ pháp, câu thiếu tự nhiên, giữ nguyên ý nghĩa.',
      AiFeatureGroup.summary => isEn
          ? 'Condense long paragraphs into brief summaries, key points, or TODO lists.'
          : 'Rút gọn đoạn văn dài thành tóm tắt ngắn, ý chính, todo list.',
      AiFeatureGroup.translate => isEn
          ? 'Translate between English, Vietnamese or auto-detect source language.'
          : 'Dịch Việt <-> Anh hoặc tự động nhận diện ngôn ngữ.',
      AiFeatureGroup.smartReply => isEn
          ? 'Generate context-aware responses (Agree, Polite decline, Request info...).'
          : 'Tạo câu trả lời phù hợp (Đồng ý, Từ chối lịch sự, Yêu cầu thêm thông tin...).',
      AiFeatureGroup.generate => isEn
          ? 'Draft emails, messages, posts, descriptions, task lists...'
          : 'Soạn email, tin nhắn, bài đăng, mô tả, danh sách công việc...',
      AiFeatureGroup.qa => isEn
          ? 'Ask direct questions about meaning, solutions, or actions for content.'
          : 'Đặt câu hỏi trực tiếp về ý nghĩa, giải pháp hoặc hướng xử lý của đoạn văn.',
      AiFeatureGroup.codeExplain => isEn
          ? 'Explain code, analyze error logs, suggest causes & fixes.'
          : 'Giải thích code, phân tích log lỗi, gợi ý nguyên nhân & sửa lỗi.',
      AiFeatureGroup.extractInfo => isEn
          ? 'Extract Names, Phones, Emails, Dates, URLs into JSON / Tables.'
          : 'Trích xuất Tên, SĐT, Email, Ngày tháng, Link ra dạng JSON / Bảng.',
      AiFeatureGroup.titlesTags => isEn
          ? 'Generate short titles, search keywords, collection tags.'
          : 'Tạo tiêu đề ngắn, từ khóa tìm kiếm, thẻ phân loại collection.',
      AiFeatureGroup.classify => isEn
          ? 'Auto-detect categories: Work, Personal, Code, Email, Shopping...'
          : 'Tự động nhận diện nhóm: Công việc, Cá nhân, Code, Email, Mua sắm...',
      AiFeatureGroup.ocrRefine => isEn
          ? 'Clean up OCR recognition errors, fix typos and summarize text from images.'
          : 'Làm sạch lỗi nhận dạng OCR, sửa chính tả và tóm tắt văn bản từ ảnh.',
    };
  }

  IconData get icon {
    return switch (this) {
      AiFeatureGroup.rewrite => CupertinoIcons.pencil_outline,
      AiFeatureGroup.grammar => CupertinoIcons.checkmark_seal,
      AiFeatureGroup.summary => CupertinoIcons.doc_text_search,
      AiFeatureGroup.translate => CupertinoIcons.globe,
      AiFeatureGroup.smartReply => CupertinoIcons.reply,
      AiFeatureGroup.generate => CupertinoIcons.sparkles,
      AiFeatureGroup.qa => CupertinoIcons.question_circle,
      AiFeatureGroup.codeExplain =>
        CupertinoIcons.chevron_left_slash_chevron_right,
      AiFeatureGroup.extractInfo => CupertinoIcons.list_bullet_indent,
      AiFeatureGroup.titlesTags => CupertinoIcons.tag,
      AiFeatureGroup.classify => CupertinoIcons.folder_badge_plus,
      AiFeatureGroup.ocrRefine => CupertinoIcons.camera_viewfinder,
    };
  }

  List<String> get options {
    final isEn = AppTranslations.currentLanguage == 'en';
    return switch (this) {
      AiFeatureGroup.rewrite => isEn
          ? [
              'More natural',
              'More professional',
              'More concise',
              'More polite',
              'Easier to understand',
              'Send Email',
              'Social Media Post',
            ]
          : [
              'Tự nhiên hơn',
              'Chuyên nghiệp hơn',
              'Ngắn gọn hơn',
              'Lịch sự hơn',
              'Dễ hiểu hơn',
              'Gửi Email',
              'Đăng Mạng xã hội',
            ],
      AiFeatureGroup.grammar => isEn
          ? [
              'Fix all errors',
              'Fix spelling only',
              'Optimize punctuation',
              'Simplify sentences',
            ]
          : [
              'Sửa lỗi toàn bộ',
              'Chỉ sửa chính tả',
              'Tối ưu dấu câu',
              'Đơn giản hóa câu văn',
            ],
      AiFeatureGroup.summary => isEn
          ? [
              'Brief summary',
              'Key points (Bullet points)',
              'Action items (Todo list)',
              'Extract key info (Name, date, numbers)',
            ]
          : [
              'Tóm tắt 1 đoạn ngắn',
              'Các ý chính (Bullet points)',
              'Danh sách việc cần làm (Todo list)',
              'Trích xuất thông tin quan trọng (Tên, ngày, số)',
            ],
      AiFeatureGroup.translate => isEn
          ? [
              'Auto -> Vietnamese',
              'Auto -> English',
              'Preserve formatting & source code',
            ]
          : [
              'Tự động -> Tiếng Việt',
              'Tự động -> Tiếng Anh',
              'Giữ nguyên định dạng & mã nguồn',
            ],
      AiFeatureGroup.smartReply => isEn
          ? [
              'Agree / Accept',
              'Polite decline',
              'Request more information',
              'Short response',
              'Professional response',
              'Friendly response',
            ]
          : [
              'Đồng ý / Chấp nhận',
              'Từ chối lịch sự',
              'Yêu cầu thêm thông tin',
              'Trả lời ngắn gọn',
              'Trả lời chuyên nghiệp',
              'Trả lời thân thiện',
            ],
      AiFeatureGroup.generate => isEn
          ? [
              'Draft Email',
              'Draft Message',
              'Social Media Post',
              'Product Description',
              'Notes / Todo list',
              'Similar Content',
            ]
          : [
              'Soạn Email',
              'Soạn Tin nhắn',
              'Bài đăng mạng xã hội',
              'Mô tả sản phẩm',
              'Ghi chú / Todo list',
              'Nội dung tương tự',
            ],
      AiFeatureGroup.qa => isEn
          ? [
              'What does this mean?',
              'What is the key takeaway?',
              'What steps should I take?',
              'Draft an appropriate answer',
            ]
          : [
              'Đoạn này có ý nghĩa gì?',
              'Nội dung quan trọng nhất là gì?',
              'Tôi cần thực hiện những bước nào?',
              'Viết câu trả lời phù hợp',
            ],
      AiFeatureGroup.codeExplain => isEn
          ? [
              'Explain code snippet',
              'Analyze error log & cause',
              'Suggest bug fix',
              'Add explanatory comments',
              'Simplify / Refactor code',
            ]
          : [
              'Giải thích đoạn code',
              'Phân tích thông báo lỗi & nguyên nhân',
              'Gợi ý cách sửa lỗi',
              'Thêm comment giải thích vào code',
              'Đơn giản hóa / Refactor code',
            ],
      AiFeatureGroup.extractInfo => isEn
          ? [
              'Standard JSON format',
              'Markdown Table format',
              'Name, Email & Phone number',
              'Dates & Tasks',
            ]
          : [
              'Dạng JSON chuẩn',
              'Dạng Bảng (Markdown Table)',
              'Tên, Email & Số điện thoại',
              'Ngày tháng & Công việc',
            ],
      AiFeatureGroup.titlesTags => isEn
          ? [
              'Short title',
              'Search keywords',
              'Collection tags',
              'One-sentence summary',
            ]
          : [
              'Tiêu đề ngắn',
              'Từ khóa tìm kiếm',
              'Thẻ phân loại Collection',
              'Mô tả ngắn 1 câu',
            ],
      AiFeatureGroup.classify => isEn
          ? [
              'Automatic classification',
              'Evaluate importance level',
            ]
          : [
              'Phân loại tự động',
              'Đánh giá mức độ quan trọng',
            ],
      AiFeatureGroup.ocrRefine => isEn
          ? [
              'Clean up recognition errors',
              'Summarize text from image',
              'Translate text from image',
            ]
          : [
              'Sửa lỗi nhận dạng & Làm sạch',
              'Tóm tắt văn bản từ ảnh',
              'Dịch văn bản từ ảnh',
            ],
    };
  }
}


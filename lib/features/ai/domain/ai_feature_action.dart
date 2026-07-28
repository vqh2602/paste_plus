import 'package:flutter/cupertino.dart';

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
    return switch (this) {
      AiFeatureGroup.rewrite => 'Viết lại nội dung',
      AiFeatureGroup.grammar => 'Sửa chính tả & ngữ pháp',
      AiFeatureGroup.summary => 'Tóm tắt nội dung',
      AiFeatureGroup.translate => 'Dịch văn bản',
      AiFeatureGroup.smartReply => 'Smart Reply',
      AiFeatureGroup.generate => 'Sinh nội dung mới',
      AiFeatureGroup.qa => 'Hỏi đáp với Clipboard',
      AiFeatureGroup.codeExplain => 'Giải thích Code & Lỗi',
      AiFeatureGroup.extractInfo => 'Trích xuất thông tin',
      AiFeatureGroup.titlesTags => 'Tạo tiêu đề & Từ khóa',
      AiFeatureGroup.classify => 'Phân loại thông minh',
      AiFeatureGroup.ocrRefine => 'Xử lý văn bản từ ảnh',
    };
  }

  String get subtitle {
    return switch (this) {
      AiFeatureGroup.rewrite =>
        'Viết lại theo phong cách tự nhiên, chuyên nghiệp, ngắn gọn, lịch sự...',
      AiFeatureGroup.grammar =>
        'Sửa lỗi chính tả, ngữ pháp, câu thiếu tự nhiên, giữ nguyên ý nghĩa.',
      AiFeatureGroup.summary =>
        'Rút gọn đoạn văn dài thành tóm tắt ngắn, ý chính, todo list.',
      AiFeatureGroup.translate =>
        'Dịch Việt <-> Anh hoặc tự động nhận diện ngôn ngữ.',
      AiFeatureGroup.smartReply =>
        'Tạo câu trả lời phù hợp (Đồng ý, Từ chối lịch sự, Yêu cầu thêm thông tin...).',
      AiFeatureGroup.generate =>
        'Soạn email, tin nhắn, bài đăng, mô tả, danh sách công việc...',
      AiFeatureGroup.qa =>
        'Đặt câu hỏi trực tiếp về ý nghĩa, giải pháp hoặc hướng xử lý của đoạn văn.',
      AiFeatureGroup.codeExplain =>
        'Giải thích code, phân tích log lỗi, gợi ý nguyên nhân & sửa lỗi.',
      AiFeatureGroup.extractInfo =>
        'Trích xuất Tên, SĐT, Email, Ngày tháng, Link ra dạng JSON / Bảng.',
      AiFeatureGroup.titlesTags =>
        'Tạo tiêu đề ngắn, từ khóa tìm kiếm, thẻ phân loại collection.',
      AiFeatureGroup.classify =>
        'Tự động nhận diện nhóm: Công việc, Cá nhân, Code, Email, Mua sắm...',
      AiFeatureGroup.ocrRefine =>
        'Làm sạch lỗi nhận dạng OCR, sửa chính tả và tóm tắt văn bản từ ảnh.',
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
    return switch (this) {
      AiFeatureGroup.rewrite => [
        'Tự nhiên hơn',
        'Chuyên nghiệp hơn',
        'Ngắn gọn hơn',
        'Lịch sự hơn',
        'Dễ hiểu hơn',
        'Gửi Email',
        'Đăng Mạng xã hội',
      ],
      AiFeatureGroup.grammar => [
        'Sửa lỗi toàn bộ',
        'Chỉ sửa chính tả',
        'Tối ưu dấu câu',
        'Đơn giản hóa câu văn',
      ],
      AiFeatureGroup.summary => [
        'Tóm tắt 1 đoạn ngắn',
        'Các ý chính (Bullet points)',
        'Danh sách việc cần làm (Todo list)',
        'Trích xuất thông tin quan trọng (Tên, ngày, số)',
      ],
      AiFeatureGroup.translate => [
        'Tự động -> Tiếng Việt',
        'Tự động -> Tiếng Anh',
        'Giữ nguyên định dạng & mã nguồn',
      ],
      AiFeatureGroup.smartReply => [
        'Đồng ý / Chấp nhận',
        'Từ chối lịch sự',
        'Yêu cầu thêm thông tin',
        'Trả lời ngắn gọn',
        'Trả lời chuyên nghiệp',
        'Trả lời thân thiện',
      ],
      AiFeatureGroup.generate => [
        'Soạn Email',
        'Soạn Tin nhắn',
        'Bài đăng mạng xã hội',
        'Mô tả sản phẩm',
        'Ghi chú / Todo list',
        'Nội dung tương tự',
      ],
      AiFeatureGroup.qa => [
        'Đoạn này có ý nghĩa gì?',
        'Nội dung quan trọng nhất là gì?',
        'Tôi cần thực hiện những bước nào?',
        'Viết câu trả lời phù hợp',
      ],
      AiFeatureGroup.codeExplain => [
        'Giải thích đoạn code',
        'Phân tích thông báo lỗi & nguyên nhân',
        'Gợi ý cách sửa lỗi',
        'Thêm comment giải thích vào code',
        'Đơn giản hóa / Refactor code',
      ],
      AiFeatureGroup.extractInfo => [
        'Dạng JSON chuẩn',
        'Dạng Bảng (Markdown Table)',
        'Tên, Email & Số điện thoại',
        'Ngày tháng & Công việc',
      ],
      AiFeatureGroup.titlesTags => [
        'Tiêu đề ngắn',
        'Từ khóa tìm kiếm',
        'Thẻ phân loại Collection',
        'Mô tả ngắn 1 câu',
      ],
      AiFeatureGroup.classify => [
        'Phân loại tự động',
        'Đánh giá mức độ quan trọng',
      ],
      AiFeatureGroup.ocrRefine => [
        'Sửa lỗi nhận dạng & Làm sạch',
        'Tóm tắt văn bản từ ảnh',
        'Dịch văn bản từ ảnh',
      ],
    };
  }
}

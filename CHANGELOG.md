# Changelog

Tất cả các thay đổi quan trọng của dự án **ClipFlow** sẽ được ghi lại trong tệp này.

## [1.0.9] - 2026-07-30

### 🚀 Tính năng mới & Cải tiến AI
- **Tự động phân tích hình ảnh với AI**:
  - Tự động kích hoạt nhận dạng chữ Apple Vision OCR trên tệp hình ảnh được chọn làm context trước khi gửi cho AI.
  - Đóng gói thông tin tên file, ứng dụng nguồn, đường dẫn và dữ liệu OCR vào prompt ngữ cảnh chuẩn hóa cho LLM.
  - Cập nhật `AiRequestPlanner` đảm bảo luôn đính kèm tệp hình ảnh được chọn làm context cho bất kỳ câu hỏi nào của người dùng.
- **Nâng cấp giao diện hiển thị tùy chọn (CupertinoActionSheet)**:
  - Thêm icon checkmark (`✓`), font chữ đậm (Bold) và màu highlight active (`activeBlue`) cho tùy chọn đang được chọn trong dialog **Cấu hình sinh nội dung** và **Settings Selector**.
- **Hỗ trợ Windows (Beta) & Cập nhật tài liệu**:
  - Cập nhật tài liệu `README.md` và `ARCHITECTURE.md` hỗ trợ nền tảng Windows (Beta).

## [1.0.8] - 2026-07-29

### 🐛 Sửa lỗi & Cải tiến
- **Tự động tắt cửa sổ AI**: Thêm xử lý cho phép tắt cửa sổ AI bằng nút X hoặc phím Escape để giảm tải cho người dùng không có nhu cầu sử dụng.
- **Auto-Updater v2**:
  - Tự động kiểm tra và tải bản cập nhật mới ngay sau khi cài đặt.
  - Thông báo lỗi rõ ràng và thân thiện khi có sự cố xảy ra trong quá trình tải hoặc cài đặt.

## [1.0.7] - 2026-07-29

### 🚀 Nâng cấp Menu Thao tác & Sửa lỗi
- **Khôi phục Menu Thao tác theo Type**:
  - Tự động hiển thị các tác vụ tương ứng với loại dữ liệu: Trích xuất văn bản (OCR) và Tải lên Cloud cho hình ảnh; Dịch văn bản cho nội dung chữ.
  - Thêm tùy chọn "Hỏi AI Assistant" (`ask_ai`) vào menu thao tác để dễ dàng chọn clipboard làm ngữ cảnh AI và mở cửa sổ AI.
  - Tối ưu hóa UI: Loại bỏ tiêu đề xem trước văn bản trùng lặp và loại bỏ tùy chọn ghim khỏi menu.
  - Khôi phục dịch vụ dịch nhanh tức thì qua `TranslationService`.
- **Bản hóa Đa ngôn ngữ nâng cao**:
  - Bản hóa hoàn toàn loại nội dung Clipboard (`Allowed Content Types`) trong mục Cài đặt (Văn bản -> Text, Liên kết -> Link, Đường dẫn file -> File Path, Màu HEX -> HEX Color...).
  - Bản hóa các nhãn hiển thị loại nội dung trên thẻ xem nhanh Clipboard (`QuickClipboardCardWidget`) và huy hiệu Markdown (`AiMarkdownContentWidget`).
  - Đa ngôn ngữ hóa các danh mục mặc định ở thanh bên Sidebar (`Cá nhân` -> `Personal`, `Link` -> `Links`, `Mẫu trả lời` -> `Reply Templates`).

---

## [1.0.6] - 2026-07-29

### 🚀 Tính năng mới & Sửa lỗi
- **Bản hóa Đa ngôn ngữ cho Local AI Assistant**:
  - Hỗ trợ ngôn ngữ Tiếng Anh (English) toàn diện cho danh sách preset chips, quá trình suy luận (Thinking process), dialog cài đặt và nội dung hội thoại AI.
  - Tách rời và tổ chức lại toàn bộ System Prompts vào module quản lý tập trung `AiPrompts` (`ai_prompts.dart`).
- **Tự động cuộn thông minh (Auto-scroll)**:
  - Tự động cuộn xuống cuối danh sách tin nhắn khi có câu phản hồi mới hoặc đang stream tokens.
  - Thông minh giữ nguyên vị trí scroll nếu người dùng chủ động cuộn lên đọc lịch sử.

---

## [1.0.5] - 2026-07-28

### 🚀 Tính năng mới & Cải tiến
- **Sao lưu & Khôi phục cấu hình cá nhân (`.clipflow`)**:
  - Hỗ trợ xuất và nhập tệp cấu hình mã hóa bảo vệ bằng mật khẩu (`AES-256` + `PBKDF2 SHA-256` + `HMAC-SHA256`).
  - Đóng gói dữ liệu định dạng `.clipflow` (tương thích ZIP archive).
  - Tích hợp thoại chọn vị trí lưu (`NSSavePanel`) và chọn file (`NSOpenPanel`) trực tiếp ở lớp Native macOS.
- **Cập nhật giao diện Giới thiệu (About UI)**:
  - Thay thế biểu tượng placeholder bằng hình ảnh logo ứng dụng ClipFlow chính thức.

---

## [1.0.4] - 2026-07-28

### 🐛 Sửa lỗi & Cải tiến
- **Sửa lỗi quyền hệ thống Trợ năng (Accessibility) khi update / cài đè app**:
  - Thêm phương thức Native Swift `resetAccessibilityPermission` chạy lệnh `/usr/bin/tccutil reset Accessibility <bundle_id>` để làm sạch cache TCC bị hỏng khi update hoặc cài đè app.
  - Tích hợp nút **"Reset & Cấp lại quyền"** trong mục Cài đặt hệ thống.
- **Tối ưu giao diện (UI)**:
  - Loại bỏ nút `(+)` thừa trên thanh tìm kiếm của màn hình chính.

---

## [1.0.2] - 2026-07-27

### 🚀 Tính năng mới
- **Trích xuất văn bản (OCR) từ hình ảnh**:
  - Tích hợp Apple Vision Framework (`VNRecognizeTextRequest`) chạy trực tiếp ở môi trường native macOS (nhanh, chính xác, không cần kết nối mạng).
  - Thêm nút **Trích xuất văn bản (OCR)** trong màn hình chi tiết và menu tác vụ hình ảnh.
  - Tự động lưu văn bản nhận diện được thành một bản sao (text item) mới trong lịch sử clipboard và sao chép vào bộ nhớ tạm.
- **Dịch văn bản & Cài đặt ngôn ngữ dịch**:
  - Thêm cài đặt **Ngôn ngữ dịch thuật** trong màn hình Cài đặt (hỗ trợ Tiếng Việt, Tiếng Anh, Tiếng Trung, Tiếng Nhật, Tiếng Hàn, Tiếng Pháp, Tiếng Đức, Tiếng Tây Ban Nha, Tiếng Nga, Tiếng Thái, v.v.).
  - Thêm nút **Dịch văn bản** cho các mục dữ liệu dạng chữ. Tự động dịch và lưu thành một bản sao mới trong lịch sử clipboard.

### 🐛 Sửa lỗi & Cải tiến
- **Khắc phục lỗi Dark Mode**:
  - Ép kiểu `platformBrightness` toàn bộ cây giao diện và giải phóng đúng màu động `resolveColor` ở tất cả các component (Sidebar, Divider, Metadata, Details, Settings, QuickPanel).
  - Giúp ứng dụng chuyển đổi sang giao diện tối mượt mà và đồng bộ 100% khi người dùng chọn Chế độ tối.

---

## [1.0.0] - 2026-07-27

### 🌟 Phát hành đầu tiên
- Lịch sử Clipboard local-first an toàn, riêng tư trên macOS.
- Giao diệnQuickPanel và cửa sổ chính phong cách macOS.
- Hỗ trợ đa dạng nội dung: Văn bản, Liên kết, Code, Hình ảnh, Màu sắc, File.
- Quản lý Collections, Ghim item, Tìm kiếm thông minh và Phím tắt toàn hệ thống.

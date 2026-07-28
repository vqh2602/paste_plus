# Changelog

Tất cả các thay đổi quan trọng của dự án **ClipFlow** sẽ được ghi lại trong tệp này.

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

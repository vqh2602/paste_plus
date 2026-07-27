# ClipFlow (Paste Plus) 📋✨

**ClipFlow** là ứng dụng quản lý lịch sử Clipboard local-first, riêng tư và bảo mật được xây dựng bằng Flutter. Đội ngũ phát triển ưu tiên tối ưu trải nghiệm người dùng trên macOS, đồng thời sẵn sàng mở rộng giao diện responsive cho các nền tảng Desktop và Mobile khác mà không cần phụ thuộc vào bất kỳ server backend nào.

---

## 🌟 Tính năng nổi bật

### ⚡ Tự động Dán (Auto-Paste) & Quyền Trợ năng (macOS)
- **Dán tự động**: Khi chọn hoặc nhấp vào một mục trong Quick Panel, ứng dụng sẽ tự động sao chép vào bộ nhớ tạm, ẩn cửa sổ panel và tự động thực hiện thao tác dán (`⌘V`) trực tiếp vào ứng dụng đang làm việc trước đó.
- **Quản lý quyền Trợ năng (Accessibility)**: Tích hợp workflow kiểm tra và yêu cầu cấp quyền Trợ năng (`AXIsProcessTrusted`) trực quan. Cung cấp lối tắt mở thẳng phần *Quyền riêng tư & Bảo mật > Trợ năng* trong System Settings của macOS.

### 🎨 Tùy chỉnh Giao diện & Bảng màu (Accent Colors & Themes)
- **Bảng màu phong phú**: Hỗ trợ hàng loạt bộ Accent Color đa dạng và hiện đại (Indigo Mac, Ocean Blue, Emerald Mint, Sunset Orange, Cyber Violet, Monochrome Slate, cùng các tông màu Pastel như Lavender, Sky Blue, Matcha Green, Peach, Soft Coral, Soft Rose...).
- **Chế độ hiển thị**: Chuyển đổi linh hoạt giữa Sáng (Light Mode), Tối (Dark Mode) hoặc Tự động theo Hệ thống (System Theme).

### 🚫 Quản lý Ứng dụng Loại trừ (Excluded Apps Picker)
- **Chọn tiến trình đang chạy**: Giao diện chọn ứng dụng bị loại trừ trực quan từ danh sách các tiến trình active trên hệ thống macOS mà không cần gõ thủ công ID.
- **Duyệt từ Finder**: Cho phép mở trình chọn tệp `NSOpenPanel` để chọn trực tiếp ứng dụng `.app` cần bỏ qua việc theo dõi clipboard.

### 📑 Điều hướng Tab & Phân loại Linh hoạt (Quick Panel Navigation)
- **Thanh cuộn Tab loại nội dung & Collection**: Tùy chọn chuyển đổi nhanh giữa các Collection cá nhân và các loại nội dung clipboard bằng thanh tab cuộn ngang mượt mà.
- **Tự động nhận diện định dạng**: Tự động phân loại Text, URL/Link, Email, Số điện thoại, Code snippet, Màu sắc (HEX Color), JSON, Đường dẫn tệp (File Path) và Hình ảnh (PNG/JPEG).

### 🛡️ Quyền riêng tư & Lưu trữ Cục cục bộ (Local-first & Privacy)
- **Lưu trữ bảo mật**: Dữ liệu lưu hoàn toàn cục bộ trên thiết bị qua SQLite database (có hỗ trợ migration, index, transaction). Nội dung clipboard không bao giờ bị đưa vào file log.
- **Mã hóa SHA-256 & Chống trùng**: Loại bỏ item trùng lặp bằng hash SHA-256, đếm số lần sử dụng và ngăn chặn vòng lặp re-copy clipboard.
- **Bộ lọc dữ liệu nhạy cảm**: Tự động phát hiện và bỏ qua mã OTP, token/chuỗi nhạy cảm độ dài lớn, cùng tùy chỉnh giới hạn kích thước tệp/độ dài văn bản.

### 🔍 Tìm kiếm Thông minh & Cú pháp Lọc
- **Tìm kiếm tức thì**: Lọc theo từ khóa trong nội dung.
- **Cú pháp tìm kiếm nâng cao**: Hỗ trợ kết hợp các bộ lọc `type:` (vd: `type:link`), `is:pinned`, `app:` (vd: `app:Xcode`), và `after:` (thời gian).

### ⌨️ Menu Bar, Tray Icon & Hotkey Toàn cục
- **Phím tắt toàn cục (Global Hotkey)**: Kích hoạt nhanh Quick Panel từ bất kỳ đâu qua `⌘ShiftV` (hoặc `CtrlV`).
- **Khay hệ thống (System Tray / Menu Bar)**: Truy cập nhanh từ thanh menu bar macOS.
- **Khởi động cùng hệ thống**: Tùy chọn tự động khởi chạy ứng dụng khi đăng nhập hệ thống (`Launch at Startup`).
- **Tùy chỉnh ẩn/hiện Dock**: Cho phép ẩn hoặc hiện biểu tượng ứng dụng trên thanh macOS Dock.
- **Đóng nhanh**: Phím `Esc` hỗ trợ đóng nhanh cửa sổ Quick Panel hoặc ứng dụng Settings.

---

## 🏗️ Cấu trúc Kiến trúc (Architecture)

Dự án được tổ chức theo mô hình **Feature-First Architecture** kết hợp với **Riverpod** cho State Management và tầng Repository / Service rõ ràng:

```text
lib/
  app/                         # Router (GoRouter), Theme, App Providers & Configuration
  core/
    database/                  # SQLite schema, migration & helper logic
    platform/                  # macOS native channels, tray, hotkey, startup, window manager
    services/                  # Isolation Clipboard Watcher, Logging & Policy services
    ui/                        # macOS Cupertino shared components & UI primitives
  features/
    clipboard_history/
      data/                    # SQLite repository implementation
      domain/                  # Data models, content classifier, search syntax & retention policy
      presentation/            # Quick panel screen, Home screen, cards & controllers
    onboarding/
      presentation/            # 5-step onboarding page
    settings/
      domain/                  # AppSettings data model
      presentation/            # General settings, Privacy, Storage & App Exclusions settings
```

- **Lưu trữ hình ảnh**: Ảnh clipboard được lưu trực tiếp vào thư mục `Application Support` của ứng dụng; SQLite chỉ lưu trữ đường dẫn tệp để tối ưu hiệu năng database.

---

## 🚀 Hướng dẫn Cài đặt & Chạy ứng dụng

### Yêu cầu
- Flutter SDK `>=3.11.5`
- Xcode 15+ (đối với macOS build)

### 1. Cài đặt Dependencies
```bash
flutter pub get
```

### 2. Chạy ứng dụng trên macOS
```bash
flutter run -d macos
```

---

## 🧪 Kiểm thử và Build

Ứng dụng đi kèm bộ unit test và widget test đầy đủ nhằm bảo đảm tính ổn định của cơ chế mã hóa, phân loại, tìm kiếm và lưu trữ database.

### Chạy phân tích mã nguồn (Linting)
```bash
flutter analyze
```

### Chạy toàn bộ Unit & Widget Tests
```bash
flutter test
```

### Build bản phát hành macOS
```bash
flutter build macos --release
```

### 🚀 Tự động Build & Phát hành qua GitHub Actions (CI/CD)
Dự án được tích hợp sẵn GitHub Actions workflow tại [.github/workflows/release_macos.yml](file:///Users/vuongquanghuy/code/flutter_project/paste_plus/.github/workflows/release_macos.yml):
- **Tự động kích hoạt khi push tag**: Khi push một tag mới (vd: `git tag v1.0.0 && git push origin v1.0.0`), GitHub Actions sẽ tự động chạy test, build bản phát hành macOS `--release`, đóng gói thành `ClipFlow-macOS.zip` và tạo **GitHub Release** đính kèm file ứng dụng.
- **Kích hoạt thủ công (Workflow Dispatch)**: Bạn cũng có thể vào tab *Actions* trên GitHub, chọn workflow *Build & Release macOS App* và nhấn *Run workflow* để tạo bản release thủ công.

---

## 🔐 Quyền hạn Hệ thống & Cấu hình macOS (Entitlements)

Để tính năng **Auto-Paste** và gửi phím tắt mô phỏng (`⌘V`) hoạt động ổn định sang các ứng dụng khác trên macOS:
1. Quyền **Accessibility**: Cần được cấp phép trong *System Settings > Privacy & Security > Accessibility*.
2. **App Sandbox**: File `DebugProfile.entitlements` và `Release.entitlements` đã được định cấu hình tắt App Sandbox (`com.apple.security.app-sandbox = false`) để cho phép thực thi AppleScript / System Events paste command sang ứng dụng tiền nhiệm.

---

## 📌 Giới hạn hiện tại & Định hướng tiếp theo

- **Quick Panel Window**: Hiện tại Quick Panel chia sẻ cùng native window và điều chỉnh kích thước động khi gọi từ hotkey.
- **Đồng bộ hóa**: Chưa tích hợp đồng bộ Cloud (iCloud/e2e encrypted sync) và khóa sinh trắc học (Touch ID/Face ID).
- **Nền tảng Mobile**: iOS/Android đang hoạt động theo dạng mô hình ứng dụng đồng hành do giới hạn background clipboard restriction từ phía OS.

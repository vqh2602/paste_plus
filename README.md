# ClipFlow

ClipFlow là ứng dụng quản lý clipboard local-first bằng Flutter. Bản MVP ưu tiên macOS, có giao diện responsive cho desktop/mobile và không cần backend.

## Tính năng đã có

- Theo dõi clipboard khi ứng dụng chạy; polling được cô lập sau `ClipboardWatcher`.
- Native channel macOS cho text, PNG và thông tin ứng dụng đang hoạt động.
- SQLite có migration, index, transaction và bảng liên kết collection.
- Nhận diện text, URL, email, số điện thoại, code, màu HEX, JSON, file path và hình ảnh.
- Hash SHA-256, chống trùng, đếm số lần dùng và tránh vòng lặp khi sao chép lại.
- Tìm kiếm tức thì, filter trực quan và cú pháp `type:`, `is:pinned`, `app:`, `after:`.
- Ghim, xóa, xóa toàn bộ, collection mặc định và collection tùy chỉnh.
- Retention theo ngày/số item/dung lượng; bảo vệ item ghim hoặc nằm trong collection.
- Privacy rules cho OTP, token dài, giới hạn độ dài/kích thước và ứng dụng loại trừ.
- Onboarding 5 bước, dark mode, Settings và empty/error states.
- Menu bar/system tray, mở cùng hệ điều hành và global shortcut (`⌃V` hoặc `⌘⇧V` trên macOS).

## Kiến trúc

Mã nguồn theo feature-first, dùng Riverpod + repository/service layer:

```text
lib/
  app/                         # app, router, theme, providers
  core/
    database/                  # SQLite schema và migration
    platform/                  # tray, hotkey, startup, window
    services/                  # clipboard watcher, logging
  features/
    clipboard_history/
      data/                    # SQLite repository
      domain/                  # model, classifier, search, policy
      presentation/            # controller và màn hình chính
    onboarding/presentation/
    settings/
```

Nội dung clipboard không được ghi vào log. Hình ảnh nằm trong Application Support và SQLite chỉ giữ đường dẫn.

## Chạy

```bash
flutter pub get
flutter run -d macos
```

Android/iOS dùng cùng giao diện responsive. Trên mobile, nút **Lưu clipboard** đọc nội dung hiện tại theo giới hạn của hệ điều hành.

## Kiểm thử và build

```bash
flutter analyze
flutter test
flutter build macos
```

Widget test dùng watcher/repository in-memory; database test dùng SQLite FFI và chạy tuần tự qua `dart_test.yaml`.

## Giới hạn hiện tại

- Quick panel dùng cùng native window và chuyển đổi kích thước/trạng thái khi gọi bằng hotkey; chưa tách thành native window thứ hai độc lập.
- Lấy source app là best-effort và phụ thuộc nền tảng; macOS dùng ứng dụng đang active khi phát hiện thay đổi.
- Theo dõi nền trên iOS/Android bị giới hạn bởi hệ điều hành, nên mobile hoạt động theo mô hình ứng dụng đồng hành.
- Đồng bộ cloud, khóa sinh trắc học và share extension thuộc giai đoạn sau.
- Scaffold Windows/Linux không thể sinh hoặc build trên Flutter host hiện tại; Dart/service layer và plugin đã chọn có hỗ trợ hai nền tảng này.

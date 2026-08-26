# Changelog

## [2.0.0] - 2026-08-25

### 🛡️ Bảo vệ dữ liệu nhạy cảm & quyền riêng tư
- Thêm bộ lọc tùy chọn để bỏ qua số thẻ thanh toán hợp lệ theo thuật toán **Luhn** và mã định danh/hộ chiếu. Nhận dạng trực tiếp bằng checksum hoặc cấu trúc chặt cho Việt Nam, Mỹ, Trung Quốc, Ấn Độ, Nhật Bản, Thái Lan, Singapore, Đài Loan, Tây Ban Nha và Hàn Quốc; hộ chiếu quốc tế còn được nhận qua nhãn đa ngôn ngữ hoặc MRZ ICAO, đồng thời không còn bị phân loại nhầm thành số điện thoại.
- Mở rộng phân loại số điện thoại bằng metadata libphonenumber cho các quốc gia trên toàn cầu; hỗ trợ mã quốc gia `+`/`00`, định dạng nội địa phổ biến, dấu chấm/gạch/ngoặc, `tel:`, số máy lẻ và chữ số Unicode trong khi loại trừ ngày tháng, mã định danh và mã quốc gia không hợp lệ.
- Sửa trình cập nhật Windows portable: updater nay chờ đúng PID của ClipFlow, giải nén ZIP trực tiếp bằng Dart, xác thực đầy đủ `clipflow.exe`, `flutter_windows.dll`, `data/app.so` và `data/flutter_assets`, sau đó thay thế toàn bộ thư mục release bằng `robocopy` rồi khởi động lại ứng dụng tại đúng ổ đĩa cài đặt.
- Khôi phục khả năng build Windows bằng MSVC 14.51 bằng lớp tương thích giới hạn riêng cho `local_auth_windows`, tránh lỗi STL1011 từ `<experimental/coroutine>` mà không tắt cảnh báo cho toàn bộ ứng dụng.
- Thêm bảo vệ cửa sổ nhạy cảm trên macOS/Windows: bỏ qua clipboard khi con trỏ đang ở ô mật khẩu hoặc tiêu đề cửa sổ thể hiện đăng nhập, xác thực, thanh toán hay ngân hàng.
- Thêm tùy chọn loại cửa sổ ClipFlow khỏi ảnh chụp, bản ghi và luồng chia sẻ màn hình bằng API bảo vệ nội dung native của hệ điều hành.
- Tất cả ba lớp bảo vệ đều có công tắc riêng trong **Cài đặt > Quyền riêng tư**.
- Sửa lỗi bật Tủ khóa trên macOS có thể phát sinh Keychain `-34018`: loại bỏ thao tác xóa khóa xác thực thiết bị không cần thiết, chỉ cập nhật trạng thái sau khi ghi kho bảo mật thành công và hiển thị lỗi có kiểm soát nếu secure storage không khả dụng.
- Sửa Quick Panel bị ẩn và khóa lại Tủ khóa khi Touch ID/Windows Hello tạm thời làm mất focus; cửa sổ nay giữ nguyên trong quá trình xác thực và tự lấy lại focus sau khi hộp thoại hệ thống đóng.

### 📦 Xuất dữ liệu & tìm kiếm có hướng dẫn
- Nâng `.clipflow` thành gói dữ liệu đầy đủ gồm cài đặt, lịch sử clipboard, ảnh, Collection và quan hệ phân loại; Tủ khóa cùng khóa mã hóa thiết bị luôn bị loại trừ.
- Lịch sử được mã hóa xác thực bằng **AES-256-GCM** với khóa PBKDF2-HMAC-SHA256 210.000 vòng; trình nhập bỏ qua trường tương lai chưa biết, bù giá trị mặc định cho trường cũ và vẫn đọc được tệp cấu hình `.clipflow` v1.
- Thêm đề xuất cú pháp `app:`, `note:`, `type:`, `is:pinned` và `after:` ngay tại ô tìm kiếm của cửa sổ chính lẫn Quick Panel; có thể bấm để chèn tại con trỏ và các biểu thức tìm kiếm đặc biệt được in đậm để dễ phân biệt với từ khóa thường.

### 🔐 Tủ khóa bảo mật
- Thêm **Tủ khóa** dưới dạng Collection hệ thống được tạo sẵn, không thể đổi tên hoặc xóa.
- Clipboard được kéo vào Tủ khóa sẽ biến mất khỏi lịch sử, tìm kiếm, AI và đồng bộ thiết bị; nội dung chỉ hiển thị sau khi mở khóa đúng cách.
- Hỗ trợ mở khóa bằng mật khẩu hoặc phương thức xác thực thiết bị (vân tay, Face ID, Windows Hello hay mã khóa hệ thống tùy nền tảng).
- Thêm cấu hình bật/tắt Tủ khóa, đổi mật khẩu, bật/tắt xác thực thiết bị và tùy chọn tự xóa dữ liệu Tủ khóa sau 5 lần nhập sai liên tiếp.
- Mã hóa tại chỗ bằng **AES-256-GCM** với khóa chính ngẫu nhiên; mật khẩu bảo vệ khóa bằng **PBKDF2-HMAC-SHA256 (210.000 vòng)**. Trường dữ liệu nhạy cảm trong SQLite và tệp ảnh thuộc Tủ khóa đều không còn lưu ở dạng đọc được.
- Tự khóa khi ứng dụng mất tiêu điểm hoặc chuyển nền; các tệp xem trước đã giải mã được dọn ngay khi khóa.

### 🧱 Cô lập dữ liệu & tương thích
- Thêm submenu **Chuyển đổi văn bản** cho định dạng/thu nhỏ JSON, Base64, URL encode/decode, đổi hoa thường, Title Case, phân tích timestamp, MD5, sắp xếp và loại bỏ dòng trùng; kết quả được sao chép/lưu thành mục mới mà không ghi đè bản gốc.
- Thêm **Link Cleaner** chỉ xuất hiện với URL để loại bỏ tham số theo dõi nhưng giữ nguyên tham số nghiệp vụ và fragment.
- Thêm tính toán biểu thức an toàn ngay trên thẻ clipboard và vùng chi tiết, cùng nhận diện **JWT** và ngôn ngữ lập trình phổ biến.
- Thêm phân loại **Emoji** cho emoji đơn, chuỗi emoji, cờ, màu da, ZWJ và keycap; văn bản có xen emoji vẫn được giữ đúng loại Văn bản.
- Tủ khóa bị loại khỏi FTS, truy vấn AI, dọn lịch sử thông thường và luồng đồng bộ LAN để tránh rò rỉ dữ liệu ngoài ý muốn.
- Khi tắt Tủ khóa, dữ liệu được giải mã và đưa trở lại lịch sử trước khi khóa mã hóa bị xóa.
- Bổ sung cấu hình native cho Local Authentication trên Android/iOS và bản địa hóa giao diện Tủ khóa trên cả 6 ngôn ngữ.
- Nâng schema SQLite lên phiên bản 8, bổ sung kiểm thử mã hóa văn bản/ảnh, khóa/mở khóa, khôi phục, tự xóa, công cụ văn bản thông minh, phân loại Emoji/JWT, bộ lọc nhạy cảm, archive và gợi ý tìm kiếm; toàn bộ **273 kiểm thử** đều đạt.

## [1.1.7] - 2026-08-25

### 🐛 Sửa lỗi & Cải tiến
- **Chia sẻ Clipboard an toàn hơn**:
  - Refactor cơ chế chia sẻ clipboard để bảo toàn đúng loại nội dung (content types) khi chia sẻ giữa các thiết bị.
  - Bổ sung kiểm tra an toàn (`mounted context checks`) để tránh lỗi khi widget đã bị huỷ trước khi thao tác hoàn tất.

## [1.1.6] - 2026-08-25

### 🚀 Tính năng mới & Cải tiến
- **Quản lý Clipboard và Collection trực quan hơn**:
  - Cho phép kéo thả clipboard vào Collection ngay trên màn hình danh sách; Collection đích được làm nổi bật khi rê qua và thông báo xác nhận hiển thị đúng tên Collection sau khi thêm.
  - Thu gọn menu thao tác của clipboard, Collection và Quick Panel theo phong cách menu native, không thay đổi bố cục thẻ hiện có.
  - Bổ sung Preview, Edit, Share, Paste as Plain Text và Open cho liên kết; Share khả dụng với mọi loại clipboard và gửi đúng payload URL, file/ảnh hoặc văn bản để hệ điều hành lọc đích chia sẻ phù hợp.
  - Hỗ trợ chỉnh sửa văn bản, màu và xoay ảnh trước khi lưu.
- **Preview và metadata đầy đủ hơn**:
  - Preview văn bản toàn màn hình nội dung và hiển thị kích thước pixel thực tế đối với hình ảnh.
  - Hiển thị số ký tự, kích thước ảnh hoặc kiểu mã màu trong Quick Panel và vùng thông tin chi tiết của cửa sổ chính.
- **Nhận diện file chính xác trên macOS và Windows**:
  - Ưu tiên file URL từ Finder và `CF_HDROP` từ Windows Explorer trước thumbnail hoặc dữ liệu text đi kèm.
  - File Word, Excel, PDF, file ảnh và nhiều file được copy cùng lúc đều được lưu dưới loại File với đường dẫn tương ứng; ảnh copy trực tiếp từ ứng dụng vẫn giữ loại Image.
- **Cloud Image Hosting với ImgBB**:
  - Thêm ImgBB API v1 bên cạnh FreeImage.host, upload file cục bộ bằng `POST multipart/form-data` và hỗ trợ ảnh tối đa 32 MB.
  - Cho phép chọn nhà cung cấp, lưu API key riêng và tự động sao chép/lưu URL ảnh sau khi upload thành công.
- **Bản địa hóa mở rộng**:
  - Cho phép chọn toàn bộ ngôn ngữ đã dịch: Tiếng Việt, English, 日本語, 한국어, Deutsch và 简体中文.
  - Bổ sung đầy đủ bản dịch tiếng Trung giản thể và đồng bộ locale với các tính năng AI/dịch thuật.

### 📱 Nền tảng & Chất lượng
- Cập nhật tài liệu xác định **iOS (Beta)** và **Android (Beta)**, kèm hướng dẫn build/chạy từ source.
- Mở rộng kiểm thử hồi quy cho clipboard file, chỉnh sửa/menu, chia sẻ theo loại dữ liệu, bản địa hóa và request upload ImgBB; toàn bộ 235 kiểm thử đều đạt.

## [1.1.5] - 2026-08-06

### 🚀 Tính năng mới & Cải tiến
- **Quản lý Ghi chú Clipboard (Clipboard Notes)**:
  - Thêm tính năng đính kèm ghi chú cho từng mục Clipboard với hộp thoại chỉnh sửa tự động lưu.
  - Hỗ trợ tìm kiếm các mục clipboard theo cú pháp `note:`.
  - Bổ sung nút Chỉnh sửa (Edit) riêng biệt và khung cuộn giới hạn chiều cao cho phần ghi chú trên các thẻ Clipboard Card.
- **Nâng cấp Hệ thống Trợ lý AI (AI Agent & Execution Pipeline)**:
  - **Kiến trúc AI Tool mới**: Đại trùng tu hệ thống AI Tool với payload có kiểu rõ ràng (`AiToolPayload`), triển khai quy trình thực thi Agent theo cấu trúc (`Structured Agent Execution Pipeline`).
  - **Phân loại Ý định & Xếp hạng Liên quan**: Nâng cấp lập kế hoạch yêu cầu (`AiRequestPlanner`), tổng hợp ngữ cảnh đa phương tiện (Multi-modal context synthesis) và xếp hạng kết quả tìm kiếm clipboard theo mức độ liên quan.
  - **Banner tải mô hình Classifier**: Thêm banner giao diện hiển thị trạng thái và tiến trình tải xuống riêng cho mô hình phân loại intent.
  - **Tối ưu hóa Phản hồi AI**: Tăng giới hạn token cho phản hồi (`max_tokens`), tối ưu hóa prompt tìm kiếm clipboard, định dạng hiển thị clipboard thân thiện và bổ sung cơ chế fallback parsing cho JSON bị cắt ngắn.
- **Cải tiến Giao diện & Tương tác (UI & Card Interactions)**:
  - Chuyển đổi callback ghim sang bất đồng bộ (`async`) và tách biệt hoàn toàn thao tác nhấn/chạm trên thẻ Clipboard Card để tránh xung đột hành vi.

## [1.1.4] - 2026-08-04

### 🚀 Cải tiến & Sửa lỗi
- **Theo dõi Clipboard đáng tin cậy**:
  - Tích hợp `changeCount` (macOS) và `GetClipboardSequenceNumber` (Windows) để bắt chính xác mọi thao tác copy (shortcut, nút Copy trên trang web/app, menu ngữ cảnh).
  - Khôi phục chính xác ứng dụng đã copy trước đó khi ClipFlow hiển thị.
- **Tối ưu hóa & Ổn định**:
  - Khắc phục các cảnh báo phân tích mã nguồn (`flutter analyze`) và đảm bảo bộ kiểm thử unit test đạt 100% thành công.

## [1.1.3] - 2026-08-01

### 🚀 Cải tiến & Sửa lỗi
- **Menu ngữ cảnh chuột phải trên Khay hệ thống (System Tray)**:
  - Bổ sung xử lý sự kiện click chuột phải (`onTrayIconRightMouseDown`) trên icon thanh Menu Bar (macOS) và Khay hệ thống (Windows).
  - Tự động bật pop-up menu hỗ trợ 4 lựa chọn nhanh: Màn hình chính, Mở Quick Panel, Kiểm tra cập nhật và Thoát ứng dụng.

## [1.1.2] - 2026-07-31

### 🐛 Sửa lỗi
- **Quick Panel**: Sau khi dán một kết quả tìm kiếm, xóa đồng thời query lọc và nội dung ô tìm kiếm. Lần mở Quick Panel kế tiếp luôn hiển thị danh sách đúng, không còn trạng thái lọc cũ dưới ô tìm kiếm trống.

## [1.1.1] - 2026-07-30

### 🐛 Sửa lỗi & Cải tiến
- **Ghi phím tắt đáng tin cậy**: Recorder hiện lắng nghe trọn vẹn tổ hợp phím, bỏ qua phím bổ trợ đơn lẻ và chỉ lưu khi người dùng bấm **Lưu**.
- **Chặn shortcut trong khi ghi**: Tạm dừng global hotkey và chặn sự kiện phím trong suốt quá trình nhập, tránh việc tổ hợp cũ mở Quick Panel ngoài ý muốn; hủy bằng Escape sẽ phục hồi shortcut cũ.
- **Sửa lỗi đóng ứng dụng khi lưu**: Không còn unregister/register native hotkey lặp trong lúc recorder đang mở; callback global được chặn an toàn rồi bật lại sau khi lưu hoặc hủy.
- **Khôi phục mặc định**: Thêm nút khôi phục toàn bộ phím tắt mặc định, bao gồm phím mở Quick Panel và các phím tắt trong ứng dụng.
- **Độ ổn định đăng ký hệ thống**: Chỉ lưu shortcut toàn hệ thống sau khi hệ điều hành đăng ký thành công; nếu bị ứng dụng khác chiếm, cấu hình trước đó được giữ nguyên.

## [1.1.0] - 2026-07-30

### 🚀 Tính năng nổi bật & Cải tiến
- **Đồng bộ hóa Thời gian thực (Real-time Sync) & Đồng bộ Trạng thái**:
  - **Tự động đồng bộ Ghim (Pin)**: Trạng thái ghim của các mục clipboard được truyền tải và áp dụng tự động giữa các thiết bị được ghép nối.
  - **Tự động đồng bộ Bộ sưu tập (Collections)**: Các tệp/nội dung clipboard nằm trong Collection sẽ tự động gửi và tạo/đưa vào đúng Collection tương ứng tại thiết bị nhận.
  - **Đồng bộ Collection độc lập**: Hỗ trợ đồng bộ hóa các sự kiện tạo, đổi tên, thay đổi thứ tự sắp xếp hoặc xóa Collection giữa các thiết bị mà không cần chờ thay đổi từ clipboard.
  - **Drain Sync hoàn chỉnh**: Tự động xếp hàng và đồng bộ toàn bộ dữ liệu lịch sử cũ (bao gồm trạng thái Pinned & Collections) ngay khi thiết bị kết nối thành công.
- **Cơ chế Tự động Kết nối lại (Auto-Reconnect)**:
  - Tích hợp hệ thống tự động kết nối lại thông minh cho các thiết bị tin cậy bằng giải thuật lùi thời gian lũy thừa (Exponential Backoff) lên đến 5 lần trước khi chuyển sang chế độ kết nối thủ công.

### 📱 Hỗ trợ Thiết bị di động (Android & iOS)
- **Tương thích SafeArea**: Bọc các màn hình chính (`HomeScreen`, `QuickPanelScreen`, `AiChatScreen`) trong `SafeArea` giúp giao diện không bị đè bởi Status bar, tai thỏ (Notch) hay Dynamic Island trên iOS/Android.
- **Sửa lỗi kích hoạt AI Chat**: Sửa lỗi logic ngăn mở màn hình AI Chat Assistant (`showAiWindow`) khi chạy trên môi trường di động.
- **Tùy chỉnh Bảo mật & Khóa tên thiết bị**: Khóa ô chỉnh sửa tên thiết bị (`device_display_name`) khi có thiết bị khác đang kết nối để bảo vệ phiên xác thực TLS đang chạy.

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

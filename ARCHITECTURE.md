# ClipFlow Technical Architecture & Developer Guide 🛠️

Welcome to the technical architecture documentation for **ClipFlow** (Paste Plus). This document provides an in-depth overview of the codebase design, cross-platform architecture (**macOS Stable; Windows, iOS, and Android Beta**), data flow, native platform channels, storage engine, local AI engine, optional cloud actions, and CI/CD pipelines.

---

## 🏛️ System Overview & Design Patterns

ClipFlow is built using **Flutter** and follows a **Feature-First Architecture** combined with **Riverpod** state management. The core guiding principles are:
- **Local-First Core**: Clipboard capture, history, search, collections, metadata, and configuration remain on-device. Network access is isolated to explicit user actions such as image hosting, online translation, update checks, LAN sharing, or model downloads.
- **On-Device Local AI Engine**: Integrated with `llamadart` / `llama.cpp` to run local GGUF Large Language Models directly on the user's CPU/GPU without cloud APIs.
- **Local-First LAN Synchronization**: Deep, secure, real-time synchronization of clipboard items, pinned statuses, and collection folders across devices in the same local network:
  - **TLS-secured Connection**: Native FFI socket encryption.
  - **Event-Driven Collection & Sync Protocols**: Immediate updates for create, rename, order change, or deletion of Collections.
  - **Smart Reconnection Flow**: Background reconnection mechanism utilizing an Exponential Backoff retry schedule (up to 5 attempts, with staggered timing based on device preference hierarchy).
  - **Complete Drain Synchronization**: Enqueues and synchronizes the entire historical clipboard dataset including categorized collections and pinned flags right when a pairing connection completes.
- **Unidirectional Data Flow**: State is managed via Riverpod controllers (`StateNotifier` / `Notifier`), ensuring predictable reactivity across UI components.
- **Cross-Platform Interoperability**: Deep native integration on **macOS**, **Windows (Beta)**, **iOS (Beta)**, and **Android (Beta)**:
  - **macOS**: MethodChannels for global hotkeys, Accessibility permissions (`AXIsProcessTrusted`), AppleScript system events auto-paste, Apple Vision OCR, and System Menu Bar tray.
  - **Windows (Beta)**: Win32 API (`win32` & `win32_registry`), `window_manager`, `tray_manager`, `hotkey_manager`, simulated `keybd_event` / `SendInput` `Ctrl+V` auto-pasting, and SQLite FFI backend.
  - **Mobile (iOS & Android Beta)**: Specialized `SafeArea` layouts, foreground clipboard workflows, platform SQLite, and mobile-friendly local AI interfaces. Continuous background clipboard access remains subject to operating-system privacy and lifecycle restrictions.

---

## 📁 Directory & Project Structure

```text
.
├── lib/
│   ├── app/                          # Bootstrap, routing, app providers & themes
│   ├── core/
│   │   ├── database/                 # SQLite selection, migrations, FTS, embeddings & indexes
│   │   ├── localization/             # BuildContext localization helpers
│   │   ├── platform/                 # Hotkeys, tray, auto-paste & startup integrations
│   │   ├── services/                 # Clipboard, cloud upload, OCR, translation & update services
│   │   ├── theme/                    # Theme, accent colors & typography
│   │   └── ui/                       # Shared Cupertino components, dialogs & notices
│   ├── features/
│   │   ├── ai/                       # Local AI engine, planning, tools, conversations & UI
│   │   ├── clipboard_history/        # Classifier, repository, Home, Quick Panel & actions
│   │   ├── device_sync/              # TLS LAN pairing, peer state, queues & metadata sync
│   │   ├── onboarding/               # First-run and retention setup
│   │   ├── settings/                 # AppSettings, encrypted backup & settings UI
│   │   └── vault/                    # Vault crypto, authentication, state & unlock dialogs
│   └── l10n/                         # ARB sources and generated vi/en/ja/ko/de/zh classes
├── android/                          # Android Beta runner and platform configuration
├── ios/                              # iOS Beta runner and entitlements
├── macos/                            # macOS Swift runner and native MethodChannels
├── windows/                          # Windows C++ runner, CF_HDROP and Win32 integrations
├── linux/                            # Flutter Linux runner scaffold
└── test/                             # Unit, widget, database and networking tests
```

---

## 💾 Storage & Data Management Engine

### 1. Cross-Platform Database Engine (SQLite & SQLite FFI)
ClipFlow selects the SQLite backend per target platform:
- **macOS / Windows / Linux**: Initializes `sqflite_common_ffi` and uses the desktop FFI database factory.
- **iOS / Android Beta**: Uses the registered mobile SQLite platform implementation.

#### Database Schema (`clipboard_items` & `collections`)
- **`clipboard_items` Table**:
  - `id`: TEXT PRIMARY KEY
  - `content_hash`: TEXT UNIQUE (SHA-256 hash for O(1) deduplication)
  - `content`: TEXT
  - `normalized_content`: TEXT
  - `content_type`: TEXT (text, url, email, phone, color, json, jwt, emoji, file, code, image)
  - `image_path`: TEXT (Local relative file path to application support storage)
  - `is_pinned`: INTEGER (0 or 1)
  - `is_sensitive`: INTEGER (0 or 1)
  - `source_app_name`: TEXT (Bundle ID or app executable name)
  - `source_app_identifier`: TEXT
  - `copy_count`: INTEGER
  - Structured search features: `contains_url`, `primary_url`, `url_host`, `url_kind`, `mime_type`, `file_extension`, `has_ocr_text`, and `searchable_text`
  - `created_at`: INTEGER (Epoch timestamp)
  - `updated_at`: INTEGER
  - `last_copied_at`: INTEGER
  - `is_vault`: INTEGER (1 only for encrypted Vault rows; normal queries and FTS require 0)

- **`collections` Table**:
  - `id`: TEXT PRIMARY KEY
  - `name`: TEXT UNIQUE
  - `icon`: TEXT
  - `created_at`: INTEGER
  - `updated_at`: INTEGER
  - `sort_order`: INTEGER

- **`clipboard_item_collections` Join Table**:
  - Composite primary key: (`clipboard_item_id`, `collection_id`)
  - Enables many-to-many Collection membership without embedding a single Collection ID in the clipboard item.
  - Foreign keys cascade on item or Collection deletion.

### 2. File & Image Storage Directory
Images copied to the clipboard are written to disk under the sandboxed Application Support directory:
- **macOS**: `/Users/{user}/Library/Application Support/com.clipflow.clipflow/clipboard_images/`
- **Windows (Beta)**: `%LOCALAPPDATA%\clipflow\clipboard_images\`
- **iOS / Android Beta**: The platform Application Support directory returned by `path_provider`.

### 3. Retention & Protection Policy
- **Automatic Purge**: Evaluated on startup and upon new clipboard additions.
- **Protection Priority**:
  1. Pinned items (`is_pinned == 1`) and items inside custom Collections are **never** auto-cleared.
  2. Image items are prioritized for cleanup if storage usage exceeds user thresholds (`maxDatabaseMb`).
  3. Items older than configured `retentionDays` (1, 7, 30, 90, 365, or Unlimited) are purged automatically.

---

## 📋 Clipboard Ingestion & Classification Pipeline

1. **Platform watcher selection** (`clipboardWatcherProvider`):
   - macOS uses `MacOSClipboardWatcher` and `NSPasteboard.changeCount`.
   - Windows Beta uses `WindowsClipboardWatcher` and `GetClipboardSequenceNumber()`.
   - iOS/Android Beta and other platforms use the foreground `FlutterClipboardWatcher` fallback.
2. **Typed native payload** (`ClipboardPayload`): text, image bytes, source application metadata, an explicit `filePaths` list, and the native `sensitiveContext` signal travel through one domain object.
3. **File-first native decoding**:
   - macOS reads Finder file URLs before `.png`/TIFF thumbnail data.
   - Windows reads Explorer `CF_HDROP` paths before `CF_UNICODETEXT` or bitmap formats.
   - A file-list payload suppresses thumbnail bytes, so copied Word, Excel, PDF, folder, or image files are stored as **File** rather than **Image**.
4. **Privacy gate, classification and persistence**: `SqliteClipboardRepository` first applies each enabled policy: OTP/long-token filtering, a Luhn check for 13–19 digit payment-card candidates, label-bound identity/passport recognition, and the native sensitive-window signal. Rejected payloads never reach SQLite. `ContentClassifier` then recognizes URLs, email, phone, color, JSON, JWT, Emoji, code, single/multiple POSIX paths, Windows paths, UNC paths, and file URLs. `SmartTextTools` additionally detects common programming-language signatures and evaluates only a bounded, explicitly parsed mathematical grammar. Accepted items are normalized, hashed, deduplicated, enriched with searchable features, and persisted.
5. **Presentation actions**: Home and Quick Panel share compact action menus for preview, edit, open, paste-as-plain-text, share, pin, delete, OCR, translation, cloud upload, Link Cleaner and a nested text-conversion menu. Text transforms are pure local operations and create a new clipboard item rather than mutating the source. Share routing preserves the clipboard type by sending a URI, file/image payload, or text to the platform. Clipboard cards can be dragged onto Collections with hover feedback. Both search surfaces use the same syntax-suggestion component for `app:`, `note:`, `type:`, `is:pinned`, and `after:` filters.

---

## 🔐 Vault Security Architecture

The Vault is a reserved Collection (`id = vault`) seeded by schema version 8. It cannot be renamed, deleted, synchronized, or addressed by AI tools. Moving an item into it removes every normal Collection membership and marks the row with `is_vault = 1`; all regular history, structured search, FTS, cleanup, and bulk-query paths explicitly require `is_vault = 0`.

### Key hierarchy and authentication

1. A random 256-bit master key is generated when the Vault is enabled.
2. The user's password derives a wrapping key through PBKDF2-HMAC-SHA256 (210,000 iterations and a random salt).
3. AES-256-GCM wraps the master key and authenticates every encrypted database field or file payload.
4. The wrapped-key configuration is stored in OS-backed secure storage. If device unlock is enabled, a secure-storage copy of the master key is only loaded after `local_auth` succeeds (Touch ID, Face ID, fingerprint, Windows Hello, or the device credential supported by the OS).
5. The in-memory key and decrypted image previews are cleared whenever the app loses focus, moves to the background, leaves the Vault, or is explicitly locked.

### At-rest data boundary

- Text, normalized text, hashes, source-app metadata, notes, URLs, MIME data, and extensions are AES-GCM ciphertext in SQLite while vaulted.
- Image bytes are moved from `clipboard_images/` into encrypted `.cfv` files under `vault_files/`. A decrypted preview exists only in the system temporary directory while unlocked and is deleted on lock.
- Searchable feature columns are blanked while vaulted, and FTS triggers never index Vault rows.
- Vault items do not enter LAN synchronization or embedding/AI indexing. Copying an unlocked Vault item is temporarily suppressed from clipboard recapture to prevent an immediate plaintext duplicate.
- The optional five-failure policy deletes only Vault rows/files; normal clipboard history remains intact. Disabling the feature first decrypts and restores Vault items to normal history, then deletes the key material.

---

## 🤖 On-Device Local AI Architecture

ClipFlow features a 100% local AI assistant powered by GGUF Large Language Models:
1. **Local Inference Engine (`llamadart`)**: Loads `.gguf` quantized models (e.g. Qwen2.5-Coder-1.5B, Gemma-2B, DeepSeek-R1-Distill-Qwen) directly onto the local CPU/GPU using C FFI bindings to `llama.cpp`.
2. **Context-Aware Request Planner (`AiRequestPlanner`)**: Automatically analyzes user prompts and clipboard context to route requests (Conversation, Clipboard Action, Search RAG, or Follow-up).
3. **Automatic Vision & OCR Integration**: When an image is attached as AI context, ClipFlow automatically executes native OCR (Apple Vision on macOS) to extract text and format a rich context block for the model.
4. **Token Budget Manager (`AiTokenBudgetManager`)**: Dynamically manages prompt token counts, context window limits, and safe response generation buffers.

---

## ☁️ Optional Network & Cloud Image Flow

Core clipboard storage never uploads automatically. Cloud image hosting only runs after the user explicitly chooses **Upload to Cloud** for an image:

1. `HistoryController.uploadImageToCloud()` resolves the local image path and current `AppSettings` provider.
2. `CloudUploadService` dispatches to:
   - **FreeImage.host**: `POST multipart/form-data` with file field `source`.
   - **ImgBB API v1**: `POST https://api.imgbb.com/1/upload`, API key in the query, binary file field `image`, and a 32 MB client-side limit.
3. The service validates the provider JSON response and returns only the resulting HTTPS image URL.
4. The URL is written to the system clipboard and stored as a new URL history item.

Provider selection and API keys are stored separately in `AppSettings` and are included in the existing encrypted settings backup. No background or automatic cloud upload is performed.

---

## 🌐 Localization Architecture

- Flutter `gen_l10n` uses `lib/l10n/app_en.arb` as the template and generates strongly typed `AppLocalizations` classes.
- Supported application locales are Vietnamese (`vi`), English (`en`), Japanese (`ja`), Korean (`ko`), German (`de`), and Simplified Chinese (`zh`).
- The Settings language picker is derived from `AppLocalizations.supportedLocales`, preventing translated locales from being hidden by a separate hard-coded allowlist.
- AI response and translation language tags are normalized through `AiLanguageRegistry`, including `zh` / `zh-CN` → `zh-Hans-CN`.

---

## ⚡ Native Platform Integration & Entitlements

### 1. Simulated Auto-Paste Execution
When a user selects an item in the Quick Panel:
- **macOS**:
  1. Updates `NSPasteboard`.
  2. Hides Quick Panel window.
  3. Invokes native Swift MethodChannel (`clipflow/paste`) executing System Events `⌘V` into the active frontmost application.
- **Windows (Beta)**:
  1. Updates Windows Clipboard via `Clipboard.setData()`.
  2. Hides Quick Panel window.
  3. Simulates `Ctrl+V` keypress sequence via Win32 API (`keybd_event` / `SendInput`).

### 2. Global Hotkey & System Tray
- Uses `hotkey_manager` and `tray_manager` to register `Control+V` (`⌃V`) on macOS / `Ctrl+Shift+V` on Windows system-wide, toggling the Quick Panel under the mouse cursor.

### 3. Native Privacy Signals & Capture Exclusion
- **macOS** uses Accessibility roles and focused-window titles to mark password/login/payment contexts, and `NSWindow.sharingType = .none` to exclude ClipFlow from capture when the user enables screen-sharing privacy.
- **Windows** checks focused `ES_PASSWORD` edit controls and window-title keywords, and applies `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)` to the ClipFlow window.
- These native signals are advisory inputs to the repository privacy gate. Each policy remains independently controlled by `AppSettings`, and capture exclusion is restored at startup and immediately after settings import.

---

## 📦 Encrypted Backup & Restore Protocol (`.clipflow`)

ClipFlow exports portable `.clipflow` ZIP archives with two independently protected payloads:
1. `settings.enc` retains the authenticated v1 settings envelope so current archives remain readable by the legacy settings importer.
2. `history.enc` contains non-Vault clipboard rows, embedded image bytes, user Collections, and memberships. It uses AES-256-GCM with a random nonce and a password key derived by PBKDF2-HMAC-SHA256 (210,000 iterations).
3. `manifest.json` records the archive, payload, KDF, and encryption schema versions. The history importer intersects archive fields with live SQLite columns, ignores unknown future fields, supplies defaults for older missing fields, merges Collection names, deduplicates clipboard hashes, and restores images to Application Support storage.
4. Vault rows, Vault membership, device-local wrapped keys, and decrypted Vault files are never exported. A settings-only `clipflow_config_v1` archive remains importable.

---

## 🧪 Developer Build, Test & CI/CD Workflow

### Local Development Setup
1. **Requirements**: Flutter SDK `>=3.11.5`, Xcode 15+ (for macOS), Visual Studio 2022 C++ Workload (for Windows).
2. **Fetch Dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run Code Analysis & Linter**:
   ```bash
   flutter analyze
   ```
4. **Run Unit & Widget Test Suite**:
   ```bash
   flutter test
   ```
5. **Build Release Binaries**:
   ```bash
   # Build macOS App Bundle
   flutter build macos --release

   # Build Windows (Beta) Release
   flutter build windows --release

   # Build unsigned iOS (Beta) app
   flutter build ios --release --no-codesign

   # Build Android (Beta) APK
   flutter build apk --release
   ```

### GitHub Actions CI/CD Pipeline
The project incorporates automated multi-platform release workflows configured in `.github/workflows/`:
- **Triggers**: Pushing a semver release tag (e.g. `v1.0.8`) or triggering release workflows.
- **Pipeline Workflow**: Runs localization verification and tests, then builds macOS (`ClipFlow-macOS.zip`), Windows Beta (`ClipFlow-Windows.zip`), unsigned iOS Beta (`ClipFlow-iOS.ipa`), and Android Beta (`ClipFlow-Android.apk`) artifacts. Release workflows attach the platform artifacts to GitHub Releases; iOS artifacts still require user signing/sideloading.

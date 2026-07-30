# ClipFlow Technical Architecture & Developer Guide 🛠️

Welcome to the technical architecture documentation for **ClipFlow** (Paste Plus). This document provides an in-depth overview of the codebase design, cross-platform architecture (macOS & Windows Beta), data flow, native platform channels, storage engine, local AI engine, and CI/CD pipelines.

---

## 🏛️ System Overview & Design Patterns

ClipFlow is built using **Flutter** and follows a **Feature-First Architecture** combined with **Riverpod** state management. The core guiding principles are:
- **Local-First & Offline**: Zero network dependency for core features. All clipboard records, images, metadata, and user configurations are stored locally on the device.
- **On-Device Local AI Engine**: Integrated with `llamadart` / `llama.cpp` to run local GGUF Large Language Models directly on the user's CPU/GPU without cloud APIs.
- **Unidirectional Data Flow**: State is managed via Riverpod controllers (`StateNotifier` / `Notifier`), ensuring predictable reactivity across UI components.
- **Cross-Platform Desktop Interoperability**: Deep native integration on both **macOS** and **Windows (Beta)**:
  - **macOS**: MethodChannels for global hotkeys, Accessibility permissions (`AXIsProcessTrusted`), AppleScript system events auto-paste, Apple Vision OCR, and System Menu Bar tray.
  - **Windows (Beta)**: Win32 API (`win32` & `win32_registry`), `window_manager`, `tray_manager`, `hotkey_manager`, simulated `keybd_event` / `SendInput` `Ctrl+V` auto-pasting, and SQLite FFI backend.

---

## 📁 Directory & Project Structure

```text
lib/
├── app/                              # Application bootstrap, routing, app-level providers & themes
│   ├── app.dart                      # Root ClipFlowApp widget
│   └── app_router.dart               # Navigation routes (Home, Quick Panel, Onboarding, Settings)
├── core/
│   ├── database/                     # SQLite engine (sqflite on Darwin / sqflite_common_ffi on Windows), migrations, & indexing
│   ├── localization/                 # AppTranslations dictionary & String.tr GetX-style extension
│   ├── platform/                     # Native platform integrations (Hotkey, System Tray, Auto-Paste, Launch-at-Startup)
│   ├── services/                     # Background clipboard monitoring isolate, OCR, Update Service & Backup services
│   ├── theme/                        # Theme system, accent colors (Pastel & Mac palettes), typography
│   └── ui/                           # Shared Cupertino design primitives, dialogs, & toast notifications
├── features/
│   ├── ai/                           # On-device Local AI Domain
│   │   ├── data/                     # Saved AI conversation repository & SQLite tables
│   │   ├── domain/                   # AI Model Info catalog, Request Planner, & Token Budget Manager
│   │   ├── presentation/             # AI Chat Screen, Chat Dialog, Debug Controller, & Model Selector
│   │   └── services/                 # Local AI Engine (llamadart), GGUF Model Downloader, & Relevance Ranker
│   ├── clipboard_history/            # Main Clipboard domain feature
│   │   ├── data/                     # Database repository implementation & query builders
│   │   ├── domain/                   # Content classifier, normalizer, search syntax & retention policies
│   │   └── presentation/             # Quick Panel floating window, Home window, cards & controllers
│   ├── onboarding/                   # Multi-step onboarding experience & retention setup
│   └── settings/                     # User preferences domain
│       ├── domain/                   # AppSettings model & backup serialization
│       └── presentation/             # Tabbed settings screen & exclusion app picker
└── windows/                          # Windows native C++ Runner & Win32 platform code
```

---

## 💾 Storage & Data Management Engine

### 1. Cross-Platform Database Engine (SQLite & SQLite FFI)
ClipFlow dynamically selects the optimal SQLite engine per target platform:
- **macOS / iOS**: Uses `sqflite` with native iOS/Darwin SQLite bindings.
- **Windows / Desktop**: Uses `sqflite_common_ffi` with `sqflite_common_ffi_windows` C FFI binaries.

#### Database Schema (`clipboard_items` & `collections`)
- **`clipboard_items` Table**:
  - `id`: TEXT PRIMARY KEY
  - `content_hash`: TEXT UNIQUE (SHA-256 hash for O(1) deduplication)
  - `content`: TEXT
  - `normalized_content`: TEXT
  - `type`: TEXT (text, url, email, phone, color, json, file, code, image)
  - `image_path`: TEXT (Local relative file path to application support storage)
  - `is_pinned`: INTEGER (0 or 1)
  - `is_sensitive`: INTEGER (0 or 1)
  - `collection_id`: TEXT (FOREIGN KEY -> `collections.id`)
  - `source_app_name`: TEXT (Bundle ID or app executable name)
  - `source_app_identifier`: TEXT
  - `copy_count`: INTEGER
  - `created_at`: INTEGER (Epoch timestamp)
  - `updated_at`: INTEGER
  - `last_copied_at`: INTEGER

- **`collections` Table**:
  - `id`: TEXT PRIMARY KEY
  - `name`: TEXT UNIQUE
  - `color`: TEXT
  - `icon`: TEXT
  - `created_at`: INTEGER

### 2. File & Image Storage Directory
Images copied to the clipboard are written to disk under the sandboxed Application Support directory:
- **macOS**: `/Users/{user}/Library/Application Support/com.clipflow.clipflow/clipboard_images/`
- **Windows (Beta)**: `%LOCALAPPDATA%\clipflow\clipboard_images\`

### 3. Retention & Protection Policy
- **Automatic Purge**: Evaluated on startup and upon new clipboard additions.
- **Protection Priority**:
  1. Pinned items (`is_pinned == 1`) and items inside custom Collections are **never** auto-cleared.
  2. Image items are prioritized for cleanup if storage usage exceeds user thresholds (`maxDatabaseMb`).
  3. Items older than configured `retentionDays` (1, 7, 30, 90, 365, or Unlimited) are purged automatically.

---

## 🤖 On-Device Local AI Architecture

ClipFlow features a 100% local AI assistant powered by GGUF Large Language Models:
1. **Local Inference Engine (`llamadart`)**: Loads `.gguf` quantized models (e.g. Qwen2.5-Coder-1.5B, Gemma-2B, DeepSeek-R1-Distill-Qwen) directly onto the local CPU/GPU using C FFI bindings to `llama.cpp`.
2. **Context-Aware Request Planner (`AiRequestPlanner`)**: Automatically analyzes user prompts and clipboard context to route requests (Conversation, Clipboard Action, Search RAG, or Follow-up).
3. **Automatic Vision & OCR Integration**: When an image is attached as AI context, ClipFlow automatically executes native OCR (Apple Vision on macOS) to extract text and format a rich context block for the model.
4. **Token Budget Manager (`AiTokenBudgetManager`)**: Dynamically manages prompt token counts, context window limits, and safe response generation buffers.

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
- Uses `hotkey_manager` and `tray_manager` to register `⌘ShiftV` (macOS) / `Ctrl+Shift+V` (Windows) system-wide, toggling the Quick Panel under the mouse cursor.

---

## 📦 Encrypted Backup & Restore Protocol (`.clipflow`)

ClipFlow configuration backups are exported as encrypted `.clipflow` archives:
1. Serializes `AppSettings` JSON data (theme, accent color, shortcuts, exclusion lists, content limits).
2. Encrypts payload with user-supplied password using AES-256 / PBKDF2 encryption (`crypto`).
3. Imports and validates password hash prior to applying restored settings.

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
   ```

### GitHub Actions CI/CD Pipeline
The project incorporates automated multi-platform release workflows configured in `.github/workflows/`:
- **Triggers**: Pushing a semver release tag (e.g. `v1.0.8`) or triggering release workflows.
- **Pipeline Workflow**: Runs static analysis (`flutter analyze`), unit test suite (`flutter test`), compiles release binaries for macOS (`ClipFlow-macOS.zip`) and Windows (`ClipFlow-Windows.zip`), and attaches artifacts to GitHub Releases.

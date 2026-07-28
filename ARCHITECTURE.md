# ClipFlow Technical Architecture & Developer Guide 🛠️

Welcome to the technical architecture documentation for **ClipFlow** (Paste Plus). This document provides an in-depth overview of the codebase design, data flow, native platform channels, storage engine, and CI/CD pipelines.

---

## 🏛️ System Overview & Design Patterns

ClipFlow is built using **Flutter** and follows a **Feature-First Architecture** combined with **Riverpod** state management. The core guiding principles are:
- **Local-First & Offline**: Zero network dependency for core features. All clipboard records, images, metadata, and user configurations are stored locally on the device.
- **Unidirectional Data Flow**: State is managed via Riverpod controllers (`StateNotifier` / `Notifier`), ensuring predictable reactivity across UI components.
- **Native macOS Interoperability**: Deep integration with macOS native APIs via MethodChannels for global hotkeys, Accessibility permissions, system tray / menu bar icon, and simulated keypress auto-pasting.

---

## 📁 Directory & Project Structure

```text
lib/
├── app/                              # Application bootstrap, routing, app-level providers & themes
│   ├── app.dart                      # Root ClipFlowApp widget
│   └── app_router.dart               # Navigation routes (Home, Quick Panel, Onboarding, Settings)
├── core/
│   ├── database/                     # SQLite engine, migration scripts, & indexing helpers
│   ├── localization/                 # AppTranslations dictionary & String.tr GetX-style extension
│   ├── platform/                     # Native macOS integrations (Hotkey, Tray, Auto-Paste, Launch-at-Login)
│   ├── services/                     # Background clipboard monitoring isolate, OCR, & Backup services
│   ├── theme/                        # Theme system, accent colors (Pastel & Mac palettes), typography
│   └── ui/                           # Shared Cupertino design primitives, dialogs, & toast notifications
└── features/
    ├── clipboard_history/            # Main Clipboard domain feature
    │   ├── data/                     # Database repository implementation & query builders
    │   ├── domain/                   # Content classifier, normalizer, search syntax & retention policies
    │   └── presentation/             # Quick Panel floating window, Home window, cards & controllers
    ├── onboarding/                   # 5-step onboarding experience & retention setup
    └── settings/                     # User preferences domain
        ├── domain/                   # AppSettings model & backup serialization
        └── presentation/             # Tabbed settings screen & exclusion app picker
```

---

## 💾 Storage & Data Management Engine

### 1. Database Schema & Indexing (SQLite)
ClipFlow uses `sqflite` with SQLite transactions, custom indexes, and automatic schema migrations.

- **`clipboard_history` Table**:
  - `id`: INTEGER PRIMARY KEY AUTOINCREMENT
  - `content_hash`: TEXT UNIQUE (SHA-256 hash for O(1) deduplication)
  - `text_content`: TEXT
  - `type`: TEXT (text, url, email, phone, color, json, file, code, image)
  - `image_path`: TEXT (Local relative file path to application support storage)
  - `is_pinned`: INTEGER (0 or 1)
  - `collection_id`: INTEGER (FOREIGN KEY -> `collections.id`)
  - `source_app`: TEXT (Bundle ID or app name)
  - `usage_count`: INTEGER
  - `created_at`: INTEGER (Epoch timestamp)

- **`collections` Table**:
  - `id`: INTEGER PRIMARY KEY AUTOINCREMENT
  - `name`: TEXT UNIQUE
  - `color`: TEXT
  - `created_at`: INTEGER

### 2. File & Image Storage
Images copied to the clipboard are written to disk under the macOS `Application Support` sandboxed directory (`/Users/{user}/Library/Application Support/com.clipflow.clipflow/images/`). Database records store only relative paths to minimize database file bloat and maximize query performance.

### 3. Retention & Storage Protection Policy
- **Automatic Cleanup**: Evaluated on application startup and history updates.
- **Protection Priority**:
  1. Pinned items (`is_pinned == 1`) and items inside custom Collections are **never** auto-cleared.
  2. Image items are prioritized for cleanup if storage usage exceeds user thresholds (`maxDatabaseMb`).
  3. Items beyond the configured `retentionDays` (1, 7, 30, 90, 365, or Unlimited) are purged automatically.

---

## ⚡ Native macOS Integration & Entitlements

### 1. Simulated Auto-Paste & Accessibility (`AXIsProcessTrusted`)
When a user selects an item in the Quick Panel:
1. ClipFlow updates the system `NSPasteboard` with the selected item.
2. ClipFlow requests window hide / order-out.
3. ClipFlow invokes macOS System Events via native Swift channel to simulate `⌘V` (Command + V) into the previously active application target.

**Entitlements Configuration**:
`DebugProfile.entitlements` and `Release.entitlements` set `com.apple.security.app-sandbox = false` to enable AppleScript / System Events execution and global window focus switching.

### 2. Global Hotkey Registration
Uses native macOS event taps / hotkey monitors to capture `⌘ShiftV` or custom key combinations system-wide, triggering the floating Quick Panel immediately.

---

## 📦 Settings Backup & Restore Protocol (`.clipflow`)

ClipFlow configuration backups are exported as encrypted `.clipflow` archives:
1. Serializes `AppSettings` JSON data (theme, accent color, shortcuts, exclusion lists, content limits).
2. Encrypts payload with user-supplied password using AES-256 / PBKDF2 encryption.
3. Imports and validates password hash prior to applying restored settings.

---

## 🧪 Developer Build, Test & CI/CD Workflow

### Local Development Setup
1. **Requirements**: Flutter SDK `>=3.11.5`, Xcode 15+ (macOS build).
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
5. **Build Release Binary**:
   ```bash
   flutter build macos --release
   ```

### GitHub Actions CI/CD Pipeline
The project incorporates automated macOS releases configured in [.github/workflows/release_macos.yml](file:///.github/workflows/release_macos.yml):
- **Tag Trigger**: Pushing any semver tag (e.g. `v1.0.5`) triggers the automated pipeline.
- **Pipeline Output**: Runs unit tests, compiles `--release` macOS app bundle, packages `ClipFlow-macOS.zip`, and creates a GitHub Release with attached release assets.

<p align="center">
  <img src="assets/branding/clipflow_app_icon.png" width="128" height="128" alt="ClipFlow Logo" />
</p>

<h1 align="center">ClipFlow</h1>

<p align="center">
  <strong>The Ultimate Cross-Platform Clipboard Companion 📋✨</strong><br>
  Never lose a copied text, link, image, or snippet again. Blazing fast, local-first, and beautiful.<br>
  <em>Native support for macOS, Windows (Beta), iOS (Beta), & Android (Beta).</em>
</p>

<p align="center">
  <a href="https://github.com/vqh2602/paste_plus/releases/latest">
    <img src="https://img.shields.io/github/v/release/vqh2602/paste_plus?color=007AFF&style=for-the-badge&logo=github" alt="Latest Release" />
  </a>
  <img src="https://img.shields.io/badge/Platform-macOS-000000?style=for-the-badge&logo=apple" alt="macOS" />
  <img src="https://img.shields.io/badge/Platform-Windows_(Beta)-0078D4?style=for-the-badge&logo=windows" alt="Windows (Beta)" />
  <img src="https://img.shields.io/badge/Platform-iOS_(Beta)-000000?style=for-the-badge&logo=apple" alt="iOS (Beta)" />
  <img src="https://img.shields.io/badge/Platform-Android_(Beta)-3DDC84?style=for-the-badge&logo=android" alt="Android (Beta)" />
  <img src="https://img.shields.io/badge/Built_With-Flutter-02569B?style=for-the-badge&logo=flutter" alt="Flutter" />
  <a href="PRIVACY_POLICY.md">
    <img src="https://img.shields.io/badge/Privacy-100%25_Local--First-34C759?style=for-the-badge&logo=shields" alt="Local First" />
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-FF9500?style=for-the-badge" alt="License" />
  </a>
</p>

---

## 🌟 Why You'll Love ClipFlow

**ClipFlow** turns your clipboard into an intelligent workspace. Built with native desktop aesthetics in mind, ClipFlow lives silently in your System Tray / Menu Bar and pops up instantly whenever you need your history.

### ⚡ Key Selling Points
- 🚀 **Auto-Paste Magic**: Select any history item and ClipFlow automatically pastes (`⌘V` on macOS / `Ctrl+V` on Windows) it straight into your active application.
- 🌐 **Real-time Local Device Sync**: Seamlessly sync clipboard records across your devices over local Wi-Fi / LAN with TLS-encrypted security.
  - **Auto-Sync Pins & Collections**: Automatically synchronizes pinned status and custom category folders (Collections) between devices.
  - **Complete Drain Sync**: Syncs your entire existing clipboard history (including categorized and pinned items) immediately upon device pairing.
  - **Auto-Reconnect (Exponential Backoff)**: Smart background auto-reconnection for trusted devices.
- 🤖 **On-Device Local AI**: Smart AI assistant running 100% locally on your machine (via GGUF models). Analyze images, summarize text, rewrite code, and chat with your clipboard context offline.
- 🔒 **Local-First & Private**: Clipboard history stays on your device with no cloud sync or tracking. Network access only occurs when you explicitly use an online action such as image hosting, translation, update checks, or model downloads.
- 🔐 **Encrypted Vault**: Move private clipboard items into an undeletable system Vault protected by a password or device authentication. Vault database fields and image files are encrypted at rest with AES-256-GCM and excluded from search, AI, retention cleanup, and LAN sync.
- 🎨 **15+ Aesthetic Themes & Pastel Accents**: Express your desktop setup with curated palettes, Emerald Mint, Cyber Violet, Sunset Orange, and Soft Pastel colors.
- 📱 **Mobile Beta**: Responsive `SafeArea` layouts and mobile-friendly navigation for iOS and Android beta builds.
- 🌐 **Six App Languages**: Switch instantly between Vietnamese, English, Japanese, Korean, German, and Simplified Chinese.
- 📦 **Password-Protected Encrypted Backups**: Export and import your entire setup with `.clipflow` encrypted files.
- 🚫 **Smart Exclusion Protection**: Automatically bypass password managers (Bitwarden, 1Password) or exclude specific applications from history recording.

---

## 🔥 Feature Highlights

| Feature | Description |
|---|---|
| **⚡ Floating Quick Panel** | Press `Control+V` (macOS) / `Ctrl+Shift+V` (Windows) anywhere to summon a sleek horizontal paste bar right under your cursor. |
| **🤖 Local AI Assistant** | Ask questions, translate, summarize, or analyze clipboard items using on-device GGUF LLMs without sending data to cloud servers. |
| **🔍 Instant Smart Search** | Filter history instantly with text or syntax like `type:link`, `app:Xcode`, or `is:pinned`. |
| **🔍 OCR & Translate** | Extract text from copied images via native OCR and translate snippets through the selected local-AI or translation workflow. |
| **📑 Content Auto-Classification** | Automatically categorizes Links, Emails, Phone Numbers, Hex Colors, Code Snippets, JSON, Files, & Images. |
| **☁️ Optional Image Hosting** | Explicitly upload an image to FreeImage.host or ImgBB and save the returned URL as a new clipboard item. |
| **🖱️ Drag to Collections** | Drag clipboard cards directly onto a collection with hover highlighting and a named confirmation notice. |
| **🛡️ Sensitive Content Shield** | Ignores OTP verification codes, API keys, and long sensitive tokens automatically. |
| **🔐 Password-Protected Vault** | Hide selected clipboard items behind password, fingerprint/Face ID/Windows Hello or device authentication, with optional wipe after five failed attempts and AES-256-GCM encryption at rest. |
| **📌 Pinning & Custom Collections** | Group frequent prompts, code snippets, or notes into color-coded collections that never expire. |
| **💾 Flexible Retention Control** | Keep history for 1 day, 7 days, 30 days, 1 year, or unlimited with smart image cleanup. |

---

## 🚀 Quick Start & Installation

### Option 1: Download Pre-built Release (Recommended)
1. Head over to [**GitHub Releases**](https://github.com/vqh2602/paste_plus/releases/latest).
2. Download the artifact for your platform: `ClipFlow-macOS.zip`, `ClipFlow-Windows.zip`, `ClipFlow-Android.apk`, or the unsigned `ClipFlow-iOS.ipa` beta payload.
3. **macOS**: Unzip and drag `ClipFlow.app` into your **Applications** folder. Grant Accessibility Permission in *System Settings > Privacy & Security > Accessibility* for Auto-Paste.
4. **Windows (Beta)**: Extract the ZIP archive and run `clipflow.exe`.
5. **Android (Beta)**: Allow installation from the selected source, then install `ClipFlow-Android.apk`.
6. **iOS (Beta)**: The release artifact is unsigned and must be signed/sideloaded with your own Apple development setup before installation.

> **iOS and Android are currently Beta.** GitHub release artifacts and source builds are available, but mobile behavior remains subject to each operating system's clipboard/background-access restrictions. Store packages are not advertised as stable releases yet.

### Option 2: Build From Source

```bash
# Clone repository
git clone https://github.com/vqh2602/paste_plus.git
cd paste_plus

# Install dependencies
flutter pub get

# Run on macOS
flutter run -d macos

# Run on Windows (Beta)
flutter run -d windows

# Run on iOS (Beta, requires macOS + Xcode)
flutter run -d ios

# Run on Android (Beta)
flutter run -d android
```

### Platform Status

| Platform | Status | Notes |
|---|---|---|
| macOS | Stable | Full clipboard watcher, Quick Panel, global shortcuts, auto-paste, OCR, tray, and updater support. |
| Windows | Beta | Native clipboard watcher, Quick Panel, global shortcuts, auto-paste, tray, and updater support. |
| iOS | Beta | Mobile UI and foreground clipboard workflows; behavior remains subject to iOS clipboard/background policies. |
| Android | Beta | Mobile UI and foreground clipboard workflows; behavior remains subject to Android background and vendor restrictions. |

---

## ⌨️ Shortcuts Cheat Sheet

| Action | macOS Shortcut | Windows (Beta) Shortcut |
|---|---|---|
| **Summon Quick Panel** | `Control + V` (`⌃V`) | `Ctrl + Shift + V` |
| **Navigate Snippets** | `↑` `↓` `←` `→` Arrows | `↑` `↓` `←` `→` Arrows |
| **Copy & Auto-Paste** | `Enter` / `Return` | `Enter` |
| **Focus Search Bar** | `⌘ + F` | `Ctrl + F` |
| **Pin / Unpin Snippet** | `⌘ + P` | `Ctrl + P` |
| **Delete Snippet** | `⌘ + Delete` | `Delete` / `Ctrl + D` |
| **Dismiss Panel** | `Esc` | `Esc` |

---

## 🛠️ Developer Architecture & Technical Documentation

Are you a developer, contributor, or curious about how ClipFlow works under the hood?

We maintain complete technical documentation covering multi-platform data flows, SQLite database engines (`sqflite` & `sqflite_common_ffi`), local GGUF AI engines (`llamadart`), native platform channels, Win32 / AppleScript integrations, and CI/CD pipelines in a separate dedicated document:

👉 [**Read Technical Architecture & Developer Guide (`ARCHITECTURE.md`)**](ARCHITECTURE.md)

---

## 📄 License & Privacy Policy

- 📜 **Software License**: Distributed under the **MIT License**. See [**`LICENSE`**](LICENSE) for details.
- 🛡️ **Privacy Policy**: 100% Local-First. Read our full policy in [**`PRIVACY_POLICY.md`**](PRIVACY_POLICY.md).

---

<p align="center">
  Crafted with ❤️ for clipboard power users across desktop and mobile. Star ⭐️ this repo if ClipFlow boosts your daily workflow!
</p>

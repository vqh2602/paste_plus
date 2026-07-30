<p align="center">
  <img src="assets/branding/clipflow_app_icon.png" width="128" height="128" alt="ClipFlow Logo" />
</p>

<h1 align="center">ClipFlow</h1>

<p align="center">
  <strong>The Ultimate Cross-Platform Clipboard Companion 📋✨</strong><br>
  Never lose a copied text, link, image, or snippet again. Blazing fast, local-first, and beautiful.<br>
  <em>Native support for macOS & Windows (Beta).</em>
</p>

<p align="center">
  <a href="https://github.com/vqh2602/paste_plus/releases/latest">
    <img src="https://img.shields.io/github/v/release/vqh2602/paste_plus?color=007AFF&style=for-the-badge&logo=github" alt="Latest Release" />
  </a>
  <img src="https://img.shields.io/badge/Platform-macOS-000000?style=for-the-badge&logo=apple" alt="macOS" />
  <img src="https://img.shields.io/badge/Platform-Windows_(Beta)-0078D4?style=for-the-badge&logo=windows" alt="Windows (Beta)" />
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
- 🤖 **On-Device Local AI**: Smart AI assistant running 100% locally on your machine (via GGUF models). Analyze images, summarize text, rewrite code, and chat with your clipboard context offline.
- 🔒 **100% Offline & Private**: Your clipboard history stays strictly on your device. No cloud sync, no tracking, zero server calls.
- 🎨 **15+ Aesthetic Themes & Pastel Accents**: Express your desktop setup with curated palettes, Emerald Mint, Cyber Violet, Sunset Orange, and Soft Pastel colors.
- 🌐 **Full English & Vietnamese Localization**: Seamlessly switch languages instantly.
- 📦 **Password-Protected Encrypted Backups**: Export and import your entire setup with `.clipflow` encrypted files.
- 🚫 **Smart Exclusion Protection**: Automatically bypass password managers (Bitwarden, 1Password) or exclude specific applications from history recording.

---

## 🔥 Feature Highlights

| Feature | Description |
|---|---|
| **⚡ Floating Quick Panel** | Press `⌘ShiftV` (macOS) / `Ctrl+Shift+V` (Windows) anywhere to summon a sleek horizontal paste bar right under your cursor. |
| **🤖 Local AI Assistant** | Ask questions, translate, summarize, or analyze clipboard items using on-device GGUF LLMs without sending data to cloud servers. |
| **🔍 Instant Smart Search** | Filter history instantly with text or syntax like `type:link`, `app:Xcode`, or `is:pinned`. |
| **🔍 On-Device OCR & Translate** | Extract text from copied images via native OCR and translate snippets in one click. |
| **📑 Content Auto-Classification** | Automatically categorizes Links, Emails, Phone Numbers, Hex Colors, Code Snippets, JSON, Files, & Images. |
| **🛡️ Sensitive Content Shield** | Ignores OTP verification codes, API keys, and long sensitive tokens automatically. |
| **📌 Pinning & Custom Collections** | Group frequent prompts, code snippets, or notes into color-coded collections that never expire. |
| **💾 Flexible Retention Control** | Keep history for 1 day, 7 days, 30 days, 1 year, or unlimited with smart image cleanup. |

---

## 🚀 Quick Start & Installation

### Option 1: Download Pre-built Release (Recommended)
1. Head over to [**GitHub Releases**](https://github.com/vqh2602/paste_plus/releases/latest).
2. Download `ClipFlow-macOS.zip` for macOS or `ClipFlow-Windows.zip` for Windows (Beta).
3. **macOS**: Unzip and drag `ClipFlow.app` into your **Applications** folder. Grant Accessibility Permission in *System Settings > Privacy & Security > Accessibility* for Auto-Paste.
4. **Windows (Beta)**: Extract the ZIP archive and run `clipflow.exe`.

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
```

---

## ⌨️ Shortcuts Cheat Sheet

| Action | macOS Shortcut | Windows (Beta) Shortcut |
|---|---|---|
| **Summon Quick Panel** | `⌘ + Shift + V` | `Ctrl + Shift + V` |
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
  Crafted with ❤️ for macOS & Windows power users. Star ⭐️ this repo if ClipFlow boosts your daily workflow!
</p>

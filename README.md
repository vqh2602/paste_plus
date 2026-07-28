<p align="center">
  <img src="assets/branding/clipflow_app_icon.png" width="128" height="128" alt="ClipFlow Logo" />
</p>

<h1 align="center">ClipFlow</h1>

<p align="center">
  <strong>The Ultimate macOS Clipboard Companion 📋✨</strong><br>
  Never lose a copied text, link, image, or snippet again. Blazing fast, local-first, and beautiful.
</p>

<p align="center">
  <a href="https://github.com/vqh2602/paste_plus/releases/latest">
    <img src="https://img.shields.io/github/v/release/vqh2602/paste_plus?color=007AFF&style=for-the-badge&logo=apple" alt="Latest Release" />
  </a>
  <img src="https://img.shields.io/badge/Platform-macOS-000000?style=for-the-badge&logo=apple" alt="macOS" />
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

**ClipFlow** turns your clipboard into an intelligent workspace. Built exclusively with native macOS aesthetics in mind, ClipFlow lives silently in your Menu Bar and pops up instantly whenever you need your history.

### ⚡ Key Selling Points
- 🚀 **Auto-Paste Magic**: Select any history item and ClipFlow automatically pastes (`⌘V`) it straight into your active application.
- 🔒 **100% Offline & Private**: Your clipboard history stays strictly on your device. No cloud sync, no tracking, zero server calls.
- 🎨 **15+ Aesthetic Themes & Pastel Accents**: Express your desk setup with curated macOS palettes, Emerald Mint, Cyber Violet, Sunset Orange, and Soft Pastel colors.
- 🌐 **Full English & Vietnamese Localization**: Seamlessly switch languages instantly.
- 📦 **Password-Protected Encrypted Backups**: Export and import your entire setup with `.clipflow` encrypted files.
- 🚫 **Smart Exclusion Protection**: Automatically bypass password managers (Bitwarden, 1Password) or exclude specific applications from history recording.

---

## 🔥 Feature Highlights

| Feature | Description |
|---|---|
| **⚡ Floating Quick Panel** | Press `⌘ShiftV` anywhere to summon a sleek horizontal paste bar right under your cursor. |
| **🔍 Instant Smart Search** | Filter history instantly with text or syntax like `type:link`, `app:Xcode`, or `is:pinned`. |
| **🔍 On-Device OCR & Translate** | Extract text from copied images via local OCR and translate snippets in one click. |
| **📑 Content Auto-Classification** | Automatically categorizes Links, Emails, Phone Numbers, Hex Colors, Code Snippets, JSON, Files, & Images. |
| **🛡️ Sensitive Content Shield** | Ignores OTP verification codes, API keys, and long sensitive tokens automatically. |
| **📌 Pinning & Custom Collections** | Group frequent prompts, code snippets, or notes into color-coded collections that never expire. |
| **💾 Flexible Retention Control** | Keep history for 1 day, 7 days, 30 days, 1 year, or unlimited with smart image cleanup. |

---

## 🚀 Quick Start & Installation

### Option 1: Download Pre-built Release (Recommended)
1. Head over to [**GitHub Releases**](https://github.com/vqh2602/paste_plus/releases/latest) and download `ClipFlow-macOS.zip`.
2. Unzip and drag `ClipFlow.app` into your **Applications** folder.
3. Open **ClipFlow** and grant **Accessibility Permission** in *System Settings > Privacy & Security > Accessibility* to enable Auto-Paste.

### Option 2: Build From Source
```bash
# Clone repository
git clone https://github.com/vqh2602/paste_plus.git
cd paste_plus

# Install dependencies & run on macOS
flutter pub get
flutter run -d macos
```

---

## ⌨️ Shortcuts Cheat Sheet

| Action | Global / App Shortcut |
|---|---|
| **Summon Quick Panel** | `⌘ + Shift + V` (Customizable) |
| **Navigate Snippets** | `↑` `↓` `←` `→` Arrows |
| **Copy & Auto-Paste** | `Enter` / `Return` |
| **Focus Search Bar** | `⌘ + F` |
| **Pin / Unpin Snippet** | `⌘ + P` |
| **Delete Snippet** | `⌘ + Delete` |
| **Dismiss Panel** | `Esc` |

---

## 🛠️ Developer Architecture & Technical Documentation

Are you a developer, contributor, or curious about how ClipFlow works under the hood?

We maintain complete technical documentation covering data flow, SQLite database schemas, native Swift channels, AppleScript entitlements, and GitHub Actions CI/CD pipelines in a separate dedicated document:

👉 [**Read Technical Architecture & Developer Guide (`ARCHITECTURE.md`)**](ARCHITECTURE.md)

---

## 📄 License & Privacy Policy

- 📜 **Software License**: Distributed under the **MIT License**. See [**`LICENSE`**](LICENSE) for details.
- 🛡️ **Privacy Policy**: 100% Local-First. Read our full policy in [**`PRIVACY_POLICY.md`**](PRIVACY_POLICY.md).

---

<p align="center">
  Crafted with ❤️ for macOS power users. Star ⭐️ this repo if ClipFlow boosts your daily workflow!
</p>

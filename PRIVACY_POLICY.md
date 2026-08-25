# Privacy Policy for ClipFlow 🛡️

**Effective Date:** July 28, 2026  
**Last Updated:** August 25, 2026

---

## 1. Overview & Our Local-First Commitment

At **ClipFlow**, your privacy is our absolute priority. ClipFlow is designed as a **100% Local-First application** for macOS. 

We believe your clipboard contains some of your most sensitive information—passwords, personal messages, code snippets, financial figures, and private links. Therefore, ClipFlow is built from the ground up to ensure that **your data stays strictly on your device and never leaves it.**

---

## 2. Information We Collect (Zero Remote Data Collection)

- **No Remote Storage**: We do not own, operate, or maintain any cloud servers to store your clipboard history.
- **No Analytics / No Telemetry**: ClipFlow contains no tracking codes, analytics SDKs (such as Google Analytics, Firebase, or Mixpanel), or crash reporting software that sends telemetry over the internet.
- **No User Account Requirement**: You do not need to register, log in, or provide any personal information (such as email or name) to use ClipFlow.

---

## 3. How Your Data Is Stored & Protected

- **Local SQLite Database**: Copied items (text, images, links, snippets, colors, and file paths) are stored exclusively in the app's local sandbox/application-data directory. Normal history is not represented as end-to-end encrypted SQLite content.
- **Optional Encrypted Vault**: Items you explicitly move into the Vault have sensitive database fields and managed image files encrypted at rest with AES-256-GCM. The master key is protected by your password and may optionally be released after OS device authentication. Vault items are excluded from search, local AI, retention cleanup, and LAN synchronization.
- **Encrypted Backups**: If you choose to export your clipboard history using ClipFlow's backup feature (`.clipflow` files), the export is protected with password-based encryption (AES) specified by you.
- **Sensitive Content Shielding**: ClipFlow automatically ignores copying events from password managers (e.g., Bitwarden, 1Password, Keychain) and offers configurable filters to automatically ignore OTP codes, API keys, and long sensitive tokens.
- **Excluded Applications**: You can configure custom application exclusion rules in Settings to prevent ClipFlow from recording clipboard activity from specific apps.

---

## 4. Third-Party Integrations & Network Usage

- **Software Updates**: ClipFlow provides an opt-in update check mechanism that queries the public GitHub Releases API (`https://api.github.com/repos/vqh2602/paste_plus/releases`) to determine if a newer version of ClipFlow is available. No user data or clipboard content is transmitted during update checks.
- **On-Device Processing**: Features like Optical Character Recognition (OCR) and text analysis are performed entirely on-device using local system APIs (macOS Vision framework).
- **Explicit Online Actions**: Image hosting, online translation, update checks, and model downloads may contact their displayed providers only after the related feature is enabled or invoked. Uploading to FreeImage.host or ImgBB sends the selected image to that provider.
- **Optional LAN Sharing**: If local device sharing is enabled, non-Vault clipboard items may be transferred to trusted paired devices over an encrypted TLS connection on the local network. Vault items are never included.

---

## 5. User Control & Data Retention

You have total control over your data at all times:
- **Auto-Cleanup Rules**: You can set clipboard history retention limits (e.g., 1 day, 7 days, 30 days, 1 year, or unlimited).
- **Manual Deletion**: You can delete individual clipboard items, clear specific collections, or purge the entire database instantly at any time via **Settings > Storage > Clear History**.
- **Complete Uninstallation**: Uninstalling ClipFlow and deleting its application support folder permanently removes all stored data from your device.

---

## 6. Contact & Open-Source Transparency

ClipFlow is open-source. You can audit our codebase, data handling, and architecture at any time on GitHub:
👉 [https://github.com/vqh2602/paste_plus](https://github.com/vqh2602/paste_plus)

If you have any questions or feedback regarding this Privacy Policy, please open an issue on our GitHub repository.

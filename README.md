# FreeMacDroid

[![Release](https://img.shields.io/github/v/release/abolfazl-moeini/FreeMacDroid?style=flat-square)](https://github.com/abolfazl-moeini/FreeMacDroid/releases/latest)
[![Platform](https://img.shields.io/badge/macOS-15%2B%20(Apple%20Silicon%20%26%20Intel)-blue?style=flat-square)](https://github.com/abolfazl-moeini/FreeMacDroid/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![Upstream PR](https://img.shields.io/badge/Upstream%20Fix-whoozle%2Faft--linux%20%23369-orange?style=flat-square)](https://github.com/whoozle/android-file-transfer-linux/pull/369)

**Mount any Android phone directly inside macOS Finder over USB — free, open-source, one click, and with USB debugging OFF.**

No paid MacDroid subscription. No ADB / USB debugging required. No kernel extensions, no Recovery Mode, and no lowered macOS security.

---

## How It Compares

| Feature | **FreeMacDroid** | MacDroid | OpenMTP | Android File Transfer |
| :--- | :---: | :---: | :---: | :---: |
| **Mounts in Finder** | Yes | Yes | No (separate app) | No (separate app) |
| **Price** | Free & Open Source | Paid ($20+/yr) | Free | Discontinued |
| **USB Debugging (ADB) Off** | Yes | Yes | Yes | Yes |
| **No Kernel Extensions (FSKit)** | Yes | Proprietary | N/A | N/A |
| **Apple Silicon & Sequoia+** | Native | Yes | Yes | Broken / Legacy |

---

## Why FreeMacDroid Exists
- Existing open-source Android tools on macOS either use a separate window (don't mount in Finder) or require enabling Developer Options + USB debugging (ADB).
- Paid tools like MacDroid mount in Finder, while Homebrew's `android-file-transfer-linux` disables FUSE (`-DBUILD_FUSE=OFF`).
- Under macFUSE 5.x's user-space **FSKit backend** (`-o backend=fskit`), upstream `aft-mtp-mount` fails with `Input/output error` on reads >= 128 KiB (`cp`, `cat`, Finder) due to `fuse_reply_buf()` vs FSKit's reply buffer.
- **FreeMacDroid** bundles a patched `aft-mtp-mount` (with our [upstream `fuse_reply_data()` fix](https://github.com/whoozle/android-file-transfer-linux/pull/369)) inside a native Swift/AppKit menu-bar & Dock app for effortless one-click mounting.

---

## Quick Install

### Option A: Download Release DMG (Fastest)
1. Install **macFUSE** if you don't already have it:
   ```bash
   brew install --cask macfuse
   ```
2. Download **[FreeMacDroid.dmg](https://github.com/abolfazl-moeini/FreeMacDroid/releases/latest/download/FreeMacDroid.dmg)** from [Releases](https://github.com/abolfazl-moeini/FreeMacDroid/releases/latest) and drag **FreeMacDroid.app** to **Applications**.
3. Open FreeMacDroid and click **Register Extensions** in the menu bar (or follow the 1-minute setup below).

### Option B: Build & Install from Source
```bash
git clone https://github.com/abolfazl-moeini/FreeMacDroid.git
cd FreeMacDroid
./install.sh
```
This installs `macFUSE` (if needed), builds `aft-mtp-mount` with the FSKit patch, compiles `FreeMacDroid.app` into `~/Applications/FreeMacDroid.app`, and registers the FSKit extensions.

---

## One-Time macOS Setup (1 Minute)
1. Open **System Settings → General → Login Items & Extensions**.
2. Scroll to **By Category** *(do **not** use "By App" — macOS has a known bug `macfuse#1194` where "By App" toggles silently fail)*, click the **`i`** button next to **File System Extensions**, and turn **ON** both:
   - **macFUSE**
   - **macFUSE (local)**
3. If you also have MacDroid or Google's Android File Transfer installed, turn off their Login Items and set **Image Capture → "Connecting this device opens:" → No application** (FreeMacDroid also cleanly releases them on mount without ever touching `adb`).

---

## Usage (One Click)
1. Plug your Android phone in with a **USB data cable**, unlock the screen, tap the USB notification, and pick **File transfer / MTP** (on Samsung: **Transferring files**). Leave **USB debugging OFF**.
2. Click **FreeMacDroid.app** (Dock or Menu Bar). It mounts the phone at `~/Android` and opens it in **Finder**.
3. Before unplugging, click **Eject / Unmount Phone** in the FreeMacDroid menu bar (or Finder's Eject icon).

CLI equivalents are also available:
```bash
android-mount               # Mount and open Finder
android-mount --read-only   # Mount read-only
android-unmount             # Cleanly unmount
```

---

## Upstream PR Patch
The FSKit large-read fix lives cleanly at:
- [patches/0001-fuse-use-fuse_reply_data-for-macfuse-fskit.patch](patches/0001-fuse-use-fuse_reply_data-for-macfuse-fskit.patch)
- Upstream PR: [whoozle/android-file-transfer-linux#369](https://github.com/whoozle/android-file-transfer-linux/pull/369)

Tested on macOS (arm64) + macFUSE 5.5.0 with 81.8 MB reads and 20 MB write/remount/read SHA-256 round-trip verification.

---

## Development & Tests
```bash
./tests/test_unit_mount_scripts.sh   # Mocked unit tests (no phone required)
./scripts/build-app.sh               # Build FreeMacDroid.app
./tests/test_build_bundle.sh         # Verify bundle, codesign, and libfuse3 linkage
./scripts/package-dmg.sh             # Create dist/FreeMacDroid.dmg
```

---

## راهنمای سریع فارسی

**FreeMacDroid** گوشی اندرویدی شما را با **یک کلیک** و **بدون نیاز به فعال‌سازی USB Debugging** و **بدون پرداخت هزینه** مستقیماً داخل **Finder** باز می‌کند:

1. **نصب:** فایل `FreeMacDroid.dmg` را از بخش [Releases](https://github.com/abolfazl-moeini/FreeMacDroid/releases/latest) دانلود کرده و به Applications منتقل کنید (پیش‌نیاز: `brew install --cask macfuse`)، یا پروژه را کلون کرده و `./install.sh` را اجرا کنید.
2. **تنظیم یک‌باره‌ی macOS:** در **System Settings → General → Login Items & Extensions**، در بخش **By Category** (نه By App) روی آیکون `i` کنار **File System Extensions** بزنید و هر دو گزینه‌ی **macFUSE** و **macFUSE (local)** را روشن کنید.
3. **اتصال:** قفل گوشی را باز کنید، در نوار اعلان‌ها گزینه‌ی **Transferring files / File transfer (MTP)** را بزنید و روی **FreeMacDroid** کلیک کنید تا حافظه‌ی گوشی در Finder باز شود.

---

## License
- FreeMacDroid app, CLI scripts, and build tooling: **MIT** (`LICENSE`).
- Bundled `aft-mtp-mount` / `aft-mtp-cli`: **LGPL-2.1-or-later** (`THIRD_PARTY_NOTICES.md`).
- Runtime dependency `macFUSE`: separate third-party package (`macfuse.github.io`).

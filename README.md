# FreeMacDroid

[![Release](https://img.shields.io/github/v/release/abolfazl-moeini/FreeMacDroid?style=flat-square)](https://github.com/abolfazl-moeini/FreeMacDroid/releases/latest)
[![Platform](https://img.shields.io/badge/macOS-15%2B%20(Apple%20Silicon%20%26%20Intel)-blue?style=flat-square)](https://github.com/abolfazl-moeini/FreeMacDroid/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![Upstream PR #369](https://img.shields.io/badge/Upstream%20PR%20%23369-Merged-brightgreen?style=flat-square)](https://github.com/whoozle/android-file-transfer-linux/pull/369)
[![Upstream PRs](https://img.shields.io/badge/Upstream%20PRs-MoveObject%20%26%20Darwin%20USB-blue?style=flat-square)](https://github.com/whoozle/android-file-transfer-linux/pulls)

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

## Upstream Contributions & Patches

1. **macFUSE FSKit Large Read Fix (PR #369 - Merged):**
   - Merged upstream in commit [`0310eb97`](https://github.com/whoozle/android-file-transfer-linux/commit/0310eb978a8d3e01b7f091b9f3d8bc0cc4ff9206). Switched large reads from `fuse_reply_buf()` to `fuse_reply_data()` to support FSKit user-space architecture.

2. **Native MTP MoveObject & FUSE Performance ([PR #370](https://github.com/whoozle/android-file-transfer-linux/pull/370) · [`patches/0001-mtp-fuse-native-move-and-perf.patch`](patches/0001-mtp-fuse-native-move-and-perf.patch)):**
   - Wires up standard MTP `MoveObject` (`0x1019`) inside `Session::MoveObject` and `FuseWrapper::Rename`. Moving files between directories on the phone now happens instantaneously inside the device without copying bytes back and forth over USB (**145x speedup**, e.g., 30 MB move dropped from 13.56s to 0.093s).
   - In-memory parent inode mapping (`_parentMap`), root storage lookup cache, and 5-second `StatFS` cache to eliminate redundant USB round-trips under macOS FSKit.
   - Fixed `.` entry in `ReadDir()` returning `Root` instead of the directory's actual inode.
   - Caches `st_mode` attributes in `Open()` instead of querying USB.
   - Write buffering (512 KiB) with `ops.flush` and sequential read-ahead (256 KiB).
   - Safe USB disconnect error handling in `WRAP_EX` and `~ObjectEditSession()` preventing `std::terminate` crashes.

3. **Darwin USB Backend Performance & Timeouts ([PR #371](https://github.com/whoozle/android-file-transfer-linux/pull/371) · [`patches/0002-darwin-usb-bulk-buffer-and-timeouts.patch`](patches/0002-darwin-usb-bulk-buffer-and-timeouts.patch)):**
   - Upgraded bulk transfer buffer size from 512 bytes (`wMaxPacketSize`) to **256 KiB**, cutting IOKit syscall overhead by 512x.
   - Implemented `ReadPipeTO` / `WritePipeTO` with proper timeouts and mapped `kIOUSBTransactionTimeout` to `TimeoutException` so an unplugged or locked phone never hangs Finder indefinitely.
   - Implemented `Device::WriteControl` with `DeviceRequestTO`.

---

## What's New in v0.2.0
- **Instant In-Phone Move/Cut**: Cut and paste files between folders in Finder instantly without downloading and re-uploading over USB.
- **512x Fewer USB Syscalls**: 256 KiB bulk USB buffers dramatically improve sustained transfer rates.
- **Write Buffering & Read-Ahead**: Smooth sequential file operations and immediate error reporting via `flush`.
- **Automatic Disconnect Recovery**: Menu bar app detects USB cable disconnection (`kIOTerminatedNotification`) and automatically unmounts stale mount points.
- **Debug Logging Mode**: Added `--debug` CLI option and Menu Bar toggle for instant diagnostics.
- **macOS Finder Optimization**: Default `noapplexattr` mount option eliminates Apple extended attribute chatter over USB.

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

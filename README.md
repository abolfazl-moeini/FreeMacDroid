# FreeMacDroid

**Mount any Android phone directly inside macOS Finder over USB — free, open-source, one click, and with USB debugging OFF.**

No paid MacDroid subscription. No ADB / USB debugging required. No kernel extensions, no Recovery Mode, and no lowered macOS security.

---

## Why FreeMacDroid Exists
- Existing open-source Android tools on macOS either use a separate window (don't mount in Finder) or require enabling Developer Options + USB debugging (ADB).
- Paid tools like MacDroid mount in Finder, while Homebrew's `android-file-transfer-linux` disables FUSE (`-DBUILD_FUSE=OFF`).
- Under macFUSE 5.x's user-space **FSKit backend** (`-o backend=fskit`), upstream `aft-mtp-mount` also fails with `Input/output error` on reads >= 128 KiB (`cp`, `cat`, Finder) due to `fuse_reply_buf()` vs FSKit's reply buffer.
- **FreeMacDroid** bundles a patched `aft-mtp-mount` (with our upstream-ready `fuse_reply_data()` fix) inside a native Swift/AppKit menu-bar & Dock app for effortless one-click mounting.

---

## Quick Install

### Option A: Homebrew (Recommended once tap is published)
```bash
brew install --cask --no-quarantine abolfazl-moeini/tap/freemacdroid
```
*(Automatically installs `macfuse` and links `android-mount` / `android-unmount`.)*

### Option B: One-Command Source Install (Works right now)
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

CLI equivalents are also installed:
```bash
android-mount               # Mount and open Finder
android-mount --read-only   # Mount read-only
android-unmount             # Cleanly unmount
```

---

## Upstream PR Patch
The FSKit large-read fix lives cleanly at:
- [patches/0001-fuse-use-fuse_reply_data-for-macfuse-fskit.patch](patches/0001-fuse-use-fuse_reply_data-for-macfuse-fskit.patch)

Tested on macOS 27.2.1 (arm64) + macFUSE 5.5.0 with 81.8 MB reads and 20 MB write/remount/read SHA-256 round-trip verification.

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

1. **نصب:** از طریق دستور `./install.sh` (پس از دانلود پروژه) یا از طریق Homebrew نصب کنید.
2. **تنظیم یک‌باره‌ی macOS:** در **System Settings → General → Login Items & Extensions**، در بخش **By Category** (نه By App) روی آیکون `i` کنار **File System Extensions** بزنید و هر دو گزینه‌ی **macFUSE** و **macFUSE (local)** را روشن کنید.
3. **اتصال:** قفل گوشی را باز کنید، در نوار اعلان‌ها گزینه‌ی **Transferring files / File transfer (MTP)** را بزنید و روی **FreeMacDroid** کلیک کنید تا حافظه‌ی گوشی در Finder باز شود.

---

## License
- FreeMacDroid app, CLI scripts, and build tooling: **MIT** (`LICENSE`).
- Bundled `aft-mtp-mount` / `aft-mtp-cli`: **LGPL-2.1-or-later** (`THIRD_PARTY_NOTICES.md`).
- Runtime dependency `macFUSE`: separate third-party package (`macfuse.github.io`).

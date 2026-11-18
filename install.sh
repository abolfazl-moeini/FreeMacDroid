#!/bin/bash
# Simple one-step installer for FreeMacDroid from source.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DEST="${APP_DEST:-$HOME/Applications/FreeMacDroid.app}"
BIN_DEST="${BIN_DEST:-$HOME/.local/bin}"

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOMEBREW_NO_AUTO_UPDATE=1

echo "==> Checking prerequisites..."
if ! command -v brew >/dev/null 2>&1; then
    echo "Error: Homebrew is required. Install it from https://brew.sh" >&2
    exit 1
fi

if [ ! -d "/Library/Filesystems/macfuse.fs" ]; then
    echo "==> Installing macFUSE (macOS admin password required)..."
    brew install --cask macfuse
fi

if ! command -v cmake >/dev/null 2>&1 || ! command -v pkg-config >/dev/null 2>&1; then
    echo "==> Installing cmake, pkg-config, readline..."
    brew install cmake pkg-config readline
fi

echo "==> Building FreeMacDroid.app..."
"$ROOT_DIR/scripts/build-app.sh"

echo "==> Installing FreeMacDroid.app to $APP_DEST..."
mkdir -p "$(dirname "$APP_DEST")" "$BIN_DEST"
rm -rf "$APP_DEST"
cp -R "$ROOT_DIR/.build/FreeMacDroid.app" "$APP_DEST"

ln -sf "$APP_DEST/Contents/Helpers/android-mount" "$BIN_DEST/android-mount"
ln -sf "$APP_DEST/Contents/Helpers/android-unmount" "$BIN_DEST/android-unmount"
ln -sf "$APP_DEST/Contents/Helpers/aft-mtp-mount" "$BIN_DEST/aft-mtp-mount"
ln -sf "$APP_DEST/Contents/Helpers/aft-mtp-cli" "$BIN_DEST/aft-mtp-cli"

MACFUSE_BIN="/Library/Filesystems/macfuse.fs/Contents/Resources/macfuse.app/Contents/MacOS/macfuse"
if [ -x "$MACFUSE_BIN" ]; then
    "$MACFUSE_BIN" install --components file-system-extensions || true
fi

echo ""
echo "FreeMacDroid installed successfully!"
echo "  App: $APP_DEST"
echo "  CLI: $BIN_DEST/android-mount , $BIN_DEST/android-unmount"
echo ""
echo "Next (one-time):"
echo "  1. Open System Settings -> General -> Login Items & Extensions -> By Category -> File System Extensions (i)"
echo "     and turn ON both 'macFUSE' and 'macFUSE (local)'."
echo "  2. Connect your Android phone, unlock it, choose 'File transfer / MTP' (USB debugging OFF)."
echo "  3. Launch FreeMacDroid.app!"

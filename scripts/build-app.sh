#!/bin/bash
# Compile FreeMacDroid.app and bundle patched aft-mtp-mount + CLI helpers.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
AFT_PREFIX="${AFT_PREFIX_DIR:-$BUILD_DIR/aft-prefix}"
APP_DIR="${APP_OUT_DIR:-$BUILD_DIR/FreeMacDroid.app}"

if [ ! -x "$AFT_PREFIX/bin/aft-mtp-mount" ] || [ ! -x "$AFT_PREFIX/bin/aft-mtp-cli" ]; then
    "$ROOT_DIR/scripts/build-aft.sh"
fi

rm -rf "$APP_DIR"
mkdir -p \
    "$APP_DIR/Contents/MacOS" \
    "$APP_DIR/Contents/Helpers" \
    "$APP_DIR/Contents/Resources"

swiftc \
    -O \
    -swift-version 6 \
    -framework AppKit \
    -framework IOKit \
    "$ROOT_DIR/src/FreeMacDroid/MTPService.swift" \
    "$ROOT_DIR/src/FreeMacDroid/USBMonitor.swift" \
    "$ROOT_DIR/src/FreeMacDroid/SetupWizardWindow.swift" \
    "$ROOT_DIR/src/FreeMacDroid/AppDelegate.swift" \
    "$ROOT_DIR/src/FreeMacDroid/main.swift" \
    -o "$APP_DIR/Contents/MacOS/FreeMacDroid"

cp "$AFT_PREFIX/bin/aft-mtp-mount" "$APP_DIR/Contents/Helpers/aft-mtp-mount"
cp "$AFT_PREFIX/bin/aft-mtp-cli" "$APP_DIR/Contents/Helpers/aft-mtp-cli"
cp "$ROOT_DIR/bin/android-mount" "$APP_DIR/Contents/Helpers/android-mount"
cp "$ROOT_DIR/bin/android-unmount" "$APP_DIR/Contents/Helpers/android-unmount"
chmod +x "$APP_DIR/Contents/Helpers/"*

cp "$ROOT_DIR/src/FreeMacDroid/Info.plist" "$APP_DIR/Contents/Info.plist"

ICON_SRC="$BUILD_DIR/aft-src/osx/android-file-transfer.icns"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$APP_DIR/Contents/Resources/AppIcon.icns"
else
    echo "Warning: icon not found at $ICON_SRC" >&2
fi

codesign --force --deep --sign - "$APP_DIR"
echo "Built $APP_DIR"

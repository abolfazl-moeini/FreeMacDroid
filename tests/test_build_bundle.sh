#!/bin/bash
# Build & verify FreeMacDroid.app bundle structure, Info.plist, signature, and dylib linkage.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/.build/FreeMacDroid.app"

if [ ! -x "$ROOT_DIR/scripts/build-app.sh" ]; then
    echo "FAIL [RED]: scripts/build-app.sh missing or not executable" >&2
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "FAIL [RED]: $APP_PATH does not exist yet" >&2
    exit 1
fi

for f in \
    "$APP_PATH/Contents/MacOS/FreeMacDroid" \
    "$APP_PATH/Contents/Helpers/aft-mtp-mount" \
    "$APP_PATH/Contents/Helpers/aft-mtp-cli" \
    "$APP_PATH/Contents/Helpers/android-mount" \
    "$APP_PATH/Contents/Helpers/android-unmount"
do
    if [ ! -x "$f" ]; then
        echo "FAIL [RED]: missing or non-executable bundle item: $f" >&2
        exit 1
    fi
done

for f in \
    "$APP_PATH/Contents/Info.plist" \
    "$APP_PATH/Contents/Resources/AppIcon.icns"
do
    if [ ! -f "$f" ]; then
        echo "FAIL [RED]: missing bundle resource: $f" >&2
        exit 1
    fi
done

plutil -lint "$APP_PATH/Contents/Info.plist" >/dev/null
codesign --verify --deep --strict "$APP_PATH"

OTOOL_OUT="$(otool -L "$APP_PATH/Contents/Helpers/aft-mtp-mount")"
if ! echo "$OTOOL_OUT" | grep -iq "fuse3"; then
    echo "FAIL [RED]: bundled aft-mtp-mount not linked against libfuse3" >&2
    exit 1
fi
if echo "$OTOOL_OUT" | grep -iq "not found"; then
    echo "FAIL [RED]: bundled aft-mtp-mount has unresolved dylibs" >&2
    exit 1
fi

echo "PASS [GREEN]: FreeMacDroid.app bundle verified cleanly"

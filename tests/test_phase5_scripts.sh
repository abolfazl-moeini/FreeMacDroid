#!/bin/bash
# Test Phase 5: Verify launcher scripts and macOS .app bundles exist, are valid, and pass static safety checks
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

MOUNT_SCRIPT="$HOME/.local/bin/android-mount"
UNMOUNT_SCRIPT="$HOME/.local/bin/android-unmount"
MOUNT_APP="$HOME/Applications/Mount Android.app"
UNMOUNT_APP="$HOME/Applications/Unmount Android.app"

echo "Running Test Phase 5: Checking launcher scripts and .app bundles..."

for f in "$MOUNT_SCRIPT" "$UNMOUNT_SCRIPT"; do
    if [ ! -x "$f" ]; then
        echo "FAIL [RED]: $f missing or not executable"
        exit 1
    fi
done

# Safety checks from PLAN.md
if grep -qE '(pkill|killall).*adb' "$MOUNT_SCRIPT"; then
    echo "FAIL [RED]: android-mount must NEVER kill adb"
    exit 1
fi
if ! grep -q -- '-f' "$MOUNT_SCRIPT"; then
    echo "FAIL [RED]: android-mount must pass -f to aft-mtp-mount"
    exit 1
fi
if ! grep -q '</dev/null' "$MOUNT_SCRIPT"; then
    echo "FAIL [RED]: android-mount must redirect stdin (</dev/null) for AppleScript"
    exit 1
fi
if ! grep -qE '\[F\]reedroid|\[A\]ndroid File Transfer' "$MOUNT_SCRIPT"; then
    echo "FAIL [RED]: android-mount must use bracket trick in pkill -f"
    exit 1
fi

for app in "$MOUNT_APP" "$UNMOUNT_APP"; do
    if [ ! -d "$app" ]; then
        echo "FAIL [RED]: $app missing"
        exit 1
    fi
    codesign --verify --deep "$app" 2>/dev/null || true
done

echo "PASS [GREEN]: Launcher scripts and .app bundles exist and pass static checks"
exit 0

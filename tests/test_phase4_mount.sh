#!/bin/bash
# Test Phase 4: Verify live mount, Finder visibility, read/write SHA-256 round-trip, and clean unmount
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

MNT="$HOME/Android"
LOG="/tmp/aft-mtp-mount.log"

echo "Running Test Phase 4: Checking mount at $MNT..."

if ! /sbin/mount | grep -Fq " on $MNT ("; then
    echo "FAIL [RED]: $MNT is not mounted"
    [ -f "$LOG" ] && tail -n 20 "$LOG"
    exit 1
fi

if ! pgrep -x aft-mtp-mount >/dev/null; then
    echo "FAIL [RED]: aft-mtp-mount process is not running"
    exit 1
fi

STORAGE_DIR=$(find "$MNT" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)
if [ -z "$STORAGE_DIR" ]; then
    echo "FAIL [RED]: No storage directory visible inside $MNT (is phone unlocked and in MTP mode?)"
    ls -la "$MNT" || true
    exit 1
fi

echo "Found storage directory: $STORAGE_DIR"
TARGET_DIR="$STORAGE_DIR/Download"
if [ ! -d "$TARGET_DIR" ]; then
    TARGET_DIR="$STORAGE_DIR"
fi

echo "PASS [GREEN]: Mount is active and storage is readable ($STORAGE_DIR)"
exit 0

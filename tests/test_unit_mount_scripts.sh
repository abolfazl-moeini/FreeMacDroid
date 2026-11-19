#!/bin/bash
# Unit tests for bin/android-mount and bin/android-unmount (mocked OS commands; CI-safe).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MOUNT_BIN="$ROOT_DIR/bin/android-mount"
UNMOUNT_BIN="$ROOT_DIR/bin/android-unmount"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

MOCK_BIN="$TMP_ROOT/mockbin"
mkdir -p "$MOCK_BIN"
CALL_LOG="$TMP_ROOT/calls.log"
MNT_DIR="$TMP_ROOT/Android"
LOG_FILE="$TMP_ROOT/aft.log"
STATE_FILE="$TMP_ROOT/mounted"
PROC_FILE="$TMP_ROOT/proc_alive"

# Create mock aft-mtp-mount
cat > "$MOCK_BIN/aft-mtp-mount" << 'EOF'
#!/bin/bash
echo "aft-mtp-mount $*" >> "$TEST_CALL_LOG"
if [ "${TEST_MTP_FAIL:-}" = "locked" ]; then
  echo "your device may be locked or does not have any storage available"
  exit 1
fi
if [ "${TEST_MTP_FAIL:-}" = "nodev" ]; then
  echo "connect failed: no MTP device found"
  exit 1
fi
touch "$TEST_STATE_FILE"
touch "$TEST_PROC_FILE"
# Stay alive briefly until killed or test ends
sleep 5 &
wait $! 2>/dev/null || true
EOF
chmod +x "$MOCK_BIN/aft-mtp-mount"

# Create mock system commands
cat > "$MOCK_BIN/mount" << 'EOF'
#!/bin/bash
if [ -f "$TEST_STATE_FILE" ]; then
  echo "/dev/disk99 on $TEST_MNT_DIR (macfuse, local, fskit)"
fi
EOF
cat > "$MOCK_BIN/pgrep" << 'EOF'
#!/bin/bash
if [ "$*" = "-x aft-mtp-mount" ] && [ -f "$TEST_PROC_FILE" ]; then
  echo "99999"
  exit 0
fi
exit 1
EOF
cat > "$MOCK_BIN/pkill" << 'EOF'
#!/bin/bash
echo "pkill $*" >> "$TEST_CALL_LOG"
if [ "$*" = "-x aft-mtp-mount" ]; then
  rm -f "$TEST_PROC_FILE"
fi
exit 0
EOF
cat > "$MOCK_BIN/open" << 'EOF'
#!/bin/bash
echo "open $*" >> "$TEST_CALL_LOG"
EOF
cat > "$MOCK_BIN/diskutil" << 'EOF'
#!/bin/bash
echo "diskutil $*" >> "$TEST_CALL_LOG"
if [ "${TEST_DISKUTIL_FAIL:-0}" = "1" ]; then
  exit 1
fi
rm -f "$TEST_STATE_FILE"
EOF
cat > "$MOCK_BIN/umount" << 'EOF'
#!/bin/bash
echo "umount $*" >> "$TEST_CALL_LOG"
rm -f "$TEST_STATE_FILE"
EOF
chmod +x "$MOCK_BIN"/*

export TEST_CALL_LOG="$CALL_LOG"
export TEST_STATE_FILE="$STATE_FILE"
export TEST_PROC_FILE="$PROC_FILE"
export TEST_MNT_DIR="$MNT_DIR"
export AFT_MTP_MOUNT_BIN="$MOCK_BIN/aft-mtp-mount"
export ANDROID_MOUNT_DIR="$MNT_DIR"
export ANDROID_MOUNT_LOG="$LOG_FILE"
export FREEMACDROID_SYSBIN="$MOCK_BIN"

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if ! grep -Fq -- "$needle" "$haystack"; then
    echo "FAIL: $msg (missing '$needle')" >&2
    cat "$haystack" >&2
    exit 1
  fi
}

# Test 1: --help
if [ ! -x "$MOUNT_BIN" ] || [ ! -x "$UNMOUNT_BIN" ]; then
  echo "FAIL [RED]: bin/android-mount or bin/android-unmount missing/not executable" >&2
  exit 1
fi
"$MOUNT_BIN" --help >/dev/null

# Test 2: Fresh mount + Finder open + no adb kill
: > "$CALL_LOG"; rm -f "$STATE_FILE" "$PROC_FILE"
"$MOUNT_BIN"
assert_contains "$CALL_LOG" "aft-mtp-mount -f -o backend=fskit,volname=Android,local,noappledouble,noapplexattr $MNT_DIR" "mount options"
assert_contains "$CALL_LOG" "open $MNT_DIR" "open Finder"
if grep -q "adb" "$CALL_LOG"; then
  echo "FAIL: must never kill adb" >&2; exit 1
fi

# Test 3: Already mounted idempotency
: > "$CALL_LOG"
"$MOUNT_BIN"
if grep -q "aft-mtp-mount" "$CALL_LOG"; then
  echo "FAIL: should not spawn aft-mtp-mount when already mounted" >&2; exit 1
fi
assert_contains "$CALL_LOG" "open $MNT_DIR" "re-open Finder when mounted"

# Test 4: Stale mount cleanup + --no-open + --read-only
: > "$CALL_LOG"; touch "$STATE_FILE"; rm -f "$PROC_FILE"
"$MOUNT_BIN" --no-open --read-only
assert_contains "$CALL_LOG" "diskutil unmount force $MNT_DIR" "stale unmount"
assert_contains "$CALL_LOG" "aft-mtp-mount -f -o backend=fskit,volname=Android,local,noappledouble,noapplexattr,ro $MNT_DIR" "read-only flag"
if grep -q "open " "$CALL_LOG"; then
  echo "FAIL: --no-open must not invoke open" >&2; exit 1
fi

# Test 5: Unmount fallback to umount -f when diskutil fails
: > "$CALL_LOG"; touch "$STATE_FILE"
TEST_DISKUTIL_FAIL=1 "$UNMOUNT_BIN"
assert_contains "$CALL_LOG" "umount -f $MNT_DIR" "umount -f fallback"

# Test 6: Locked phone error
: > "$CALL_LOG"; rm -f "$STATE_FILE" "$PROC_FILE"
if TEST_MTP_FAIL=locked "$MOUNT_BIN" --no-open 2>"$TMP_ROOT/err.txt"; then
  echo "FAIL: locked phone must return non-zero" >&2; exit 1
fi
assert_contains "$TMP_ROOT/err.txt" "locked" "locked phone diagnostic"

# Test 7: Debug mode passes -d to aft-mtp-mount
: > "$CALL_LOG"; rm -f "$STATE_FILE" "$PROC_FILE"
"$MOUNT_BIN" --no-open --debug
assert_contains "$CALL_LOG" "aft-mtp-mount -f -d -o backend=fskit,volname=Android,local,noappledouble,noapplexattr $MNT_DIR" "debug flag"

# Test 8: Symlinked mount point resolves real target in mount & unmount
SYM_TARGET="$TMP_ROOT/RealAndroid"
SYM_MNT="$TMP_ROOT/SymlinkAndroid"
mkdir -p "$SYM_TARGET"
ln -s "$SYM_TARGET" "$SYM_MNT"
REAL_SYM_TARGET="$(cd "$SYM_TARGET" && pwd -P)"
: > "$CALL_LOG"; rm -f "$STATE_FILE" "$PROC_FILE"
TEST_MNT_DIR="$REAL_SYM_TARGET" ANDROID_MOUNT_DIR="$SYM_MNT" "$MOUNT_BIN" --no-open
assert_contains "$CALL_LOG" "aft-mtp-mount -f -o backend=fskit,volname=Android,local,noappledouble,noapplexattr $REAL_SYM_TARGET" "symlink mount target"
: > "$CALL_LOG"
TEST_MNT_DIR="$REAL_SYM_TARGET" ANDROID_MOUNT_DIR="$SYM_MNT" "$UNMOUNT_BIN"
assert_contains "$CALL_LOG" "diskutil unmount $REAL_SYM_TARGET" "symlink unmount target"

echo "PASS [GREEN]: All unit tests for bin/android-mount and bin/android-unmount passed"

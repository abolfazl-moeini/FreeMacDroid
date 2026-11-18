#!/bin/bash
# Test Phase 3: Check build artifacts, dynamic library linkage, and raw MTP connectivity
set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

echo "Running Test Phase 3: Checking aft-mtp-mount and aft-mtp-cli..."

AFT_MOUNT="$HOME/.local/bin/aft-mtp-mount"
AFT_CLI="$HOME/.local/bin/aft-mtp-cli"

if [ ! -x "$AFT_MOUNT" ]; then
    echo "FAIL [RED]: $AFT_MOUNT not found or not executable"
    exit 1
fi

if [ ! -x "$AFT_CLI" ]; then
    echo "FAIL [RED]: $AFT_CLI not found or not executable"
    exit 1
fi

HELP_OUT=$("$AFT_MOUNT" --help 2>&1 || true)
if ! echo "$HELP_OUT" | grep -q "Additional AFT options"; then
    echo "FAIL [RED]: aft-mtp-mount --help did not output expected options"
    exit 1
fi

OTOOL_OUT=$(otool -L "$AFT_MOUNT" 2>&1 || true)
if ! echo "$OTOOL_OUT" | grep -i -q "fuse3"; then
    echo "FAIL [RED]: aft-mtp-mount is not linked against libfuse3"
    exit 1
fi
if echo "$OTOOL_OUT" | grep -i -q "not found"; then
    echo "FAIL [RED]: aft-mtp-mount has unresolved library dependencies:"
    echo "$OTOOL_OUT"
    exit 1
fi

echo "PASS [GREEN]: binaries built and linked cleanly against libfuse3"

echo "Checking raw MTP connectivity with aft-mtp-cli..."
MTP_LS=$(printf 'ls\nquit\n' | "$AFT_CLI" -b 2>&1) || {
    echo "FAIL [RED]: aft-mtp-cli failed:"
    echo "$MTP_LS"
    exit 1
}
echo "$MTP_LS"
if echo "$MTP_LS" | grep -i -q -E "no MTP device found|device not found|connect failed|busy|claim|access denied"; then
    echo "FAIL [RED]: MTP connection error"
    exit 1
fi

echo "PASS [GREEN]: MTP communication verified"
exit 0

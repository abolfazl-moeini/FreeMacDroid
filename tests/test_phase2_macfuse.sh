#!/bin/bash
# Test Phase 2: Check macFUSE installation and fuse3 pkg-config availability
set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

echo "Running Test Phase 2: Checking macFUSE and fuse3.pc..."

MACFUSE_FS=$(ls /Library/Filesystems 2>/dev/null | grep -i macfuse || true)
if [ -z "$MACFUSE_FS" ]; then
    echo "FAIL [RED]: macFUSE not found in /Library/Filesystems"
    exit 1
fi

FUSE3_PC=$(find /usr/local /Library/Filesystems -name 'fuse3.pc' 2>/dev/null | head -n 1 || true)
if [ -z "$FUSE3_PC" ]; then
    echo "FAIL [RED]: fuse3.pc not found in /usr/local or /Library/Filesystems"
    exit 1
fi

export PKG_CONFIG_PATH="$(dirname "$FUSE3_PC"):${PKG_CONFIG_PATH:-}"
FUSE3_VER=$(pkg-config --modversion fuse3 2>/dev/null || true)
case "$FUSE3_VER" in
    3.*) ;;
    *)
        echo "FAIL [RED]: expected fuse3 version 3.x, got '${FUSE3_VER:-none}'"
        exit 1
        ;;
esac

echo "PASS [GREEN]: macFUSE found ($MACFUSE_FS), fuse3.pc at $FUSE3_PC (version $FUSE3_VER)"

FS_MODS=$(pluginkit -m -p com.apple.fskit.fsmodule 2>/dev/null | grep -i macfuse || true)
if ! echo "$FS_MODS" | grep -q "io.macfuse.app.fsmodule.macfuse-local" || ! echo "$FS_MODS" | grep -q "io.macfuse.app.fsmodule.macfuse"; then
    echo "FAIL [RED]: macFUSE FSKit modules not registered in pluginkit"
    exit 1
fi
echo "PASS [GREEN]: macFUSE FSKit modules registered:"
echo "$FS_MODS"
exit 0

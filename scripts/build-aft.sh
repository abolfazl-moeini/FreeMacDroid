#!/bin/bash
# Reproducibly clone, patch, and build aft-mtp-mount and aft-mtp-cli (LGPL-2.1-or-later).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AFT_COMMIT="${AFT_COMMIT:-0310eb978a8d3e01b7f091b9f3d8bc0cc4ff9206}"
AFT_REPO="${AFT_REPO:-https://github.com/whoozle/android-file-transfer-linux.git}"
SRC_DIR="${AFT_SRC_DIR:-$ROOT_DIR/.build/aft-src}"
PREFIX_DIR="${AFT_PREFIX_DIR:-$ROOT_DIR/.build/aft-prefix}"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

if [ -z "${PKG_CONFIG_PATH:-}" ]; then
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"
else
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
fi

if ! pkg-config --exists fuse3; then
    FUSE3_PC="$(find /usr/local /Library/Filesystems /opt/homebrew -name 'fuse3.pc' 2>/dev/null | head -n 1 || true)"
    if [ -n "$FUSE3_PC" ]; then
        export PKG_CONFIG_PATH="$(dirname "$FUSE3_PC"):$PKG_CONFIG_PATH"
    fi
fi

if ! pkg-config --exists fuse3; then
    echo "Error: fuse3 pkg-config metadata not found. Install macFUSE >= 5.5 first." >&2
    exit 1
fi

mkdir -p "$(dirname "$SRC_DIR")" "$PREFIX_DIR"

if [ ! -d "$SRC_DIR/.git" ]; then
    git clone --depth 1 "$AFT_REPO" "$SRC_DIR"
fi

cd "$SRC_DIR"
CURRENT_HEAD="$(git rev-parse HEAD)"
if [ "$CURRENT_HEAD" != "$AFT_COMMIT" ]; then
    git fetch --depth 1 origin "$AFT_COMMIT"
    git checkout --force "$AFT_COMMIT"
fi

git reset --hard "$AFT_COMMIT"
git clean -fd

if [ -d "$ROOT_DIR/patches" ]; then
    for patch_file in "$ROOT_DIR"/patches/*.patch; do
        [ -f "$patch_file" ] || continue
        echo "Applying $(basename "$patch_file")..."
        git apply "$patch_file"
    done
fi

READLINE_PREFIX=""
if command -v brew >/dev/null 2>&1; then
    READLINE_PREFIX="$(brew --prefix readline 2>/dev/null || true)"
fi

CMAKE_ARGS=(
    -S "$SRC_DIR"
    -B "$SRC_DIR/build"
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_FUSE=ON
    -DBUILD_QT_UI=OFF
    -DBUILD_MTPZ=OFF
    -DBUILD_PYTHON=OFF
    -DBUILD_TAGLIB=OFF
    -DBUILD_SHARED_LIB=OFF
    -DCMAKE_INSTALL_PREFIX="$PREFIX_DIR"
)
if [ -n "$READLINE_PREFIX" ]; then
    CMAKE_ARGS+=("-DCMAKE_PREFIX_PATH=$READLINE_PREFIX")
fi

rm -rf "$SRC_DIR/build"
cmake "${CMAKE_ARGS[@]}"
cmake --build "$SRC_DIR/build" -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
cmake --install "$SRC_DIR/build"

echo "Built aft-mtp-mount & aft-mtp-cli into $PREFIX_DIR/bin"

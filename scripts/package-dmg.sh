#!/bin/bash
# Package FreeMacDroid.app into a drag-and-drop macOS .dmg installer.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$ROOT_DIR/.build/dmg-staging"
APP_DIR="$ROOT_DIR/.build/FreeMacDroid.app"
DMG_PATH="$DIST_DIR/FreeMacDroid.dmg"

"$ROOT_DIR/scripts/build-app.sh"

mkdir -p "$DIST_DIR"
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

cp -R "$APP_DIR" "$STAGING_DIR/FreeMacDroid.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "FreeMacDroid" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING_DIR"
echo "Created $DMG_PATH"

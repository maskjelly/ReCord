#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/ReCord.app"
DMG_PATH="$ROOT_DIR/dist/ReCord.dmg"
STAGING_DIR="$ROOT_DIR/dist/dmg-staging"

if [ ! -d "$APP_PATH" ]; then
    "$ROOT_DIR/scripts/build_release_app.sh"
fi

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "ReCord" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING_DIR"
echo "$DMG_PATH"

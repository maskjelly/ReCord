#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: scripts/notarize_dmg.sh <notarytool-keychain-profile>" >&2
    exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$1"
DMG_PATH="$ROOT_DIR/dist/ReCord.dmg"

if [ ! -f "$DMG_PATH" ]; then
    "$ROOT_DIR/scripts/package_dmg.sh"
fi

xcrun notarytool submit "$DMG_PATH" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH"

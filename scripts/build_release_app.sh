#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ReCord"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

cd "$ROOT_DIR"
swift build -c release --disable-sandbox

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Config/Info.plist" "$CONTENTS_DIR/Info.plist"

if [ -d "$ROOT_DIR/Sources/ReCord/Resources" ]; then
    cp -R "$ROOT_DIR/Sources/ReCord/Resources/." "$RESOURCES_DIR/" 2>/dev/null || true
fi

if [ -f "$ROOT_DIR/Sources/ReCord/Resources/AppIcon.icns" ]; then
    cp "$ROOT_DIR/Sources/ReCord/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

cat > "$CONTENTS_DIR/PkgInfo" <<'PKGINFO'
APPL????
PKGINFO

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER:-1}" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${APP_VERSION:-0.1.0}" "$CONTENTS_DIR/Info.plist"

codesign --force --deep --options runtime --entitlements "$ROOT_DIR/Config/ReCord.entitlements" --sign "$SIGN_IDENTITY" "$APP_DIR"

echo "$APP_DIR"

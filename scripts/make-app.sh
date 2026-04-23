#!/usr/bin/env bash
# Build VoiceSnippet.app — a proper macOS app bundle with icon, ad-hoc signed.
#
# Usage:
#   ./scripts/make-app.sh           # builds into dist/VoiceSnippet.app
#   ./scripts/make-app.sh install   # also copies to /Applications
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="VoiceSnippet"
DISPLAY_NAME="Voice Snippet"
DIST_DIR="dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"

echo "==> swift build -c release"
swift build -c release

echo "==> generating AppIcon.icns"
mkdir -p "$DIST_DIR"
swift scripts/gen-icon.swift "$DIST_DIR/AppIcon.icns" >/dev/null

echo "==> assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp ".build/release/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp Info.plist "$APP_DIR/Contents/Info.plist"
cp "$DIST_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

# Ensure Info.plist points at the icon.
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP_DIR/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_DIR/Contents/Info.plist"

echo "==> ad-hoc code signing"
codesign --force --deep --sign - --entitlements VoiceSnippet.entitlements "$APP_DIR"

echo "==> done: $APP_DIR"

if [[ "${1:-}" == "install" ]]; then
    echo "==> installing to /Applications"
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_DIR" "/Applications/$APP_NAME.app"
    echo "==> installed: /Applications/$APP_NAME.app"
fi

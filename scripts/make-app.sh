#!/usr/bin/env bash
# Build VoiceSnippet.app — a proper macOS app bundle with icon.
#
# Signs with Developer ID Application if available (for distribution outside
# the App Store), otherwise falls back to ad-hoc signing (local use only).
#
# Usage:
#   ./scripts/make-app.sh           # builds into dist/VoiceSnippet.app
#   ./scripts/make-app.sh install   # also copies to /Applications
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="VoiceSnippet"
DIST_DIR="dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"

# Developer ID identity for distribution. Override via env var if needed.
DEV_ID_IDENTITY="${DEV_ID_IDENTITY:-Developer ID Application: AnalystAI INC. (884G6Q7X9V)}"

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

/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP_DIR/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_DIR/Contents/Info.plist"

# Pick signing identity: Developer ID if present, else ad-hoc.
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$DEV_ID_IDENTITY"; then
    echo "==> signing with: $DEV_ID_IDENTITY"
    codesign --force --deep \
        --sign "$DEV_ID_IDENTITY" \
        --options runtime \
        --timestamp \
        --entitlements VoiceSnippet.entitlements \
        "$APP_DIR"
    SIGNED_FOR_DISTRIBUTION=1
else
    echo "==> Developer ID not found, signing ad-hoc (local use only)"
    codesign --force --deep --sign - \
        --entitlements VoiceSnippet.entitlements "$APP_DIR"
    SIGNED_FOR_DISTRIBUTION=0
fi

echo "==> done: $APP_DIR"
if [[ "$SIGNED_FOR_DISTRIBUTION" == "1" ]]; then
    echo "    Next: ./scripts/notarize.sh   (to notarize for distribution)"
fi

if [[ "${1:-}" == "install" ]]; then
    echo "==> installing to /Applications"
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_DIR" "/Applications/$APP_NAME.app"
    echo "==> installed: /Applications/$APP_NAME.app"
fi

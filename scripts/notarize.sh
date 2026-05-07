#!/usr/bin/env bash
# Notarize VoiceSnippet.app with Apple, then staple the ticket so it works
# offline. Requires the app to already be Developer ID signed (run make-app.sh
# first) and a notarytool keychain profile named "voicesnippet-notary".
#
# One-time setup (run this once, then forget). Apple ID is the AnalystAI INC
# account on developer.apple.com. App-specific password is generated at
# appleid.apple.com → Sign-In and Security → App-Specific Passwords.
#   xcrun notarytool store-credentials voicesnippet-notary \
#       --apple-id hello@analystai.ai \
#       --team-id 884G6Q7X9V \
#       --password YOUR-APP-SPECIFIC-PASSWORD
#
# Then:
#   ./scripts/notarize.sh
set -euo pipefail

cd "$(dirname "$0")/.."

APP_DIR="dist/VoiceSnippet.app"
ZIP_PATH="dist/VoiceSnippet-notarize.zip"
PROFILE="${NOTARY_PROFILE:-voicesnippet-notary}"

if [[ ! -d "$APP_DIR" ]]; then
    echo "error: $APP_DIR not found. Run ./scripts/make-app.sh first." >&2
    exit 1
fi

if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
    echo "error: notarytool profile '$PROFILE' not found in keychain." >&2
    echo "Run the store-credentials command shown at the top of this script." >&2
    exit 1
fi

echo "==> zipping app for submission"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "==> submitting to Apple notary service (this can take a few minutes)"
xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$PROFILE" \
    --wait

echo "==> stapling notarization ticket to app"
xcrun stapler staple "$APP_DIR"

echo "==> verifying"
xcrun stapler validate "$APP_DIR"
spctl --assess --type execute --verbose=2 "$APP_DIR"

rm -f "$ZIP_PATH"
echo "==> notarized + stapled: $APP_DIR"

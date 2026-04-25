#!/usr/bin/env bash
# One-shot setup for Voice Snippet.
#
# Voice Snippet is a self-contained native Mac app:
#   - Speech-to-text: WhisperKit (distil-whisper-large-v3, on-device, Swift)
#   - Formatter:      Apple Foundation Models (on-device, requires macOS 26+)
#
# By default this script downloads a pre-built VoiceSnippet.app from GitHub
# Releases, so end-users don't need the Swift toolchain. If the download
# fails, it falls back to building from source (Xcode CLT required).
#
# Run from the repo root:
#   ./scripts/setup.sh
set -euo pipefail

cd "$(dirname "$0")/.."

log() { printf "\n\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!! %s\033[0m\n" "$*"; }

REPO="Vietnam-VoDich/voice-snippet"
DIST_APP="dist/VoiceSnippet.app"

# ── Preflight ────────────────────────────────────────────────────────────────
if [[ "$(uname -m)" != "arm64" ]]; then
    warn "Voice Snippet requires Apple Silicon (M1/M2/M3/M4). You're on $(uname -m). Aborting."
    exit 1
fi

macos_major=$(sw_vers -productVersion | cut -d. -f1)
if (( macos_major < 26 )); then
    warn "Voice Snippet uses Apple Foundation Models, which requires macOS 26 or later. You're on $(sw_vers -productVersion). Aborting."
    exit 1
fi

# ── Get the .app: try prebuilt download, fall back to source ─────────────────
download_prebuilt() {
    log "Downloading pre-built VoiceSnippet.app from GitHub Releases"
    mkdir -p dist
    LATEST_URL="https://github.com/$REPO/releases/latest/download/VoiceSnippet.app.tar.gz"
    if curl -fSL --progress-bar "$LATEST_URL" -o /tmp/VoiceSnippet.app.tar.gz; then
        tar -xzf /tmp/VoiceSnippet.app.tar.gz -C dist/
        rm -f /tmp/VoiceSnippet.app.tar.gz
        return 0
    fi
    return 1
}

build_from_source() {
    log "Building VoiceSnippet.app from source (requires Swift toolchain)"
    if ! command -v swift >/dev/null 2>&1; then
        warn "Swift not found. Install Xcode Command Line Tools: xcode-select --install"
        return 1
    fi
    ./scripts/make-app.sh
}

if ! download_prebuilt; then
    warn "Could not download pre-built app. Trying to build from source..."
    build_from_source
fi

# ── Next steps ───────────────────────────────────────────────────────────────
cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Setup complete.

Next steps:

  1. Make sure Apple Intelligence is on:
       System Settings → Apple Intelligence & Siri → toggle on.
     The Foundation Models formatter (Clean / Bullets / Email / etc.) needs it.

  2. Launch the app:
       open dist/VoiceSnippet.app

  3. First launch: macOS will say "developer cannot be verified".
     Right-click VoiceSnippet.app in Finder → Open → Open.
     You only need to do this once.

  4. First recording downloads the speech model (~1.5 GB) into
     ~/Library/Application Support/argmaxinc.WhisperKit/. Subsequent
     recordings transcribe in seconds.

Want it in /Applications?   ./scripts/make-app.sh install
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

#!/usr/bin/env bash
# One-shot setup for Voice Snippet.
#
# Voice Snippet is a self-contained native Mac app:
#   - Speech-to-text: WhisperKit (distil-whisper-large-v3, on-device, Swift)
#   - Formatter:      Apple Foundation Models (on-device, requires macOS 26+)
#
# This script just preflights the environment and builds the .app.
# No Python, no Ollama, no second terminal.
#
# Run from the repo root:
#   ./scripts/setup.sh
set -euo pipefail

cd "$(dirname "$0")/.."

log() { printf "\n\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!! %s\033[0m\n" "$*"; }

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

if ! command -v swift >/dev/null 2>&1; then
    warn "Swift toolchain missing. Run: xcode-select --install"
    exit 1
fi

# ── Build the Swift app ──────────────────────────────────────────────────────
log "Building VoiceSnippet.app"
./scripts/make-app.sh

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

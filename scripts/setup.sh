#!/usr/bin/env bash
# One-shot setup for Voice Snippet.
#
# Installs Ollama (if missing), pulls the formatter model, sets up the Python
# backend venv, builds the Swift app, and packages it as VoiceSnippet.app.
#
# Run from the repo root:
#   ./scripts/setup.sh
set -euo pipefail

cd "$(dirname "$0")/.."

log() { printf "\n\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!! %s\033[0m\n" "$*"; }

# ── 1. Check we're on Apple Silicon ───────────────────────────────────────────
if [[ "$(uname -m)" != "arm64" ]]; then
    warn "This app requires Apple Silicon (M1/M2/M3/M4). You're on $(uname -m). Aborting."
    exit 1
fi

# ── 2. Ollama ─────────────────────────────────────────────────────────────────
log "Checking Ollama"
if ! command -v ollama >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        log "Installing Ollama via Homebrew"
        brew install ollama
    else
        warn "Ollama not installed and Homebrew is missing. Install Homebrew from https://brew.sh, then re-run this script."
        exit 1
    fi
fi

# Start ollama serve if nothing is listening on 11434
if ! lsof -iTCP:11434 -sTCP:LISTEN >/dev/null 2>&1; then
    log "Starting 'ollama serve' in the background"
    nohup ollama serve >/tmp/ollama.log 2>&1 &
    disown
    sleep 2
fi

log "Pulling gemma3:1b formatter model (~750 MB, skips if already present)"
ollama pull gemma3:1b

log "Setting OLLAMA_KEEP_ALIVE=30m so models stay resident"
launchctl setenv OLLAMA_KEEP_ALIVE 30m || true

# ── 3. Python backend venv ────────────────────────────────────────────────────
log "Creating Python venv at .venv"
if [[ ! -d .venv ]]; then
    python3 -m venv .venv
fi
./.venv/bin/pip install -q --upgrade pip
log "Installing backend requirements (may take a minute)"
./.venv/bin/pip install -q -r backend/requirements.txt

# ── 4. Build and package the Swift app ────────────────────────────────────────
log "Building VoiceSnippet.app"
./scripts/make-app.sh

# ── 5. Next steps ─────────────────────────────────────────────────────────────
cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Setup complete.

Next steps:

  1. Start the backend (leave this terminal open):
       source .venv/bin/activate
       python backend/app.py

  2. In another terminal, launch the app:
       open dist/VoiceSnippet.app

  3. First launch: macOS will say "developer cannot be verified".
     Right-click VoiceSnippet.app in Finder → Open → Open.
     You only need to do this once.

Want it in /Applications?   ./scripts/make-app.sh install
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

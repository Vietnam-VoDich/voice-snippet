# AGENTS.md — setup guide for coding agents

This file tells an AI coding agent (Claude Code, Codex, Cursor, Aider, etc.) how to set up Voice Snippet on a user's Mac from a fresh clone. Each step has a **verify** command with expected output — do not proceed until the check passes.

> **If you are a human:** use [README.md](README.md). This file is written for non-interactive agent execution.

---

## 0. What you are setting up

Three independent processes that must all be running for the app to work:

1. **Ollama** on `127.0.0.1:11434` — runs the `gemma3:1b` formatter model
2. **Backend** (FastAPI) on `127.0.0.1:8003` — wraps mlx-whisper + Ollama
3. **VoiceSnippet.app** — the Swift/SwiftUI menubar app

Everything is local. No cloud, no API keys, no network egress outside `127.0.0.1`.

---

## 1. Preflight

Run these checks first. Abort with a clear message to the user if any fail.

```bash
# Must be Apple Silicon — mlx-whisper is Apple-Silicon-only
uname -m                              # expect: arm64

# Must be macOS 13 or later
sw_vers -productVersion               # expect: 13.* or higher

# Must have ~10 GB free
df -h ~ | awk 'NR==2 {print $4}'      # expect: 10G+ free

# Must have Homebrew (for Ollama install)
command -v brew                       # expect: path printed

# Must have Python 3.10+
python3 --version                     # expect: 3.10+

# Must have Swift toolchain (bundled with Xcode / Command Line Tools)
swift --version                       # expect: Swift version printed
```

If `brew` is missing, instruct the user to install Homebrew from `https://brew.sh` and re-run you. Do not attempt to install Homebrew yourself.

If `swift` is missing, tell the user to run `xcode-select --install` and re-run you.

---

## 2. Fast path (recommended)

From the repo root:

```bash
./scripts/setup.sh
```

This script is idempotent — safe to re-run. It will:
- Install Ollama via Homebrew (if missing)
- Start `ollama serve` in the background (if not already running)
- Pull `gemma3:1b` (~750 MB, skipped if present)
- Set `OLLAMA_KEEP_ALIVE=30m` via `launchctl`
- Create `.venv/` and install backend requirements
- Build `VoiceSnippet` in release mode and package it as `dist/VoiceSnippet.app`

**Verify it succeeded:**

```bash
test -d .venv                         # backend venv exists
test -d dist/VoiceSnippet.app         # app bundle exists
curl -s http://127.0.0.1:11434/api/tags | grep -q gemma3:1b   # model pulled
```

If all three pass, skip to [§4 Launch](#4-launch).

If `setup.sh` fails, fall through to the manual steps and diagnose.

---

## 3. Manual path (if §2 fails)

### 3a. Ollama

```bash
# Install
command -v ollama || brew install ollama

# Start server (idempotent — skip if port 11434 is already listening)
lsof -iTCP:11434 -sTCP:LISTEN >/dev/null 2>&1 \
  || (nohup ollama serve >/tmp/ollama.log 2>&1 & disown)
sleep 2

# Pull model
ollama pull gemma3:1b

# Keep resident to avoid cold starts
launchctl setenv OLLAMA_KEEP_ALIVE 30m

# Verify
curl -s http://127.0.0.1:11434/api/tags | grep -q gemma3:1b && echo OK
```

### 3b. Backend

```bash
# From repo root
python3 -m venv .venv
./.venv/bin/pip install --upgrade pip
./.venv/bin/pip install -r backend/requirements.txt

# Start backend (will block the terminal — run in background for agent flows)
nohup ./.venv/bin/python backend/app.py >/tmp/voice-snippet-backend.log 2>&1 &
disown
sleep 3

# Verify
curl -s http://127.0.0.1:8003/health  # expect: {"ok":true,...}
```

First call to `/transcribe` will download the Whisper model (`mlx-community/distil-whisper-large-v3`, ~1.5 GB) to `~/.cache/huggingface/`. Warn the user this takes ~30 seconds on first recording only.

### 3c. Swift app

**Preferred: download pre-built app (no Swift toolchain needed):**

```bash
mkdir -p dist
curl -fSL https://github.com/Vietnam-VoDich/voice-snippet/releases/latest/download/VoiceSnippet.app.tar.gz \
  -o /tmp/VoiceSnippet.app.tar.gz
tar -xzf /tmp/VoiceSnippet.app.tar.gz -C dist/
rm -f /tmp/VoiceSnippet.app.tar.gz
test -d dist/VoiceSnippet.app && echo OK
```

**Fallback: build from source (requires Xcode Command Line Tools):**

```bash
./scripts/make-app.sh                 # builds dist/VoiceSnippet.app
```

This step requires the Swift toolchain (`xcode-select --install` if missing). Output goes to `.build/release/VoiceSnippet` and is packaged into `dist/VoiceSnippet.app` with an ad-hoc codesign.

> **Common issue:** If `swift build` fails with "SDK is not supported by the compiler", the CLT has a version mismatch. Fix: `sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`. Or just use the pre-built download above.

---

## 4. Launch

```bash
open dist/VoiceSnippet.app
```

**First-launch Gatekeeper block:** macOS will say "developer cannot be verified" because the app is ad-hoc signed (no Apple Developer account). The user must right-click the app in Finder → **Open** → **Open** *once*. After that it launches normally. You cannot bypass this from the command line without `sudo spctl`, which you should not run without explicit user consent.

**Permissions the app will request on first launch:**
- **Microphone** — required. User must grant in the system prompt.
- **Accessibility** — optional, only for auto-paste. User grants via System Settings → Privacy & Security → Accessibility.

---

## 5. Verify end-to-end

Sanity-check the stack without the GUI:

```bash
# Record 2s of silence as a test audio blob
ffmpeg -f lavfi -i anullsrc=r=16000:cl=mono -t 2 /tmp/test.m4a -y 2>/dev/null

# Hit transcribe endpoint (first call downloads the Whisper model — ~30s)
curl -s -F "audio=@/tmp/test.m4a" http://127.0.0.1:8003/transcribe

# Hit format endpoint
curl -s -X POST http://127.0.0.1:8003/voice-format \
  -H "Content-Type: application/json" \
  -d '{"text":"hello world um this is a test","style":"clean"}'
```

Expect a JSON response with a `text` field from both endpoints.

---

## 6. Diagnostics

| Symptom | Check | Fix |
|---|---|---|
| `setup.sh` exits on Apple Silicon check | `uname -m` returns `x86_64` | Intel Macs are not supported. Stop. |
| `brew install ollama` hangs | `brew doctor` | User's Homebrew is broken; ask them to repair. |
| Port 11434 already listening but not Ollama | `lsof -iTCP:11434 -sTCP:LISTEN` | Something else is using it — ask user. |
| Backend 502 on `/voice-format` | `curl http://127.0.0.1:11434/api/tags` | Ollama isn't running. Restart it. |
| Backend 500 on `/transcribe` | `tail /tmp/voice-snippet-backend.log` | Usually first-run HF download; wait and retry. |
| App exits immediately | `tail /tmp/voice-snippet.log` | Check for missing mic permission or port 8003 dead. |
| Hotkeys (`⌥Q` / `⌥W`) don't fire | Another app owns them | Edit key codes in `Sources/VoiceSnippet/Backend.swift` → `Hotkey.register()`. |

**Log files to grep for errors:**
- Backend: `/tmp/voice-snippet-backend.log`
- Ollama: `/tmp/ollama.log`
- App: `/tmp/voice-snippet.log`

---

## 7. Configuration knobs

Agents should not change these without asking the user. Listed here for diagnosis only.

| Variable | Default | Effect |
|---|---|---|
| `OLLAMA_FAST_MODEL` | `gemma3:1b` | Formatter model. Can swap for `gemma3:4b` or `qwen2.5:3b` if user wants higher quality / slower output. |
| `WHISPER_MODEL` | `distil-whisper-large-v3` | mlx-whisper variant. Smaller options: `whisper-tiny`, `whisper-base` (faster, less accurate). |
| `OLLAMA_URL` | `http://127.0.0.1:11434` | Where the backend finds Ollama. |
| `OLLAMA_KEEP_ALIVE` | unset | Set to `30m` to keep Ollama model resident and avoid cold starts. |
| `PORT` | `8003` | Backend port. The Swift app hardcodes `8003` — do not change without updating `Sources/VoiceSnippet/Backend.swift`. |

---

## 8. Repo layout cheat sheet

```
voice-snippet/
├── Sources/VoiceSnippet/       Swift app (SwiftUI, menubar, hotkeys, audio capture)
│   ├── App.swift
│   ├── Backend.swift           HTTP client to :8003, hotkey registration
│   ├── Views.swift             Record / History / Dictionary / Settings tabs
│   └── ...
├── backend/
│   ├── app.py                  FastAPI: /transcribe, /voice-format, /health
│   └── requirements.txt
├── scripts/
│   ├── setup.sh                One-shot installer (§2)
│   ├── make-app.sh             Builds + packages dist/VoiceSnippet.app
│   └── gen-icon.swift          Generates AppIcon.icns
├── Info.plist                  App bundle metadata
├── VoiceSnippet.entitlements   Sandbox exemptions (mic access, network client)
└── Package.swift               SwiftPM manifest
```

---

## 9. What NOT to do

- Don't `rm -rf ~/.analystai/` — this is where user voice notes and their dictionary live. Delete only with explicit confirmation.
- Don't modify `~/.cache/huggingface/` — evicting the cache forces a 1.5 GB re-download on next use.
- Don't change hotkey bindings or the backend port without asking.
- Don't commit `dist/`, `.venv/`, or `.build/` — they are gitignored.
- Don't skip Gatekeeper with `sudo spctl --master-disable`; it affects the whole system.
- Don't create a Developer ID certificate or upload to notarization — this project is ad-hoc signed by design.

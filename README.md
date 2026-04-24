# Voice Snippet

A tiny floating macOS widget for **100% local** speech-to-text with instant LLM cleanup. Press a hotkey, speak, and the transcript is on your clipboard — cleaned up, bulleted, or rewritten as an email. Nothing ever leaves your Mac.

Two modes:
- **Mini pill** — a small horizontal bar that stays out of the way
- **Full window** — tabs for Record / History / Dictionary / Settings

<!-- If you have a screenshot, drop it here -->

## What this actually does

1. You press `⌥W` anywhere on your Mac.
2. Voice Snippet starts recording from your mic.
3. You press `⌥W` again (or release it, in push-to-talk mode) to stop.
4. The audio is sent to a small local service on `127.0.0.1:8003`.
5. That service transcribes it with [**mlx-whisper**](https://github.com/ml-explore/mlx-examples) (Whisper, optimized for Apple Silicon).
6. The raw transcript is copied to your clipboard immediately.
7. If you want, click a style (or hit `⌘1`–`⌘6`) and the transcript gets rewritten by a local LLM (via **Ollama**) — cleaned up, bulleted, as an email, etc. The result replaces the clipboard.

No cloud. No telemetry. No API keys. The whole stack runs on `127.0.0.1`.

## Requirements

- **Apple Silicon Mac** (M1/M2/M3/M4). Intel Macs are not supported — the Whisper model runs on Apple's MLX framework, which only targets Apple Silicon.
- **macOS 13 (Ventura) or later**
- **~10 GB free disk space** — for the Whisper model (~1.5 GB), Ollama model (~750 MB), and Python deps
- **8 GB RAM minimum**, 16 GB recommended
- **Homebrew** — for installing Ollama (install from [brew.sh](https://brew.sh) if you don't have it)

> **Note:** You do **not** need Xcode or Xcode Command Line Tools for normal use. The setup script downloads a pre-built `VoiceSnippet.app` from GitHub Releases. Building from source is only needed if you're contributing code — see [Contributing](#contributing).

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `⌥Q` | Show / hide the window |
| `⌥W` | Record now — start / stop recording (auto-shows window if hidden) |

Push-to-talk mode (toggle in Settings): hold `⌥W` to record, release to stop.

Once a transcript appears:

| Shortcut | Style |
|---|---|
| `⌘1` | Clean |
| `⌘2` | Bullets |
| `⌘3` | Email |
| `⌘4` | Formal |
| `⌘5` | Notes |
| `⌘6` | Tweet |

---

## What you're about to install

Voice Snippet depends on two local runtimes. If you've never used them, here's the one-paragraph version:

- **[Ollama](https://ollama.com)** — a tiny server that runs open-source LLMs locally on your Mac. Think "Docker for language models". You `ollama pull` a model once, then anything on your machine can chat with it via `http://127.0.0.1:11434`. We use it to clean up transcripts. Free, open-source, no account needed.
- **[mlx-whisper](https://github.com/ml-explore/mlx-examples/tree/main/whisper)** — Apple's MLX-accelerated port of OpenAI's Whisper speech-to-text model. Runs on your GPU (well, Apple Silicon's unified memory). It's a Python package; our backend uses it directly. It downloads the model weights from Hugging Face on first use.

Between them they do the whole job, offline.

---

## Setup

> **Using Claude Code, Codex, Cursor, or another coding agent?** Point it at [AGENTS.md](AGENTS.md) and tell it *"set this up for me"* — that file has step-by-step instructions with verifiable checkpoints written for non-interactive agent execution.

### Fast path — one script

If you already have Homebrew and Xcode Command Line Tools, this single command installs everything:

```bash
git clone https://github.com/Vietnam-VoDich/voice-snippet.git
cd voice-snippet
./scripts/setup.sh
```

`setup.sh` will:
1. Check you're on Apple Silicon (abort if not)
2. Install Ollama via Homebrew (skip if already installed)
3. Start `ollama serve` in the background if nothing is running on port 11434
4. Pull the `gemma3:1b` formatter model (~750 MB, skip if already pulled)
5. Set `OLLAMA_KEEP_ALIVE=30m` so the model stays warm in RAM
6. Create `.venv/` and install the backend's Python dependencies
7. Build the Swift app and package it as `dist/VoiceSnippet.app`

When it's done, open two terminals:

```bash
# Terminal 1 — the backend (leave this running)
source .venv/bin/activate
python backend/app.py

# Terminal 2 — launch the app
open dist/VoiceSnippet.app
```

On first launch macOS will say **"developer cannot be verified"** — that's because the app is ad-hoc signed locally (no Apple Developer account is involved). Right-click `VoiceSnippet.app` in Finder → **Open** → **Open**. You only need to do this once.

Prefer it in `/Applications`? Run `./scripts/make-app.sh install`.

---

### Manual path — step by step

If `setup.sh` fails, or you want to understand each piece, here's the same thing in four parts. Run everything from the repo root after:

```bash
git clone https://github.com/Vietnam-VoDich/voice-snippet.git
cd voice-snippet
```

#### 1. Install Ollama

Ollama is the local LLM runtime that rewrites your transcripts. You have two install options — pick one.

**Option A — Homebrew (recommended, matches the setup script):**

```bash
brew install ollama
```

**Option B — the `.dmg` from ollama.com:**

Download from [ollama.com/download/mac](https://ollama.com/download/mac), double-click to install. This gives you `Ollama.app` in `/Applications`. You can launch it from Spotlight and a llama icon appears in your menu bar — that's the server running.

Verify the install:

```bash
ollama --version
```

#### 2. Start Ollama

Ollama needs to be running (listening on `127.0.0.1:11434`) whenever Voice Snippet is in use. Again, two choices:

**If you used the `.dmg`:** launch `Ollama.app` from Applications (or Spotlight). You'll see a llama icon in your menu bar — that means it's serving. That's it.

**If you used Homebrew:** run it from the terminal:

```bash
ollama serve
```

This will block the terminal and print logs. Either leave it running in a dedicated terminal, or detach it:

```bash
nohup ollama serve >/tmp/ollama.log 2>&1 &
disown
```

**Verify it's up:**

```bash
curl -s http://127.0.0.1:11434/api/tags
```

Expect: `{"models":[...]}` (possibly an empty list the first time). If you get *"connection refused"*, Ollama isn't running.

#### 3. Pull the formatter model

This downloads `gemma3:1b` (~750 MB) to `~/.ollama/models/`. Done once per machine.

```bash
ollama pull gemma3:1b
```

You'll see a progress bar. On a decent connection it takes a couple of minutes.

**Keep the model warm** so the first reformat after a pause isn't slow:

```bash
launchctl setenv OLLAMA_KEEP_ALIVE 30m
```

Then quit and relaunch `Ollama.app` (or restart `ollama serve`) so it picks up the new env var.

**Verify the model works:**

```bash
ollama run gemma3:1b "rewrite as a tweet: hello world it is a nice day"
```

You should get back a polished one-liner in under a second. Type `/bye` to exit the chat.

Want a higher-quality (but slower) model? Try `gemma3:4b` (~3.3 GB). Swap it in via:

```bash
export OLLAMA_FAST_MODEL=gemma3:4b    # before starting the backend
```

#### 4. Start the Voice Snippet backend

The backend is a ~100-line FastAPI service in `backend/` that exposes two endpoints: `/transcribe` (wraps mlx-whisper) and `/voice-format` (wraps Ollama). The Swift app talks to it over HTTP on port 8003.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
python backend/app.py
```

You should see:

```
INFO:     Uvicorn running on http://127.0.0.1:8003
```

**Leave this terminal open.** The app needs the backend running.

**Verify it works:**

```bash
curl -s http://127.0.0.1:8003/health
```

Expect: `{"ok":true,"whisper":"mlx-community/distil-whisper-large-v3","ollama_model":"gemma3:1b"}`.

> **Heads up:** the very first time you record audio, mlx-whisper downloads the Whisper model (`mlx-community/distil-whisper-large-v3`, ~1.5 GB) to `~/.cache/huggingface/`. The first transcription will take ~30 seconds. Every one after that takes under 2 seconds.

If you want to pre-download the model so the first recording feels instant:

```bash
pip install huggingface_hub
huggingface-cli download mlx-community/distil-whisper-large-v3
```

#### 5. Get and launch the app

**Option A — Download pre-built (recommended, no Xcode needed):**

```bash
curl -fSL https://github.com/Vietnam-VoDich/voice-snippet/releases/latest/download/VoiceSnippet.app.tar.gz -o /tmp/VoiceSnippet.app.tar.gz
mkdir -p dist
tar -xzf /tmp/VoiceSnippet.app.tar.gz -C dist/
open dist/VoiceSnippet.app
```

**Option B — Build from source (requires Xcode Command Line Tools):**

```bash
./scripts/make-app.sh
open dist/VoiceSnippet.app
```

`make-app.sh` builds a Swift release binary, generates the app icon, assembles `dist/VoiceSnippet.app`, and ad-hoc codesigns it so Gatekeeper allows launch. Requires `xcode-select --install`.

On first launch, macOS will say **"developer cannot be verified"**. Right-click `VoiceSnippet.app` in Finder → **Open** → **Open**. You only need to do this once.

Want it in `/Applications`?

```bash
# If you built from source:
./scripts/make-app.sh install
# If you downloaded:
cp -R dist/VoiceSnippet.app /Applications/
```

#### 6. Grant permissions

On first launch the app will prompt for:

- **Microphone** — required, for audio capture. Click **OK**.
- **Accessibility** — optional, only needed if you turn on *Auto-paste into frontmost app* in Settings. Grant via System Settings → Privacy & Security → Accessibility.

No cloud. No telemetry. Audio never leaves your Mac.

---

## Daily use

Once everything is running:

1. Leave Ollama running (menu bar icon or `ollama serve` in a terminal).
2. Leave the backend running (`source .venv/bin/activate && python backend/app.py`).
3. Launch `VoiceSnippet.app`.
4. Anywhere on your Mac, press `⌥W` to start recording, press `⌥W` again to stop.
5. The raw transcript is on your clipboard. Click a style (or hit `⌘1`–`⌘6`) to reformat.

Want it to persist across reboots? You can make `ollama serve` and the backend run as launchd agents — that's on the roadmap but not covered here yet.

## Where your data lives

| Path | Contents |
|---|---|
| `~/.analystai/voice-notes/YYYY-MM-DD.md` | Daily transcript log — one file per day, timestamped entries |
| `~/.analystai/voice-notes/dictionary.json` | Custom vocabulary and context terms |
| `~/.ollama/models/` | Downloaded Ollama models |
| `~/.cache/huggingface/hub/` | Downloaded Whisper model |
| `/tmp/voice-snippet.log` | App output and debug logs |
| `/tmp/ollama.log` | Ollama logs (if you started it via `nohup`) |

Open the voice-notes folder from the app via Settings → "Open voice-notes folder", or from terminal:

```bash
open ~/.analystai/voice-notes
```

## Custom vocabulary

The **Dictionary** tab lets you teach Voice Snippet words it mishears. Add entries like:

| Heard | Correct | Context (optional) |
|---|---|---|
| deep world | DP World | DP World is a port operator in Dubai |
| eleven labs | ElevenLabs | ElevenLabs is a voice AI company |

The "Heard → Correct" replacement runs after transcription (case-insensitive). The context gets added to the LLM system prompt when you reformat text, so the model knows what you were talking about.

Entries persist in `dictionary.json`.

## Formatter styles

After a transcription you can reformat it with a click or `⌘1` – `⌘6`:

| Style | Use case |
|---|---|
| Clean | Fix filler words, punctuation, obvious speech-to-text errors |
| Bullets | Convert to a tight bulleted list |
| Email | Rewrite as a friendly, professional email body |
| Formal | Polished business-correspondence register |
| Notes | Meeting-style notes with headers |
| Tweet | Single punchy line under 280 chars |

You can also type a custom instruction ("make it sound excited", "add emojis", etc.) via **Format → Custom prompt…**.

## Architecture

```
┌──────────────────┐   multipart m4a    ┌────────────────────┐
│  Voice Snippet   │ ──────────────────▶│   Backend :8003    │
│ (Swift / SwiftUI)│                    │                    │
│                  │                    │ POST /transcribe   │──▶ mlx-whisper (distil-whisper-large-v3)
│ - AVAudioRecorder│                    │ POST /voice-format │──▶ Ollama :11434 (gemma3:1b)
│ - Global hotkeys │                    └────────────────────┘
│ - Menubar icon   │
│ - Floating window│
└──────────────────┘
        │
        └─▶ NSPasteboard (clipboard) + optional ⌘V auto-paste
```

Zero network calls outside `127.0.0.1`.

## Troubleshooting

**"No response from http://127.0.0.1:8003"** — the backend isn't running. From the repo root: `source .venv/bin/activate && python backend/app.py`. Verify with `curl -s http://127.0.0.1:8003/health` or `lsof -iTCP:8003 -sTCP:LISTEN`.

**"ollama unreachable" from the backend** — Ollama isn't running or isn't on port 11434. Check with `curl -s http://127.0.0.1:11434/api/tags`. If it's down, launch `Ollama.app` or run `ollama serve`.

**Formatting takes 5+ seconds on the first call** — Ollama cold-starts the model on first request. Set `launchctl setenv OLLAMA_KEEP_ALIVE 30m` and relaunch Ollama. Subsequent calls are near-instant.

**First recording takes 30+ seconds** — mlx-whisper is downloading the model (~1.5 GB) from Hugging Face. Only happens once. Pre-download with `huggingface-cli download mlx-community/distil-whisper-large-v3`.

**Hotkeys don't fire** — another app has claimed `⌥Q` or `⌥W`. Quit the other app, or edit the key codes in `Sources/VoiceSnippet/Backend.swift` → `Hotkey.register()`.

**Window stuck off-screen** — quit (`pkill -x VoiceSnippet`) and relaunch. The window repositions itself on launch.

**`brew install ollama` fails** — run `brew doctor` and fix whatever it reports. If Homebrew itself is missing, install it from [brew.sh](https://brew.sh) first.

**`swift build` errors with "no such command"** — you don't have Xcode Command Line Tools. Run `xcode-select --install` and try again.

**`swift build` errors with "SDK is not supported by the compiler"** — your Command Line Tools have a version mismatch between the Swift compiler and SDK (common after macOS updates). Fix by reinstalling CLT: `sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`. Or skip building entirely and use the pre-built app from GitHub Releases.

**"Operation not permitted" on mic access** — macOS blocks mic access silently if the plist is malformed. Quit the app (`pkill -x VoiceSnippet`), rebuild (`./scripts/make-app.sh`), relaunch, and accept the mic prompt when it appears.

## Advanced configuration

Environment variables — set them in the terminal **before** `python backend/app.py`:

| Variable | Default | Purpose |
|---|---|---|
| `OLLAMA_FAST_MODEL` | `gemma3:1b` | Ollama model used for reformatting. Try `gemma3:4b` or `qwen2.5:3b` for higher quality. |
| `WHISPER_MODEL` | `distil-whisper-large-v3` | mlx-whisper variant. Try `whisper-tiny` or `whisper-base` for faster (less accurate) transcription. |
| `OLLAMA_URL` | `http://127.0.0.1:11434` | Where the backend finds Ollama. |
| `OLLAMA_KEEP_ALIVE` | — | How long Ollama keeps models resident in RAM. Set to `30m` to avoid cold starts. |
| `PORT` | `8003` | Backend port. The Swift app hardcodes `8003` — don't change this without also editing `Sources/VoiceSnippet/Backend.swift`. |

## Contributing

Issues and PRs welcome. See [AGENTS.md](AGENTS.md) for the fastest way to get a local dev environment up (written for coding agents, but humans can follow it too).

## License

MIT — see [LICENSE](LICENSE).

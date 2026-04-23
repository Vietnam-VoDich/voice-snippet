# Voice Snippet

A tiny floating macOS widget for **100% local** speech-to-text with instant LLM cleanup. Press a hotkey, speak, and the transcript is on your clipboard — cleaned up, bulleted, or rewritten as an email, all offline.

Two modes:
- **Mini pill** — a small horizontal bar that stays out of the way
- **Full window** — tabs for Record / History / Dictionary / Settings

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `⌥Q` | Show / hide the window |
| `⌥W` | Record now — start / stop recording (auto-shows window if hidden) |

Push-to-talk mode (toggle in Settings): hold `⌥W` to record, release to stop.

## Requirements

- **Apple Silicon Mac** (M1/M2/M3/M4). Intel Macs are not supported — the Whisper model runs on MLX which is Apple-Silicon-only.
- **macOS 13 (Ventura) or later**
- **~10 GB free disk space** for the models (Ollama model + Whisper model + backend deps)
- **8 GB RAM minimum**, 16 GB recommended

## Setup

> **Using Claude Code, Codex, Cursor, or another coding agent?** Point it at [AGENTS.md](AGENTS.md) and tell it *"set this up for me"* — that file has step-by-step instructions with verifiable checkpoints written for non-interactive agent execution.

### Fast path — one script

```bash
git clone https://github.com/Vietnam-VoDich/voice-snippet.git
cd voice-snippet
./scripts/setup.sh
```

`setup.sh` installs Ollama (via Homebrew), pulls the `gemma3:1b` formatter model, creates a Python venv for the backend, builds the Swift app, and packages it as `dist/VoiceSnippet.app`. When it's done you start the backend in one terminal (`source .venv/bin/activate && python backend/app.py`) and launch the app with `open dist/VoiceSnippet.app`.

On first launch, macOS will say "developer cannot be verified" — right-click the app in Finder → **Open** → **Open**. You only need to do this once. (The app is ad-hoc signed locally; there's no Apple Developer account involved.)

To install into `/Applications`: `./scripts/make-app.sh install`.

### Manual path

Prefer to go step by step? Run these from the repo root.

### 1. Clone the repo

```bash
git clone https://github.com/Vietnam-VoDich/voice-snippet.git
cd voice-snippet
```

All remaining steps run from inside this directory.

### 2. Install Ollama and pull the formatter model

```bash
brew install ollama
```

Start Ollama (or launch Ollama.app from Applications):

```bash
ollama serve
```

Pull the formatter model:

```bash
ollama pull gemma3:1b
```

This is a 750 MB model that rewrites transcribed speech in under 0.2 seconds per call. It runs entirely on your Mac.

Keep it resident in memory so there's no cold-start delay:

```bash
launchctl setenv OLLAMA_KEEP_ALIVE 30m
```

Then quit and relaunch Ollama.app (or restart `ollama serve`).

Verify it works:

```bash
ollama run gemma3:1b "rewrite as a tweet: hello world it is a nice day"
```

### 3. Start the backend

The backend is a small FastAPI service in `backend/` that wraps Ollama (for formatting) and mlx-whisper (for speech-to-text). From the repo root:

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

Leave this terminal open — the app needs the backend running.

The Whisper model (`mlx-community/distil-whisper-large-v3`, ~1.5 GB) downloads automatically on your first recording and is cached under `~/.cache/huggingface/`. The first transcription takes ~30 seconds while it downloads; every one after that takes under 2 seconds.

### 4. Build Voice Snippet as a proper `.app`

In a second terminal, from the repo root:

```bash
./scripts/make-app.sh
open dist/VoiceSnippet.app
```

This builds a Swift release binary, generates the app icon, assembles `dist/VoiceSnippet.app`, and ad-hoc codesigns it so Gatekeeper lets it launch.

On first launch macOS will say "developer cannot be verified" — right-click the app in Finder → **Open** → **Open**. You only need to do this once.

Want it in `/Applications`? `./scripts/make-app.sh install`.

### 5. Grant permissions

First launch, macOS will prompt for:

- **Microphone** — required, for audio capture
- **Accessibility** — only needed if you enable *Auto-paste into frontmost app* in Settings. Grant in System Settings → Privacy & Security → Accessibility.

No cloud. No telemetry. Audio never leaves your Mac.

## Where your data lives

| Path | Contents |
|---|---|
| `~/.analystai/voice-notes/YYYY-MM-DD.md` | Daily transcript log — one file per day, timestamped entries |
| `~/.analystai/voice-notes/dictionary.json` | Custom vocabulary and context terms |
| `~/.cache/huggingface/hub/` | The downloaded Whisper model |
| `/tmp/voice-snippet.log` | App output and debug logs |

Open the voice-notes folder from the app via Settings → "Open voice-notes folder", or from terminal:

```bash
open ~/.analystai/voice-notes
```

## Custom vocabulary

The **Dictionary** tab lets you teach Voice Snippet words it mishears. Add entries like:

| Heard | Correct | Context (optional) |
|---|---|---|
| deep world | DP World | DP World is a port operator in Dubai |
| hamilton | Hamilton | Hamilton is our research platform |

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

**"No response from http://127.0.0.1:8003"** — the backend isn't running. From the repo root: `source .venv/bin/activate && python backend/app.py`. Verify with `lsof -iTCP:8003 -sTCP:LISTEN`.

**Formatting takes a long time on the first call** — Ollama loads the model into memory on cold start. Set `OLLAMA_KEEP_ALIVE=30m` (see step 1) and subsequent calls are instant.

**First recording takes 30+ seconds** — Whisper downloads the model on first use (~1.5 GB). This only happens once. You can pre-download: `pip install huggingface_hub && huggingface-cli download mlx-community/distil-whisper-large-v3`.

**Hotkeys don't fire** — another app has claimed `⌥Q` or `⌥W`. Quit it, or edit the key codes in `Sources/VoiceSnippet/Backend.swift` → `Hotkey.register()`.

**Window stuck off-screen** — quit (`pkill -x VoiceSnippet`) and relaunch. The window repositions itself on launch.

## Advanced configuration

Environment variables (set before starting the backend):

| Variable | Default | Purpose |
|---|---|---|
| `OLLAMA_FAST_MODEL` | `gemma3:1b` | Ollama model used for reformatting |
| `WHISPER_MODEL` | `distil-whisper-large-v3` | mlx-whisper variant for transcription |
| `OLLAMA_KEEP_ALIVE` | — | How long Ollama keeps models resident. Set to `30m` to avoid cold starts. |
| `PORT` | `8001` | Backend port. Voice Snippet expects `8003`. |

## License

MIT — see [LICENSE](LICENSE).

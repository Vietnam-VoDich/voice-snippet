# Hamilton Voice

Tiny floating macOS widget for **100% local** speech-to-text with optional LLM reformatting. Hotkey → speak → transcript is copied to your clipboard and (optionally) auto-pasted into the frontmost app.

Two clean modes:
- **Mini pill** — a small horizontal bar that stays out of the way
- **Full rectangle** — tabs for Record / History / Dictionary / Settings

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `⌥Q`  | Show / hide the window |
| `⌥W`  | Record now — start / stop recording (auto-shows window if hidden) |

Push-to-talk mode (Settings → toggle): hold `⌥W` to record, release to stop.

## Requirements

Hamilton Voice is a thin Swift client. All the heavy lifting happens in two local services you need to run:

### 1. Ollama — for voice reformatting (Clean / Bullets / Email / Formal / Notes / Tweet)

Install Ollama: https://ollama.com

Then pull the fast formatter model the backend expects:

```bash
ollama pull gemma3:4b
```

That's the model referenced by `OLLAMA_FAST_MODEL` in the backend. It's ~3.3 GB, runs comfortably on any Apple-silicon Mac, and produces the rewrites in under a second on an M-class chip.

If you want to swap to a different model, set the env var before starting the backend:

```bash
export OLLAMA_FAST_MODEL=qwen3:4b   # or whatever you prefer
```

Ollama must be reachable at `http://localhost:11434` (its default).

### 2. AnalystAI Local backend — HTTP endpoints for transcribe + format

Hamilton Voice talks to a small FastAPI backend at `http://127.0.0.1:8003`. Two endpoints are used:

| Endpoint | Purpose | Upstream |
|---|---|---|
| `POST /transcribe` | Upload an `audio/mp4` file, get back `{ "text": "..." }` | mlx-whisper + `distil-whisper-large-v3` |
| `POST /voice-format` | Body `{ text, style, instruction? }` → `{ text }` | Ollama chat using `OLLAMA_FAST_MODEL` |

The STT model (`distil-whisper-large-v3`) is downloaded automatically on first transcription — about 1.5 GB — and cached under `~/.cache/huggingface/`.

Override via env var if you want a different Whisper variant:

```bash
export WHISPER_MODEL=distil-whisper-large-v3
```

The backend also writes each successful transcription to `~/.analystai/voice-notes/YYYY-MM-DD.md` so your history survives app restarts.

### 3. macOS permissions

First launch will prompt for:
- **Microphone** — mandatory, for audio capture
- **Accessibility** — needed only if you enable *Auto-paste into frontmost app*; grant in System Settings → Privacy & Security → Accessibility

No cloud, no telemetry. If the backend on 8003 is unreachable, you'll see an error in the widget and a placeholder line will be appended to today's voice-note file so you can recover the raw audio path later.

## Build & run

```bash
cd ~/Desktop/voice-snippet
swift build -c release
.build/release/VoiceSnippet
```

For daily use, launch it detached so closing the terminal doesn't kill it:

```bash
nohup .build/release/VoiceSnippet > /tmp/voice-snippet.log 2>&1 &
disown
```

## Where things live

| Path | Contents |
|---|---|
| `~/.analystai/voice-notes/YYYY-MM-DD.md` | Daily transcript log (markdown, timestamped) |
| `~/.analystai/voice-notes/dictionary.json` | Custom vocabulary + context terms you've added |
| `/tmp/voice-snippet.log` | App stdout / stderr + debug logs |

## Custom vocabulary

The **Dictionary** tab lets you add corrections that run *after* transcription and context hints that get injected into the formatter prompt:

- **Heard** → **Correct** — e.g. *deep world* → *DP World* (case-insensitive replace)
- **Context** (optional) — e.g. *DP World is a port operator in Dubai*; this gets added to the system prompt whenever you format the text, so the LLM knows what you were talking about

Entries persist across restarts in `dictionary.json`.

## Architecture

```
┌──────────────────┐      multipart m4a        ┌─────────────────┐
│ Hamilton Voice   │ ─────────────────────────▶│  Backend :8003  │
│ (Swift / SwiftUI)│                            │                 │
│                  │                            │ POST /transcribe│──▶ mlx-whisper (distil-whisper-large-v3)
│ - AVAudioRecorder│                            │                 │
│ - Hotkeys (⌥Q,⌥W)│                            │ POST /voice-fmt │──▶ Ollama :11434 (gemma3:4b)
│ - Status bar     │                            └─────────────────┘
│ - Floating window│
└──────────────────┘
        │
        └─▶ NSPasteboard (clipboard) + optional ⌘V paste
```

All state lives locally. The app itself has zero network calls outside `127.0.0.1:8003`.

## Tips

- The menubar mic icon pulses red while recording and shows the elapsed timer.
- Right-click the menubar icon for a quick menu (auto-paste, push-to-talk, open notes folder, quit).
- The **Mini** pill has a drag-area in the middle — click-and-hold there to move the window around.
- `⌘1` … `⌘6` in the Record tab apply the six preset formatters (Clean, Bullets, Email, Formal, Notes, Tweet) to the last transcript.

## Troubleshooting

**"No response from http://127.0.0.1:8003"** — the AnalystAI Local backend isn't running. Start it (`cd ~/Desktop/analystai-local && python backend/app.py` or equivalent) and verify with `lsof -iTCP:8003 -sTCP:LISTEN`.

**Ollama timeout** — the first formatting request after an idle period can take a few seconds while Ollama warms the model. Make sure `ollama list` shows `gemma3:4b` and that `ollama serve` (or the Ollama menubar app) is running.

**Hotkey doesn't fire** — another app may have claimed `⌥Q` or `⌥W`. Close the conflicting app or edit `Backend.swift` → `Hotkey.register()` to pick different key codes.

**Window stuck off-screen** — quit the app (`pkill -x VoiceSnippet`) and relaunch; the window is repositioned on launch if the saved origin is outside the current screen.

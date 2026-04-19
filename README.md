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

**Step 1. Install Ollama.** Either download the native Mac app from https://ollama.com or use Homebrew:

```bash
brew install ollama
```

**Step 2. Start the Ollama service.** If you installed the Mac app, launch **Ollama.app** — it adds a llama icon to your menubar and runs the server automatically. If you installed via Homebrew, run it yourself in a terminal (keep it running):

```bash
ollama serve
```

You can verify it's up with:

```bash
curl http://localhost:11434/api/tags
# should return {"models":[...]} — empty list is fine on first run
```

**Step 3. Pull the formatter model.** The backend looks for `gemma3:4b` by default (env var `OLLAMA_FAST_MODEL`):

```bash
ollama pull gemma3:4b
```

This downloads ~3.3 GB the first time. Subsequent runs load from disk. On an M-class Mac it formats a paragraph in well under a second.

**Step 4. Verify.** `ollama list` should show the model, and you should be able to chat with it:

```bash
ollama list
# NAME         ID              SIZE      MODIFIED
# gemma3:4b    a2af6cc3eb7f    3.3 GB    …

ollama run gemma3:4b "rewrite this as a tweet: hello world it's a nice day"
```

**Swapping models.** Any Ollama chat model works. Point the backend at a different one with:

```bash
export OLLAMA_FAST_MODEL=qwen3:4b     # lighter, faster
# or
export OLLAMA_FAST_MODEL=qwen3:14b    # higher quality, slower
```

…then restart the backend. Pull the model first (`ollama pull …`) or Ollama will do it on first request.

### 2. Whisper (mlx-whisper) — for speech-to-text

Transcription runs through the **AnalystAI Local backend** (see step 3), which wraps [`mlx-whisper`](https://github.com/ml-explore/mlx-examples/tree/main/whisper) — an Apple-Silicon-optimised port of OpenAI Whisper that runs on the GPU (no CUDA, no rosetta).

**Step 1. mlx-whisper installs with the backend.** If you follow step 3 below (`pip install -r requirements.txt` in `analystai-local`), `mlx-whisper` is pulled in automatically. You can also install it standalone:

```bash
pip install mlx-whisper
```

Requires Apple Silicon (M1/M2/M3/M4). Intel Macs are not supported by MLX.

**Step 2. The model downloads on first use.** You don't need to download it manually. The first time you hit `POST /transcribe`, mlx-whisper pulls `mlx-community/distil-whisper-large-v3` (~1.5 GB) from HuggingFace and caches it under:

```
~/.cache/huggingface/hub/models--mlx-community--distil-whisper-large-v3/
```

Subsequent requests load from disk in under a second. You'll see a one-time log line like `[Whisper] Loading model distil-whisper-large-v3 (first use — downloads if needed)…` in the backend output.

**Optional: pre-download the model.** If you don't want the first recording to take an extra minute while it downloads, pre-fetch it:

```bash
pip install huggingface_hub
huggingface-cli download mlx-community/distil-whisper-large-v3
```

**Swapping models.** Any MLX-community Whisper variant works. Set the env var before starting the backend:

```bash
export WHISPER_MODEL=distil-whisper-large-v3   # default — fast, English-only, good accuracy
# or
export WHISPER_MODEL=whisper-large-v3-mlx       # slower, multilingual, higher accuracy
# or
export WHISPER_MODEL=whisper-tiny-mlx           # tiny & fast, lower accuracy
```

Browse available variants at https://huggingface.co/mlx-community?search_models=whisper.

### 3. AnalystAI Local backend — HTTP endpoints on :8003

Hamilton Voice talks to a small FastAPI backend at `http://127.0.0.1:8003`. Two endpoints:

| Endpoint | Purpose | Upstream |
|---|---|---|
| `POST /transcribe` | Upload an `audio/m4a` file (`multipart/form-data`, field `audio`), get back `{ "text": "..." }` | mlx-whisper + `$WHISPER_MODEL` |
| `POST /voice-format` | Body `{ text, style, instruction? }` → `{ text }` | Ollama chat using `$OLLAMA_FAST_MODEL` |

**Setup:**

```bash
cd ~/Desktop/analystai-local                # or wherever the backend lives
pip install -r backend/requirements.txt     # installs fastapi, uvicorn, mlx-whisper, etc.
export PORT=8003                            # Hamilton Voice expects 8003
python backend/app.py
```

You should see `Uvicorn running on http://127.0.0.1:8003` in the output. Leave it running — Hamilton Voice connects on each recording.

The backend also writes each successful transcription to `~/.analystai/voice-notes/YYYY-MM-DD.md` so history survives app restarts.

### 4. macOS permissions

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

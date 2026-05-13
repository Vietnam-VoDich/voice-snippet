# Voice Snippet

A tiny floating macOS widget for **100% local** speech-to-text with instant LLM cleanup. Press a hotkey, speak, and the transcript is on your clipboard — cleaned up, bulleted, or rewritten as an email. Nothing ever leaves your Mac.

**[⬇ Download the latest release](https://github.com/Vietnam-VoDich/voice-snippet/releases/latest)** — one click, drag to Applications, open. No terminal needed.

Two modes:
- **Mini pill** — a small horizontal bar that stays out of the way
- **Full window** — tabs for Record / History / Dictionary / Settings

## What it does

1. You press `⌥W` anywhere on your Mac.
2. Voice Snippet starts recording from your mic.
3. You press `⌥W` again (or release it, in push-to-talk mode) to stop.
4. The audio is transcribed on-device by **WhisperKit** running `distil-whisper-large-v3`.
5. The raw transcript is copied to your clipboard immediately.
6. If you want, click a style (or hit `⌘1`–`⌘6`) and the transcript is rewritten by **Apple Foundation Models** (the on-device LLM that powers Apple Intelligence) — cleaned up, bulleted, as an email, etc. The result replaces the clipboard.

No cloud. No telemetry. No API keys. No Python. No Ollama. Just one `.app`.

## Requirements

- **Apple Silicon Mac** (M1/M2/M3/M4)
- **macOS 26 (Tahoe) or later** — Apple Foundation Models needs it
- **Apple Intelligence enabled** — System Settings → Apple Intelligence & Siri
- **~2 GB free disk space** — for the Whisper model on first run

That's the entire dependency list.

## Install

1. Download **`VoiceSnippet.app.zip`** from the [latest release](https://github.com/Vietnam-VoDich/voice-snippet/releases/latest).
2. Double-click the zip to expand it.
3. Drag `VoiceSnippet.app` into your `Applications` folder.
4. Open it.

The app is signed and notarized by Apple, so it just opens — no Gatekeeper warnings, no right-click → Open workaround.

On first launch you'll see a quick 3-page onboarding (welcome / hotkeys / privacy). After that the app lives in your menubar.

### Permissions

The first time you record, macOS will prompt for:

- **Microphone** — required, for audio capture. Click **OK**.
- **Accessibility** — optional, only needed if you turn on *Auto-paste into frontmost app* in Settings. Grant via System Settings → Privacy & Security → Accessibility.

### What happens on first use

The very first time you press `⌥W`, WhisperKit downloads the `distil-whisper-large-v3` weights (~1.5 GB) into `~/Library/Application Support/argmaxinc.WhisperKit/`. The first transcription takes ~30 seconds; every one after that takes under 2 seconds.

The first time you press `⌘1`–`⌘6`, Foundation Models warms up on-device. No download — Apple ships the model with macOS.

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

## Daily use

1. Launch `VoiceSnippet.app` (or leave it running — it lives in the menubar).
2. Anywhere on your Mac, press `⌥W` to start recording, press `⌥W` again to stop.
3. The raw transcript is on your clipboard. Click a style (or hit `⌘1`–`⌘6`) to reformat.

That's it.

## Where your data lives

| Path | Contents |
|---|---|
| `~/.analystai/voice-notes/YYYY-MM-DD.md` | Daily transcript log — one file per day, timestamped entries |
| `~/.analystai/voice-notes/dictionary.json` | Custom vocabulary and context terms |
| `~/Library/Application Support/argmaxinc.WhisperKit/` | Cached WhisperKit / Whisper model weights |
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
┌────────────────────────────────────────────────────────────────┐
│  VoiceSnippet.app (Swift / SwiftUI)                            │
│                                                                │
│   ┌─────────────────┐                                          │
│   │ AVAudioRecorder │ ── temp .m4a ──▶ WhisperKit              │
│   │ (mic capture)   │                  (distil-whisper-large-v3│
│   └─────────────────┘                   on-device, MLX/CoreML) │
│                                                  │             │
│                                                  ▼             │
│                                         (raw transcript)       │
│                                                  │             │
│                                                  ▼             │
│                                       Apple Foundation Models  │
│                                       (on-device LLM, system)  │
│                                                  │             │
│                                                  ▼             │
│                                      NSPasteboard + auto-paste │
│                                                                │
│   Global hotkeys (⌥Q, ⌥W)  •  Menubar icon  •  Floating window │
└────────────────────────────────────────────────────────────────┘
```

Zero network calls except the one-time WhisperKit model download from Hugging Face on first launch.

## Build from source (developers only)

If you want to modify the app, you'll need Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/Vietnam-VoDich/voice-snippet.git
cd voice-snippet
./scripts/make-app.sh           # build + sign + open dist/VoiceSnippet.app
./scripts/make-app.sh install   # also copy to /Applications
```

For a full notarized release (requires Apple Developer credentials):

```bash
./scripts/release.sh            # build → sign → notarize → staple → tarball
```

> **Using Claude Code, Codex, Cursor, or another coding agent?** Point it at [AGENTS.md](AGENTS.md) and tell it *"set this up for me"* — that file has step-by-step instructions with verifiable checkpoints written for non-interactive agent execution.

## Troubleshooting

**"Apple Intelligence is off"** — the formatter (Clean / Bullets / etc.) requires it. System Settings → Apple Intelligence & Siri → toggle on. Speech-to-text continues to work either way.

**"This Mac doesn't support Apple Intelligence"** — you're on a Mac without an M-series chip, or on macOS 25 or earlier. Speech-to-text still works.

**First recording takes 30+ seconds** — WhisperKit is downloading the model (~1.5 GB) from Hugging Face. Only happens once. Subsequent transcriptions are sub-2-second.

**Hotkeys don't fire** — another app has claimed `⌥Q` or `⌥W`. Quit the other app, or edit the key codes in `Sources/VoiceSnippet/Backend.swift` → `Hotkey.register()`.

**Window stuck off-screen** — quit (`pkill -x VoiceSnippet`) and relaunch. The window repositions itself on launch.

**Want to see the onboarding again** — `defaults delete com.voicesnippet.app hasOnboarded`, then relaunch the app.

## Contributing

Issues and PRs welcome. See [AGENTS.md](AGENTS.md) for the fastest way to get a local dev environment up (written for coding agents, but humans can follow it too).

## License

MIT — see [LICENSE](LICENSE).

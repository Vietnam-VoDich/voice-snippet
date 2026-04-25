# Voice Snippet

A tiny floating macOS widget for **100% local** speech-to-text with instant LLM cleanup. Press a hotkey, speak, and the transcript is on your clipboard — cleaned up, bulleted, or rewritten as an email. Nothing ever leaves your Mac.

Two modes:
- **Mini pill** — a small horizontal bar that stays out of the way
- **Full window** — tabs for Record / History / Dictionary / Settings

## What this actually does

1. You press `⌥W` anywhere on your Mac.
2. Voice Snippet starts recording from your mic.
3. You press `⌥W` again (or release it, in push-to-talk mode) to stop.
4. The audio is transcribed on-device by **WhisperKit** running `distil-whisper-large-v3`.
5. The raw transcript is copied to your clipboard immediately.
6. If you want, click a style (or hit `⌘1`–`⌘6`) and the transcript is rewritten by **Apple Foundation Models** (the on-device LLM that powers Apple Intelligence) — cleaned up, bulleted, as an email, etc. The result replaces the clipboard.

No cloud. No telemetry. No API keys. No Python. No Ollama. Just one `.app`.

## Requirements

- **Apple Silicon Mac** (M1/M2/M3/M4)
- **macOS 26 or later** — Apple Foundation Models needs it
- **Apple Intelligence enabled** — System Settings → Apple Intelligence & Siri
- **~2 GB free disk space** — for the Whisper model on first run
- **Xcode Command Line Tools** — *only if building from source*. End users don't need this; `setup.sh` downloads a pre-built `.app` from GitHub Releases by default.

That's the entire dependency list.

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

## Setup

> **Using Claude Code, Codex, Cursor, or another coding agent?** Point it at [AGENTS.md](AGENTS.md) and tell it *"set this up for me"* — that file has step-by-step instructions with verifiable checkpoints written for non-interactive agent execution.

```bash
git clone https://github.com/Vietnam-VoDich/voice-snippet.git
cd voice-snippet
./scripts/setup.sh
open dist/VoiceSnippet.app
```

That's the whole setup. `setup.sh` checks that you're on Apple Silicon + macOS 26, then downloads a pre-built `VoiceSnippet.app` from [GitHub Releases](https://github.com/Vietnam-VoDich/voice-snippet/releases). If the download fails (no network, or you want a dev build), it falls back to building from source using your Swift toolchain.

No Python, no Ollama, no second terminal.

On first launch macOS will say **"developer cannot be verified"** — that's because the app is ad-hoc signed locally (no Apple Developer account is involved). Right-click `VoiceSnippet.app` in Finder → **Open** → **Open**. You only need to do this once.

Prefer it in `/Applications`? Run `./scripts/make-app.sh install`.

### What happens on first use

The very first time you press `⌥W`, WhisperKit downloads the `distil-whisper-large-v3` weights (~1.5 GB) into `~/Library/Application Support/argmaxinc.WhisperKit/`. The first transcription will take ~30 seconds. Every one after that takes under 2 seconds.

The first time you press `⌘1`–`⌘6`, Foundation Models warms up on-device. No download — Apple ships the model with macOS.

### Permissions

On first launch the app will prompt for:

- **Microphone** — required, for audio capture. Click **OK**.
- **Accessibility** — optional, only needed if you turn on *Auto-paste into frontmost app* in Settings. Grant via System Settings → Privacy & Security → Accessibility.

---

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

## Troubleshooting

**"Apple Intelligence is off"** — the formatter (Clean / Bullets / etc.) requires it. System Settings → Apple Intelligence & Siri → toggle on. Speech-to-text continues to work either way.

**"This Mac doesn't support Apple Intelligence"** — you're on a Mac without an M-series chip, or on macOS 25 or earlier. Speech-to-text still works.

**First recording takes 30+ seconds** — WhisperKit is downloading the model (~1.5 GB) from Hugging Face. Only happens once. Subsequent transcriptions are sub-2-second.

**Hotkeys don't fire** — another app has claimed `⌥Q` or `⌥W`. Quit the other app, or edit the key codes in `Sources/VoiceSnippet/Backend.swift` → `Hotkey.register()`.

**Window stuck off-screen** — quit (`pkill -x VoiceSnippet`) and relaunch. The window repositions itself on launch.

**`swift build` errors with "no such command"** — you don't have Xcode Command Line Tools. Run `xcode-select --install` and try again.

**"Operation not permitted" on mic access** — macOS blocks mic access silently if the plist is malformed. Quit the app (`pkill -x VoiceSnippet`), rebuild (`./scripts/make-app.sh`), relaunch, and accept the mic prompt when it appears.

**"developer cannot be verified" on every launch** — only the *first* launch should show this. If it persists, the app may have been re-downloaded with the quarantine attribute. Run `xattr -d com.apple.quarantine /Applications/VoiceSnippet.app` (or wherever the `.app` lives).

## Contributing

Issues and PRs welcome. See [AGENTS.md](AGENTS.md) for the fastest way to get a local dev environment up (written for coding agents, but humans can follow it too).

## License

MIT — see [LICENSE](LICENSE).

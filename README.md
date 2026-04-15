# Voice Snippet

Tiny macOS menubar app for local speech-to-text. Hotkey **⌘⌥Space** opens a small popover, records mic, sends to the AnalystAI Local backend at `http://127.0.0.1:8001/api/transcribe` (mlx-whisper / distil-whisper-large-v3), copies the result to clipboard, pastes it into the active app, and the backend appends it to `~/Documents/AnalystAI/voice-notes/YYYY-MM-DD.md`.

Completely local. No cloud.

## Build & run

```bash
cd ~/Desktop/voice-snippet
swift build -c release
.build/release/VoiceSnippet
```

First launch macOS will prompt for:
- **Microphone** access (for recording)
- **Accessibility** access (for pasting via synthesized ⌘V — grant in System Settings → Privacy & Security → Accessibility)

Requires AnalystAI Local backend running on port 8001.

## Why separate from Hamilton

This is a free STT client you can use from anywhere (email, Slack, Notes, anywhere text can go). Hamilton picks up your notes automatically by indexing the `voice-notes/` folder — no coupling.

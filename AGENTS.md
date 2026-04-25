# AGENTS.md — setup guide for coding agents

This file tells an AI coding agent (Claude Code, Codex, Cursor, Aider, etc.) how to set up Voice Snippet on a user's Mac from a fresh clone. Each step has a **verify** command with expected output — do not proceed until the check passes.

> **If you are a human:** use [README.md](README.md). This file is written for non-interactive agent execution.

---

## 0. What you are setting up

A single self-contained Swift `.app`. There is no separate backend, no Python, no Ollama.

- **Speech-to-text:** WhisperKit running `distil-whisper-large-v3`, on-device, downloaded once on first use into `~/Library/Application Support/argmaxinc.WhisperKit/`.
- **Formatter LLM:** Apple Foundation Models — built into macOS 26, no download.

Everything runs on the user's Mac. No cloud, no API keys, no network egress except WhisperKit's one-time model download from Hugging Face.

---

## 1. Preflight

Run these checks first. Abort with a clear message to the user if any fail.

```bash
# Must be Apple Silicon — WhisperKit + Foundation Models are Apple-Silicon-only
uname -m                              # expect: arm64

# Must be macOS 26 or later — Foundation Models requires it
sw_vers -productVersion               # expect: 26.* or higher

# Must have ~3 GB free for the Whisper model + build artifacts
df -h ~ | awk 'NR==2 {print $4}'      # expect: 3G+ free

# Swift toolchain is OPTIONAL — only needed if the prebuilt download fails.
# `setup.sh` will pull the .app from GitHub Releases by default.
swift --version                       # nice to have; not required
```

If `swift` is missing AND the prebuilt download fails (e.g. no network), tell the user to run `xcode-select --install` and re-run you.

If `sw_vers` shows macOS 25 or older, stop. Voice Snippet is built around `import FoundationModels`, which is unavailable below 26.

---

## 2. Get the app

```bash
./scripts/setup.sh
```

This is idempotent — safe to re-run. It will:
- Re-check Apple Silicon + macOS 26 (in case you skipped §1)
- Try to download the latest pre-built `VoiceSnippet.app` from GitHub Releases
- If that fails, fall back to: `swift build -c release`, generate `dist/AppIcon.icns`, assemble `dist/VoiceSnippet.app`, ad-hoc codesign

The prebuilt path takes ~5 seconds. The source build path takes ~5 minutes (SwiftPM fetches WhisperKit on first build).

**Verify it succeeded:**

```bash
test -d dist/VoiceSnippet.app                                 # bundle exists
test -x dist/VoiceSnippet.app/Contents/MacOS/VoiceSnippet     # executable present
codesign -dv dist/VoiceSnippet.app 2>&1 | grep -q adhoc       # ad-hoc signed
```

If all three pass, skip to [§4 Launch](#4-launch).

If `setup.sh` fails, fall through to the manual steps and diagnose.

---

## 3. Manual path (if §2 fails)

```bash
# Build the binary
swift build -c release

# Verify the binary
test -x .build/release/VoiceSnippet

# Package as a .app
./scripts/make-app.sh

# Verify the bundle
test -d dist/VoiceSnippet.app
```

Common failure modes:

- **`error: the package requires a higher minimum deployment target`** — the user is on macOS 25 or older. Stop.
- **SPM hangs fetching `argmax-oss-swift`** — network issue or HF rate-limited. Retry. If persistent, check `~/Library/Developer/Xcode/DerivedData/SourcePackages/`.
- **`undefined symbol: ... FoundationModels ...`** — Xcode Command Line Tools are out of date. `softwareupdate --install --all` and try again.

---

## 4. Launch

```bash
open dist/VoiceSnippet.app
```

**First-launch Gatekeeper block:** macOS will say "developer cannot be verified" because the app is ad-hoc signed (no Apple Developer account). The user must right-click the app in Finder → **Open** → **Open** *once*. After that it launches normally. You cannot bypass this from the command line without `sudo spctl`, which you should not run without explicit user consent.

**Permissions the app will request on first launch:**
- **Microphone** — required. User must grant in the system prompt.
- **Accessibility** — optional, only for auto-paste. User grants via System Settings → Privacy & Security → Accessibility.

**For the formatter (⌘1–⌘6) to work**, the user must have Apple Intelligence enabled: System Settings → Apple Intelligence & Siri → toggle on. Speech-to-text works without it; formatter does not.

---

## 5. Verify end-to-end

There is no HTTP API to curl anymore. End-to-end verification means launching the app and recording a snippet. Tell the user to:

1. Press `⌥W`, say "test one two three", press `⌥W` again.
2. Wait. (First time: ~30s while WhisperKit downloads weights. Subsequent: <2s.)
3. Confirm transcript appears in the app and on the clipboard.
4. Press `⌘1` to invoke the Clean style. Confirm reformatted text replaces the clipboard.

If any step hangs or errors, see §6.

---

## 6. Diagnostics

| Symptom | Check | Fix |
|---|---|---|
| `setup.sh` exits on Apple Silicon check | `uname -m` returns `x86_64` | Intel Macs are not supported. Stop. |
| `setup.sh` exits on macOS version check | `sw_vers -productVersion` < 26 | User must update macOS. Stop. |
| `swift build` fails with `FoundationModels` symbol errors | `swift --version` < 6.0 | `softwareupdate --install --all`, then `xcode-select --install`. |
| First recording hangs forever | `tail /tmp/voice-snippet.log` | WhisperKit is downloading the model (~1.5 GB). Be patient or check network. |
| Formatter (⌘1) silently fails or returns "Apple Intelligence is off" | System Settings → Apple Intelligence & Siri | User must enable Apple Intelligence. |
| Formatter says "Apple Intelligence model is still downloading" | macOS is fetching the FM model | Wait — this is a one-time OS-level download, separate from WhisperKit's. |
| App exits immediately on launch | `tail /tmp/voice-snippet.log` | Usually missing mic permission. Quit, rebuild, relaunch, accept prompts. |
| Hotkeys (`⌥Q` / `⌥W`) don't fire | Another app owns them | Edit key codes in `Sources/VoiceSnippet/Backend.swift` → `Hotkey.register()`. |

**Log file to grep for errors:** `/tmp/voice-snippet.log`

---

## 7. Configuration knobs

There are very few knobs left. Listed for diagnosis only — agents should not change these without asking the user.

| Where | What | Effect |
|---|---|---|
| `Sources/VoiceSnippet/Transcriber.swift` | `modelVariant` | Which Whisper model WhisperKit loads. Default `distil-whisper_distil-large-v3`. Other options listed at <https://huggingface.co/argmaxinc/whisperkit-coreml>. |
| `Sources/VoiceSnippet/Formatter.swift` | `stylePrompts` | The system prompt for each formatter style. |
| `Sources/VoiceSnippet/Formatter.swift` | `GenerationOptions(temperature: 0.2)` | Sampling temperature for Foundation Models. |

---

## 8. Repo layout cheat sheet

```
voice-snippet/
├── Sources/VoiceSnippet/       Swift app (SwiftUI, menubar, hotkeys, audio capture)
│   ├── main.swift              App controller, hotkey wiring, record/process loop
│   ├── Backend.swift           Recorder, Notes persistence, Hotkey registration, Config
│   ├── Transcriber.swift       WhisperKit wrapper — speech-to-text
│   ├── Formatter.swift         Foundation Models wrapper — LLM rewrite styles
│   ├── Models.swift            HistoryItem, DictionaryStore, AppState
│   └── Views.swift             Record / History / Dictionary / Settings tabs
├── scripts/
│   ├── setup.sh                One-shot installer (preflight + build)
│   ├── make-app.sh             Builds + packages dist/VoiceSnippet.app
│   └── gen-icon.swift          Generates AppIcon.icns
├── Info.plist                  App bundle metadata (LSMinimumSystemVersion 26.0)
├── VoiceSnippet.entitlements   Mic + Apple Events + network client
└── Package.swift               SwiftPM manifest — depends on argmax-oss-swift
```

---

## 9. What NOT to do

- Don't `rm -rf ~/.analystai/` — this is where user voice notes and their dictionary live. Delete only with explicit confirmation.
- Don't modify `~/Library/Application Support/argmaxinc.WhisperKit/` — evicting it forces a 1.5 GB re-download on next use.
- Don't change hotkey bindings without asking.
- Don't commit `dist/`, `.build/`, or `.swiftpm/` — they are gitignored.
- Don't skip Gatekeeper with `sudo spctl --master-disable`; it affects the whole system.
- Don't reintroduce a Python backend or Ollama. The app was deliberately migrated off both. If you find yourself reaching for `pip install` or `brew install ollama`, stop and re-read this file.

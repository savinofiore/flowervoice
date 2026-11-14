# FlowerVoice 🌸

Personal voice dictation for macOS (Wispr Flow / Willow style).
Speech-to-text runs **locally** (NVIDIA Parakeet TDT v3 via FluidAudio, on the Neural Engine); text cleanup uses **your Codex subscription**
(the ChatGPT login of the Codex CLI, `~/.codex/auth.json`). No API key and no cost per call.

## Usage

| Gesture | Action |
|---|---|
| **Tap ⌃⌘M** (Ctrl+Cmd+M) | Starts hands-free recording (🔒); tap again to transcribe, clean up and paste |
| **Hold ⌃⌘M** while talking, then release | Push-to-talk: pastes on release |

Menu bar (flower icon): status, permissions, copy last dictation, history, **Settings… (⌘,)**.

## Install

**From the installer:** open `dist/FlowerVoice-1.0.0.dmg` and drag FlowerVoice into Applications.

**From source:**

```bash
./scripts/build-app.sh --install   # build + sign + install into /Applications and launch
./scripts/make-dmg.sh              # build dist/FlowerVoice-<version>.dmg
./scripts/make-icon.sh             # regenerate Assets/AppIcon.icns
```

The app is signed with an Apple Development certificate, not notarized: on another Mac, open it the
first time with right-click → Open.

On first launch, grant:
1. **Microphone**
2. **Accessibility** (to paste with Cmd+V and read the text before the cursor)

FlowerVoice asks for each one in turn. ⌃⌘M is a system hot key and needs no permission
(it also works from a mouse button mapped to that shortcut, e.g. in Logi Options+).

The first launch downloads the Parakeet v3 model (~500 MB) into `~/Library/Application Support/FlowerVoice`.

## Settings

Menu → **Settings…**: microphone, language, dictionary, Codex model and reasoning, style
instructions, launch at login. They are stored in `~/.config/flowervoice/config.json`:

| Key | Default | Notes |
|---|---|---|
| `codexModel` | `gpt-5.6-luna` | Any model in `~/.codex/models_cache.json` |
| `reasoningEffort` | `low` | Lower is faster |
| `language` | `it` | Hint for Parakeet; `null` = auto-detect |
| `inputDevice` | system default | Microphone name as in System Settings → Sound (e.g. `"HyperX SoloCast"`). Use a non-Bluetooth mic so headphones stay in music mode. Falls back to the default if disconnected |
| `isCleanupEnabled` | `true` | `false` = raw transcript only |
| `dictionary` | `[]` | Names/terms to spell exactly |
| `extraInstructions` | `""` | Style preferences for the LLM |

## Pipeline

```
⌃⌘M (Carbon hot key) → AVCaptureSession 16 kHz (chosen mic only) → Parakeet v3 (local, ANE) → Codex Responses
(chatgpt.com/backend-api/codex/responses, Codex token) → clipboard + Cmd+V → clipboard restore
```

Context sent to the LLM: active app + up to 400 characters before the cursor (Accessibility).
Local history: `~/.config/flowervoice/history.jsonl`.

## Debugging

```bash
say -v Alice -o /tmp/t.aiff "ehm allora domani alle tre no alle quattro"
.build/debug/FlowerVoice --transcribe /tmp/t.aiff com.apple.mail
open -n --stdout /tmp/mic.txt /Applications/FlowerVoice.app --args --mic-test && sleep 4 && cat /tmp/mic.txt   # 2 s capture from inputDevice
/usr/bin/log stream --predicate 'subsystem == "dev.fiore.flowervoice"'
```

## Caveats

- The Codex endpoint is internal to ChatGPT, not a public API: it can change when Codex updates.
  If cleanup fails, FlowerVoice pastes the raw transcript.
- When the token expires it is refreshed the way Codex does it, and written back to `~/.codex/auth.json`.

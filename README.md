<p align="center">
  <img src="Assets/AppIcon.png" width="128" alt="FlowerVoice icon">
</p>

<h1 align="center">FlowerVoice 🌸</h1>

<p align="center">
  <em>A tiny, cozy dictation buddy that lives in your Mac's menu bar.</em><br>
  Talk, let go, and your words bloom into clean text wherever your cursor is.
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-pink?logo=apple&logoColor=white">
  <img alt="Apple Silicon" src="https://img.shields.io/badge/Apple%20Silicon-M1%2B-violet">
  <img alt="Swift 5.10" src="https://img.shields.io/badge/Swift-5.10-orange?logo=swift&logoColor=white">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-lightgrey">
</p>

---

## ✨ What it does

1. You press **⌃⌘M** and talk, just like you'd talk to a friend: "ehm", false starts and "no wait, I meant…" are all fine.
2. Your voice is turned into text **right on your Mac** by NVIDIA's Parakeet model, running on the Neural Engine. The audio never leaves your computer.
3. The transcript gets a gentle tidy-up by a Codex model, **using the Codex subscription you already have**. It removes filler words, applies your self-corrections, fixes punctuation and matches the tone of the app you're typing into.
4. The text is pasted where your cursor is, and your clipboard is put back the way it was.
   Clipboard managers are told to skip it, and in terminals it's always pasted as a single line, so nothing runs by surprise.

You get no API keys, pay nothing per word, and have no account to create. 🌷

## 🎀 How to use it

| Gesture | What happens |
|---|---|
| **Tap ⌃⌘M** | Hands-free mode 🔒: talk as long as you like, tap again to finish |
| **Hold ⌃⌘M**, talk, release | Push-to-talk: the text is pasted when you let go |

A little capsule at the bottom of the screen shows your voice level while you talk. A soft *tink* tells you it's listening.

The flower in the menu bar gives you:
- **Copy last dictation**
- **Dictation history… (⌘Y)**: search, copy, and see the original transcript
- **Settings… (⌘,)**: microphone, language, personal dictionary, Codex model, style instructions, launch at login

## 🌱 Getting started

### What you need
- A Mac with **Apple Silicon** running **macOS 14** or later
- The [Codex CLI](https://github.com/openai/codex), logged in with your ChatGPT account (`codex login`)

### Install

**The easy way:** grab the latest `FlowerVoice-<version>.dmg` from [Releases](../../releases) and drag FlowerVoice into Applications.
The app is not notarized, so macOS will refuse to open it the first time.
Go to **System Settings → Privacy & Security** and click **Open Anyway** (on macOS 14 you can also right-click the app and choose **Open**).
Release builds are signed ad-hoc, so after each update macOS may ask for Microphone and Accessibility again.

**From source:**

```bash
git clone https://github.com/savinofiore/flowervoice.git
cd flowervoice
./scripts/build-app.sh --install   # build, sign, copy to /Applications and launch
```

`build-app.sh` signs the app with your Apple Development certificate if you have one, so macOS remembers your permissions between builds.
Otherwise it signs ad-hoc.
You can also choose the identity with `FLOWER_SIGN_IDENTITY="…"`.

### First launch
FlowerVoice will politely ask for two permissions, one at a time:
1. **Microphone**, to hear you
2. **Accessibility**, to paste with ⌘V and read the few characters before your cursor, so new text continues the old smoothly

The first launch also downloads the Parakeet v3 model (~460 MB) into `~/Library/Application Support/FlowerVoice`.
It then prepares the model for the Neural Engine, which takes about 30 seconds, only once.

## 🧺 Settings

Everything lives in `~/.config/flowervoice/config.json` and can be changed from the Settings window:

| Key | Default | Notes |
|---|---|---|
| `codexModel` | `gpt-5.6-luna` | Any model listed in `~/.codex/models_cache.json` |
| `reasoningEffort` | `low` | Lower means faster |
| `language` | `it` | Hint for Parakeet; `null` means auto-detect |
| `inputDevice` | system default | Microphone name as shown in System Settings → Sound. A wired or USB mic keeps Bluetooth headphones in high-quality music mode 🎧 |
| `isCleanupEnabled` | `true` | `false` pastes the raw transcript and never contacts the network |
| `dictionary` | `[]` | Names and words to always spell exactly like this |
| `extraInstructions` | `""` | Your style wishes for the cleanup model |

## 🔒 Privacy, honestly

| What | Where it goes |
|---|---|
| Your **voice** | Stays on your Mac. It's transcribed locally and never uploaded or saved to disk. |
| The **transcript**, the **name of the active app** and up to **400 characters before your cursor** | Sent to OpenAI through the Codex endpoint, only when cleanup is on, with `store: false` |
| Anything typed into a **password field** or a **password manager** (1Password, Bitwarden, Passwords…) | Nothing is sent: the raw transcript is pasted, no context is read and nothing is saved to history |
| Your **Codex login** | FlowerVoice reads `~/.codex/auth.json` and, when the token expires, refreshes it exactly like Codex does and writes it back with `0600` permissions. Tokens go only to `chatgpt.com` and `auth.openai.com`. |
| The **speech model** | Downloaded once from Hugging Face by [FluidAudio](https://github.com/FluidInference/FluidAudio) on first launch |
| Your **dictation history** | A local file, `~/.config/flowervoice/history.jsonl`, readable only by you (`0600`). You can clear it from the History window. |

There's no telemetry, no analytics and no server of ours. 🌼

> [!NOTE]
> The Codex endpoint (`chatgpt.com/backend-api/codex/responses`) is the one the Codex CLI uses internally, not a public, documented API.
> It may change without notice; when cleanup fails, FlowerVoice simply pastes the raw transcript.
> FlowerVoice identifies itself honestly to OpenAI (`originator: flowervoice`); it reuses the Codex CLI's public OAuth client ID only to refresh the token Codex gave you.
> You are responsible for making sure your use complies with OpenAI's terms for your plan.

## 🛠️ How it works

```
⌃⌘M (Carbon hot key)
  → AVCaptureSession, 16 kHz mono, only the chosen mic
  → Parakeet TDT v3 via FluidAudio (local, Neural Engine, ~0.15 s)
  → Codex Responses API with your Codex token (cleanup, ~1–2 s)
  → clipboard + ⌘V → clipboard restored
```

<details>
<summary>Debugging tips</summary>

```bash
swift build
say -v Alice -o /tmp/t.aiff "ehm allora domani alle tre no alle quattro"
.build/debug/FlowerVoice --transcribe /tmp/t.aiff com.apple.mail          # full pipeline, no UI
open -n --stdout /tmp/mic.txt /Applications/FlowerVoice.app --args --mic-test && sleep 4 && cat /tmp/mic.txt
/usr/bin/log stream --predicate 'subsystem == "dev.fiore.flowervoice"'
```

</details>

## 💐 Contributing

Pull requests are very welcome, whether it's a bug fix, a new language or a nicer capsule.
Fork the repo, make your change on a branch and open a PR against `main`.
Keep functions small and names clear, and please describe how you tested it.

Found a security issue? Please don't open a public issue: use **[Report a vulnerability](../../security/advisories/new)** instead. 🙏

## 📜 License

[MIT](LICENSE). Made with care, and a lot of talking to myself, by Savino Fiore.

<p align="center"><sub>FlowerVoice is an independent project and is not affiliated with OpenAI or NVIDIA.</sub></p>

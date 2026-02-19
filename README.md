# Claude Notifications (plugin)

[![Ubuntu CI](https://github.com/777genius/claude-notifications-go/workflows/Ubuntu%20CI/badge.svg)](https://github.com/777genius/claude-notifications-go/actions)
[![macOS CI](https://github.com/777genius/claude-notifications-go/workflows/macOS%20CI/badge.svg)](https://github.com/777genius/claude-notifications-go/actions)
[![Windows CI](https://github.com/777genius/claude-notifications-go/workflows/Windows%20CI/badge.svg)](https://github.com/777genius/claude-notifications-go/actions)
[![Go Report Card](https://goreportcard.com/badge/github.com/777genius/claude-notifications-go)](https://goreportcard.com/report/github.com/777genius/claude-notifications-go)
[![codecov](https://codecov.io/gh/777genius/claude-notifications-go/branch/main/graph/badge.svg)](https://codecov.io/gh/777genius/claude-notifications-go)

<img width="250" height="350" alt="image" src="https://github.com/user-attachments/assets/e7aa6d8e-5d28-48f7-bafe-ad696857b938" />
<img width="350" height="239" alt="image" src="https://github.com/user-attachments/assets/42b7a306-f56f-4499-94cf-f3d573416b6d" />
<img width="220" alt="image" src="https://github.com/user-attachments/assets/4b5929d8-1a51-4a15-a3d5-dda5482554cc" />


Smart notifications for Claude Code with click-to-focus, git branch display, and webhook integrations.

## Table of Contents

  - [Supported Notification Types](#supported-notification-types)
  - [Installation](#installation)
    - [Prerequisites](#prerequisites)
    - [Quick Install (Recommended)](#quick-install-recommended)
    - [Manual Install](#manual-install)
    - [Updating](#updating)
  - [Features](#features)
  - [Platform Support](#platform-support)
    - [Click-to-Focus (macOS & Linux)](#click-to-focus-macos--linux)
  - [Configuration](#configuration)
    - [Manual Configuration](#manual-configuration)
    - [Sound Options](#sound-options)
    - [Test Sound Playback](#test-sound-playback)
  - [Manual Testing](#manual-testing)
  - [Contributing](#contributing)
  - [Troubleshooting](#troubleshooting)
  - [Documentation](#documentation)
  - [License](#license)

## Supported Notification Types

| Status | Icon | Description | Trigger |
|--------|------|-------------|---------|
| Task Complete | ✅ | Main task completed | Stop/SubagentStop hooks (state machine detects active tools like Write/Edit/Bash, or ExitPlanMode followed by tool usage) |
| Review Complete | 🔍 | Code review finished | Stop/SubagentStop hooks (state machine detects only read-like tools: Read/Grep/Glob with no active tools, plus long text response >200 chars) |
| Question | ❓ | Claude has a question | PreToolUse hook (AskUserQuestion) OR Notification hook |
| Plan Ready | 📋 | Plan ready for approval | PreToolUse hook (ExitPlanMode) |
| Session Limit Reached | ⏱️ | Session limit reached | Stop/SubagentStop hooks (state machine detects "Session limit reached" text in last 3 assistant messages) |
| API Error | 🔴 | Authentication expired, rate limit, server error, connection error | Stop/SubagentStop hooks (state machine detects via `isApiErrorMessage` flag + `error` field from JSONL) |


## Installation

### Prerequisites

- Claude Code (tested on v2.0.15)
- **Windows users:** Git Bash (included with [Git for Windows](https://git-scm.com/download/win)) or WSL
- **macOS/Linux users:** No additional software required

### Quick Install (Recommended)

One command to install everything:

```bash
curl -fsSL https://raw.githubusercontent.com/777genius/claude-notifications-go/main/bin/bootstrap.sh | bash
```

Then restart Claude Code and optionally run `/claude-notifications-go:settings` to configure sounds.

The binary is downloaded once and cached locally. You can re-run `/claude-notifications-go:settings` anytime to reconfigure.

> If the bootstrap script doesn't work for your environment, use the [Manual Install](#manual-install) below.

### Manual Install

<details>
<summary>Step-by-step installation (if bootstrap doesn't work)</summary>

```bash
# 1) Add marketplace
/plugin marketplace add 777genius/claude-notifications-go
# 2) Install plugin
/plugin install claude-notifications-go@claude-notifications-go
# 3) Restart Claude Code
# 4) Download binary
/claude-notifications-go:init
# 5) (Optional) Configure sounds and settings
/claude-notifications-go:settings
```

</details>

> Having issues with installation? See [Troubleshooting](#troubleshooting).

### Updating

Run the same command as for installation — it will update both the plugin and the binary:

```bash
curl -fsSL https://raw.githubusercontent.com/777genius/claude-notifications-go/main/bin/bootstrap.sh | bash
```

Then restart Claude Code to apply the new version. Your settings in `~/.claude/claude-notifications-go/config.json` are preserved across updates.

> **Note:** Downgrading to v1.18 or earlier requires manually copying config back to `config/config.json` inside the plugin directory.

<details>
<summary>Manual update (if bootstrap didn't work)</summary>

Claude Code also periodically checks for plugin updates automatically. Binaries are updated on the next hook invocation when a version mismatch is detected.

To update manually via Claude Code UI:

1. Run `/plugin`, select **Marketplaces**, choose `claude-notifications-go`, then select **Update marketplace**
2. Select **Installed**, choose `claude-notifications-go`, then select **Update now**

If the binary auto-update didn't work (e.g. no internet at the time), run `/claude-notifications-go:init` to download it manually. If hook definitions changed in the new version, restart Claude Code to apply them.

</details>


## Features

### 🖥️ Cross-Platform Support
- **macOS** (Intel & Apple Silicon), **Linux** (x64 & ARM64), **Windows 10+** (x64)
- Works in PowerShell, CMD, Git Bash, or WSL
- Pre-built binaries included - no compilation needed

### 🧠 Smart Detection
- **Operations count** File edits, file creates, ran commands + total time
- **6 notification types**: Task Complete, Review Complete, Question, Plan Ready, Session Limit, API Error
- **PreToolUse integration** for instant alerts when Claude asks questions or creates plans

### 🔔 Flexible Notifications
- **Desktop notifications** with custom icons and sounds
- **Click-to-focus** (macOS, Linux): Click notification to activate your terminal window
- **Git branch in title**: See current branch like `✅ Completed main [cat]`
- **Webhook integrations**: Slack, Discord, Telegram, Lark/Feishu, and custom endpoints
- **Session names**: Friendly identifiers like `[cat]` for multi-session tracking

### 🔊 Audio Customization
- **Multi-format support**: MP3, WAV, FLAC, OGG, AIFF
- **Volume control**: 0-100% customizable volume
- **Audio device selection**: Route notifications to a specific output device
- **System sounds**: Use macOS/Linux system sounds (optional)
- **Sound preview**: Test sounds before choosing with `/claude-notifications-go:settings`

### 🌐 Enterprise-Grade Webhooks
- **Retry logic** with exponential backoff
- **Circuit breaker** for fault tolerance
- **Rate limiting** with token bucket algorithm
- **Rich formatting** with platform-specific embeds/attachments
- **→ [Complete Webhook Documentation](docs/webhooks/README.md)**

### 🤝 Plugin Compatibility

Compatible with other Claude Code plugins that spawn background Claude instances:

- **[double-shot-latte](https://github.com/obra/double-shot-latte)** - Auto-continue plugin that uses a background Claude instance for context evaluation. Notifications are automatically suppressed for the background judge process (via `CLAUDE_HOOK_JUDGE_MODE=true` environment variable).

If you're developing a plugin that spawns background Claude instances and want to suppress notifications, set `CLAUDE_HOOK_JUDGE_MODE=true` in the environment before invoking Claude.

To disable this behavior and receive notifications even in judge mode, set in `~/.claude/claude-notifications-go/config.json`:

```json
{
  "notifications": {
    "respectJudgeMode": false
  }
}
```

## Platform Support

**Supported platforms:**
- macOS (Intel & Apple Silicon)
- Linux (x64 & ARM64)
- Windows 10+ (x64)

**No additional dependencies:**
- ✅ Binaries auto-download from GitHub Releases
- ✅ Pure Go - no C compiler needed
- ✅ All libraries bundled
- ✅ Works offline after first setup

**Windows-specific features:**
- Native Toast notifications (Windows 10+)
- Works in PowerShell, CMD, Git Bash, or WSL
- MP3/WAV/OGG/FLAC audio playback via native Windows APIs
- System sounds not accessible - use built-in MP3s or custom files

### Click-to-Focus (macOS & Linux)

Clicking a notification activates your terminal window. Auto-detects terminal and platform:

- **macOS** — via `terminal-notifier` with bundle ID detection. VS Code requires Accessibility and Screen Recording permissions (other terminals need neither); both are requested automatically on first use.
- **Linux** — via D-Bus daemon with fallback chain (GNOME extension, Shell Eval, wlrctl, kdotool, xdotool)

Enabled by default. See **[Click-to-Focus Guide](docs/CLICK_TO_FOCUS.md)** for configuration and supported terminals.

## Configuration

Run `/claude-notifications-go:settings` to configure sounds, volume, webhooks, and other options via an interactive wizard. You can re-run it anytime to reconfigure.

### Manual Configuration

Config file location:

| Platform | Path |
|----------|------|
| macOS / Linux | `~/.claude/claude-notifications-go/config.json` |
| Windows (Git Bash) | `~/.claude/claude-notifications-go/config.json` |
| Windows (PowerShell) | `$env:USERPROFILE\.claude\claude-notifications-go\config.json` |

Edit the config file directly:

```json
{
  "notifications": {
    "desktop": {
      "enabled": true,
      "sound": true,
      "volume": 1.0,
      "audioDevice": "",
      "clickToFocus": true,
      "terminalBundleId": "",
      "appIcon": "${CLAUDE_PLUGIN_ROOT}/claude_icon.png"
    },
    "webhook": {
      "enabled": false,
      "preset": "slack",
      "url": "",
      "chat_id": "",
      "format": "json",
      "headers": {}
    },
    "suppressQuestionAfterTaskCompleteSeconds": 12,
    "suppressQuestionAfterAnyNotificationSeconds": 12,
    "notifyOnSubagentStop": false,
    "notifyOnTextResponse": true,
    "respectJudgeMode": true
  },
  "statuses": {
    "task_complete": {
      "title": "✅ Completed",
      "sound": "${CLAUDE_PLUGIN_ROOT}/sounds/task-complete.mp3"
    },
    "review_complete": {
      "title": "🔍 Review",
      "sound": "${CLAUDE_PLUGIN_ROOT}/sounds/review-complete.mp3"
    },
    "question": {
      "title": "❓ Question",
      "sound": "${CLAUDE_PLUGIN_ROOT}/sounds/question.mp3"
    },
    "plan_ready": {
      "title": "📋 Plan",
      "sound": "${CLAUDE_PLUGIN_ROOT}/sounds/plan-ready.mp3"
    },
    "session_limit_reached": {
      "title": "⏱️ Session Limit Reached",
      "sound": "${CLAUDE_PLUGIN_ROOT}/sounds/error.mp3"
    },
    "api_error": {
      "title": "🔴 API Error: 401",
      "sound": "${CLAUDE_PLUGIN_ROOT}/sounds/error.mp3"
    },
    "api_error_overloaded": {
      "title": "🔴 API Error",
      "sound": "${CLAUDE_PLUGIN_ROOT}/sounds/error.mp3"
    }
  }
}
```

| Option | Default | Description |
|--------|---------|-------------|
| `notifyOnSubagentStop` | `false` | Send notifications when subagents (Task tool) complete |
| `notifyOnTextResponse` | `true` | Send notifications for text-only responses (no tool usage) |
| `respectJudgeMode` | `true` | Honor `CLAUDE_HOOK_JUDGE_MODE=true` env var to suppress notifications |
| `suppressQuestionAfterTaskCompleteSeconds` | `12` | Suppress question notifications for N seconds after task complete |
| `suppressQuestionAfterAnyNotificationSeconds` | `12` | Suppress question notifications for N seconds after any notification |

Each status can be individually disabled by adding `"enabled": false`.

### Sound Options

**Built-in sounds** (included):
- `${CLAUDE_PLUGIN_ROOT}/sounds/task-complete.mp3`
- `${CLAUDE_PLUGIN_ROOT}/sounds/review-complete.mp3`
- `${CLAUDE_PLUGIN_ROOT}/sounds/question.mp3`
- `${CLAUDE_PLUGIN_ROOT}/sounds/plan-ready.mp3`
- `${CLAUDE_PLUGIN_ROOT}/sounds/error.mp3`

**System sounds:**
- macOS: `/System/Library/Sounds/Glass.aiff`, `/System/Library/Sounds/Hero.aiff`, etc.
- Linux: `/usr/share/sounds/**/*.ogg` (varies by distribution)
- Windows: Use built-in MP3s (system sounds not easily accessible)

**Supported formats:** MP3, WAV, FLAC, OGG/Vorbis, AIFF

### List Available Sounds

See all available notification sounds on your system:

```bash
# List all sounds (built-in + system)
bin/list-sounds

# Output as JSON
bin/list-sounds --json

# Preview a sound
bin/list-sounds --play task-complete

# Preview at specific volume
bin/list-sounds --play Glass --volume 0.5
```

Or use the skill command: `/claude-notifications-go:sounds`

### Audio Device Selection

Route notification sounds to a specific audio output device instead of the system default:

```bash
# List available audio devices
bin/list-devices

# Output:
#   0: MacBook Pro-Lautsprecher
#   1: Babyface (23314790) (default)
#   2: Immersed
```

Then add the device name to your `~/.claude/claude-notifications-go/config.json`:

```json
{
  "notifications": {
    "desktop": {
      "audioDevice": "MacBook Pro-Lautsprecher"
    }
  }
}
```

Leave `audioDevice` empty or omit it to use the system default device.

### Test Sound Playback

Preview any sound file with optional volume control:

```bash
# Test built-in sound (full volume)
bin/sound-preview sounds/task-complete.mp3

# Test with reduced volume (30% - recommended for testing)
bin/sound-preview --volume 0.3 sounds/task-complete.mp3

# Test macOS system sound at 30% volume
bin/sound-preview --volume 0.3 /System/Library/Sounds/Glass.aiff

# Test custom sound at 50% volume
bin/sound-preview --volume 0.5 /path/to/your/sound.wav

# Show all options
bin/sound-preview --help
```

**Volume flag:** Use `--volume` to control playback volume (0.0 to 1.0). Default is 1.0 (full volume).


## Manual Testing

The plugin is invoked automatically by Claude Code hooks. To test manually:

```bash
# Test PreToolUse hook
echo '{"session_id":"test","transcript_path":"/path/to/transcript.jsonl","tool_name":"ExitPlanMode"}' | \
  claude-notifications handle-hook PreToolUse

# Test Stop hook
echo '{"session_id":"test","transcript_path":"/path/to/transcript.jsonl"}' | \
  claude-notifications handle-hook Stop
```

## Contributing

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for development setup, testing, building, and submitting changes.

## Troubleshooting

See **[Troubleshooting Guide](docs/troubleshooting.md)** for common issues:

- **Ubuntu 24.04**: `EXDEV: cross-device link not permitted` during `/plugin install` (TMPDIR workaround)
- **Windows**: install issues related to `%TEMP%` / `%TMP%` location

## Documentation

- **[Architecture](docs/ARCHITECTURE.md)** - Plugin architecture, directory structure, data flow

- **[Click-to-Focus](docs/CLICK_TO_FOCUS.md)** - Configuration, supported terminals, platform details

- **[Volume Control Guide](docs/volume-control.md)** - Customize notification volume
  - Configure volume from 0% to 100%
  - Logarithmic scaling for natural sound
  - Per-environment recommendations

- **[Interactive Sound Preview](docs/interactive-sound-preview.md)** - Preview sounds during setup
  - Interactive sound selection
  - Preview before choosing

- **[Troubleshooting](docs/troubleshooting.md)** - Common install/runtime issues
  - Ubuntu 24.04 `EXDEV` during `/plugin install` (TMPDIR workaround)

- **[Webhook Integration Guide](docs/webhooks/README.md)** - Complete guide for webhook setup
  - **[Slack](docs/webhooks/slack.md)** - Slack integration with color-coded attachments
  - **[Discord](docs/webhooks/discord.md)** - Discord integration with rich embeds
  - **[Telegram](docs/webhooks/telegram.md)** - Telegram bot integration
  - **[Lark/Feishu](docs/webhooks/lark.md)** - Lark/Feishu integration with interactive cards
  - **[Custom Webhooks](docs/webhooks/custom.md)** - Any webhook-compatible service
  - **[Configuration](docs/webhooks/configuration.md)** - Retry, circuit breaker, rate limiting
  - **[Monitoring](docs/webhooks/monitoring.md)** - Metrics and debugging
  - **[Troubleshooting](docs/webhooks/troubleshooting.md)** - Common issues and solutions

## License

GPL-3.0 - See [LICENSE](LICENSE) file for details.

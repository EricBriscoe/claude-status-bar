# AI Status Bar

A lightweight macOS menu bar app that shows the real-time status of Claude and OpenAI services.

## Features

- Color-coded status dot in the menu bar (green/yellow/orange/red)
- Switch between **Claude** and **OpenAI** status with one click
- Per-service status breakdown (API, ChatGPT, Claude Code, Codex, etc.)
- Active incident details with latest updates
- Auto-refreshes every 60 seconds
- Auto-update notifications from GitHub Releases
- Open at Login toggle
- Zero dependencies — pure Swift + AppKit

## Install

### Download

1. Grab the latest `ClaudeStatus.zip` from [Releases](https://github.com/EricBriscoe/claude-status-bar/releases)
2. Unzip and move `ClaudeStatus.app` to Applications
3. Remove the quarantine flag (required for unsigned apps):
   ```
   xattr -d com.apple.quarantine /Applications/ClaudeStatus.app
   ```
4. Open the app

### Build from Source

Requires Swift 5.9+ and macOS 13+.

```bash
git clone https://github.com/EricBriscoe/claude-status-bar.git
cd claude-status-bar
make install
```

Or to just build and run without installing:

```bash
make run
```

## Requirements

- macOS 13 (Ventura) or later

## How It Works

Polls the [Claude](https://status.claude.com) or [OpenAI](https://status.openai.com) status page API every 60 seconds and displays the overall system health as a colored dot in your menu bar. Click the dot to see per-service status, active incidents, switch providers, and more.

Both status pages use the same [Atlassian Statuspage](https://www.atlassian.com/software/statuspage) API format, so adding more providers is straightforward.

## License

[MIT](LICENSE)

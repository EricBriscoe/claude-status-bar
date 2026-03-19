# Claude Status Bar

A lightweight macOS menu bar app that shows the real-time status of Claude services.

## Features

- Color-coded status dot in the menu bar (green/yellow/orange/red)
- Per-service status breakdown (claude.ai, API, Claude Code, etc.)
- Active incident details with latest updates
- Auto-refreshes every 60 seconds
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

Polls the [Claude status page](https://status.claude.com) API every 60 seconds and displays the overall system health as a colored dot in your menu bar. Click the dot to see per-service status, active incidents, and controls.

## License

[MIT](LICENSE)

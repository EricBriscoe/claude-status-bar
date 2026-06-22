# AI Status Bar

A lightweight macOS menu bar app that shows the real-time status of Claude and OpenAI services, with optional usage cost tracking.

## Features

- **Color-coded status dot**: green (operational), yellow (degraded), orange (partial outage), red (major outage), blue (maintenance)
- **Switch providers**: toggle between Claude and OpenAI status with one click
- **Per-service breakdown**: see the status of individual services (API, Console, Claude Code, ChatGPT, Codex, etc.)
- **Active incidents**: view incident names, impact level, and the latest status update
- **Plan usage limits**: optional display of your Claude Pro/Max session and weekly usage percentages with reset timers
- **Usage cost tracking**: optional Claude Code & Codex cost/token display via [ccusage](https://github.com/ryoppippi/ccusage)
- **Auto-refresh**: status polls every 60 seconds, usage data every 5 minutes
- **Auto-update**: checks GitHub Releases every 6 hours with skip-version option
- **Open at Login**: native macOS login item via ServiceManagement
- **Keyboard shortcuts**: Refresh (⌘R), Open Status Page (⌘O), Quit (⌘Q)
- **Zero dependencies**: pure Swift + AppKit, universal binary (arm64 + x86_64)

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

Both status pages use the same [Atlassian Statuspage](https://www.atlassian.com/software/statuspage) API format. Add a provider by extending `StatusProvider`.

## Plan Usage Limits (Optional)

Shows your Claude Pro/Max plan usage directly in the menu bar: session utilization, weekly limits, and reset timers.

**How it works:** The app reads your active session from the Claude desktop app's local data to authenticate with `claude.ai` and fetch your current usage limits. This uses the same session your Claude desktop app is already logged into.

**Enable it:** Click the status dot and toggle **"Show Plan Usage"**. The menu bar will show your weekly utilization percentage (e.g. `64%`), and the dropdown shows a full breakdown:

```
Plan Usage Limits
  Session:  11% • resets in 42 min
  Weekly:   64% • resets Mon 12:00 PM
  Sonnet:    0% • resets Tue 9:00 AM
```

**Requirements:**
- The Claude desktop app must be installed and logged in
- On first use, macOS will prompt you to allow Keychain access to "Claude Safe Storage". Click **Allow**

**Security & privacy:**
- Your session cookie is read from the Claude desktop app's local encrypted cookie database and decrypted using a key stored in your macOS Keychain
- The cookie is sent **only** to `claude.ai` over HTTPS via an ephemeral connection (no disk cache, no persistent storage)
- Cross-domain redirects are blocked to prevent cookie leakage
- The session cookie is never logged, written to disk, or sent to any third party
- This feature uses an unofficial claude.ai API endpoint and may be affected by changes to Claude's web interface

Usage data refreshes every 2 minutes. If the Claude app isn't installed or your session expires, the app shows an error. Open Claude to refresh your session.

## Usage Tracking (Optional)

The app can display your Claude Code and OpenAI Codex usage costs directly in the menu bar using [ccusage](https://github.com/ryoppippi/ccusage).

**Prerequisites:** [Node.js](https://nodejs.org) (for `npx`) or [Bun](https://bun.sh) (for `bunx`)

**Enable it:** Click the status dot and toggle **"Show Today's Usage"** and/or **"Show 90d Usage"**. The app will run:

- `npx ccusage@latest daily --json`: for Claude Code costs
- `npx @ccusage/codex@latest daily --json`: for OpenAI Codex costs

When enabled, the menu bar shows a compact cost figure next to the status dot (e.g. `$4.2/$127`). The dropdown menu shows a full breakdown with both cost and token counts for today and the last 90 days.

Usage data refreshes every 5 minutes. If Node.js/Bun isn't installed, the app works normally; usage tracking is unavailable until the prerequisites are met.

## License

[MIT](LICENSE)

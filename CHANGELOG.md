# Changelog

## [1.0.0] - 2026-03-24

### Added
- Menu bar status dot with color-coded health indicator (green/yellow/orange/red/blue)
- Per-service status breakdown with emoji indicators
- Active incident display with latest update preview
- Switch between Claude and OpenAI status providers
- Claude Code & OpenAI Codex usage cost tracking via ccusage
- Today's cost and 90-day cost displayed in menu bar and dropdown
- Token count display in dropdown menu
- Auto-refresh every 60 seconds, usage data every 5 minutes
- Auto-update checker via GitHub Releases (checks every 6 hours)
- Skip version option for update notifications
- Open at Login toggle via ServiceManagement
- Keyboard shortcuts (⌘R refresh, ⌘O open status page, ⌘Q quit)
- Universal binary (arm64 + x86_64)
- Graceful fallback when Node.js/Bun is not installed

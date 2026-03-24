# Changelog

## [1.2.0] - Unreleased

### Added
- Claude Code & OpenAI Codex usage cost tracking via ccusage
- Today's cost and 90-day cost displayed in menu bar and dropdown
- Independent toggles for today and 90d usage display
- Token count display in dropdown menu
- Graceful fallback when Node.js/Bun is not installed

## [1.1.0] - 2026-03-18

### Added
- OpenAI status provider — switch between Claude and OpenAI with one click
- Auto-update checker via GitHub Releases (checks every 6 hours)
- Skip version option for update notifications

### Changed
- Extracted shared `JSONDecoder.snakeCase` extension
- DRY refactoring of fetch logic and timer cleanup

### Fixed
- Handle missing `incidents` key in OpenAI status response

## [1.0.0] - 2026-03-18

### Added
- Menu bar status dot with color-coded health indicator
- Per-service status breakdown with emoji indicators
- Active incident display with latest update preview
- Auto-refresh every 60 seconds
- Open at Login toggle via ServiceManagement
- Universal binary (arm64 + x86_64)

# AI Status Bar

macOS menu bar app showing real-time Claude/OpenAI service status with optional usage cost tracking.

**Repo:** `EricBriscoe/claude-status-bar` on GitHub

## Build & Test

```bash
make build   # compile universal binary (arm64 + x86_64)
make app     # build + assemble .app bundle
make run     # build + launch — use this to manually verify changes
make install # build + copy to /Applications
make clean   # remove build artifacts
```

Requires Swift 5.9+, macOS 13+, Xcode Command Line Tools.

There are no automated tests. Verify changes by running `make run` and confirming:
1. Status dot appears in the menu bar with correct color
2. Dropdown shows per-service status and active incidents
3. Provider switching works (Claude ↔ OpenAI)
4. Usage toggles work if Node.js/Bun is installed
5. Keyboard shortcuts work (⌘R refresh, ⌘O open page, ⌘Q quit)

## Releasing a New Version

1. Bump the version string in all three locations:
   - `Sources/UpdateChecker.swift` → `static let appVersion = "X.Y.Z"`
   - `Info.plist` → both `CFBundleVersion` and `CFBundleShortVersionString`
   - `CHANGELOG.md` → add a new section at the top
2. Commit the version bump
3. Tag and push:
   ```bash
   git tag vX.Y.Z && git push origin main --tags
   ```
4. GitHub Actions (`.github/workflows/release.yml`) automatically builds a universal binary, packages `ClaudeStatus.app` into `ClaudeStatus.zip`, and creates a GitHub Release with the zip attached.

## Architecture

- `Sources/main.swift` — app entry point, sets up NSApplication as accessory (no dock icon)
- `Sources/MenuBarController.swift` — owns the NSStatusItem, builds the dropdown menu, coordinates all UI
- `Sources/StatusProvider.swift` — enum of status providers (Claude, OpenAI); each provides an Atlassian Statuspage API URL
- `Sources/Models.swift` — Codable models for the Statuspage API + shared `JSONDecoder.snakeCase`
- `Sources/UsageModels.swift` — Codable models for ccusage JSON output; `CostBearing` protocol for shared cost resolution
- `Sources/UsageTracker.swift` — polls `npx ccusage` for cost/token data; resolves npx/bunx from login shell PATH
- `Sources/UpdateChecker.swift` — checks GitHub Releases API for newer versions

## Conventions

- No external dependencies — pure Swift + AppKit
- No comments unless they explain non-obvious logic
- Keep code DRY; extract shared patterns into helpers
- Version must be kept in sync across `UpdateChecker.appVersion`, `Info.plist` (both keys), and `CHANGELOG.md`
- All status providers use the Atlassian Statuspage API format — add new ones by extending the `StatusProvider` enum
- Commit messages: imperative mood, leading with what changed and why

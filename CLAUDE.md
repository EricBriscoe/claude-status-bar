# AI Status Bar

macOS menu bar app showing real-time Claude/OpenAI service status with optional usage cost tracking.

## Build

```bash
make build   # compile universal binary (arm64 + x86_64)
make app     # build + assemble .app bundle
make run     # build + launch
make install # build + copy to /Applications
make clean   # remove build artifacts
```

Requires Swift 5.9+, macOS 13+, Xcode Command Line Tools.

## Architecture

- `Sources/main.swift` — app entry point, sets up NSApplication as accessory (no dock icon)
- `Sources/MenuBarController.swift` — owns the NSStatusItem, builds the dropdown menu, coordinates all UI
- `Sources/StatusProvider.swift` — enum of status providers (Claude, OpenAI); each provides an Atlassian Statuspage API URL
- `Sources/Models.swift` — Codable models for the Statuspage API + shared `JSONDecoder.snakeCase`
- `Sources/UsageModels.swift` — Codable models for ccusage JSON output
- `Sources/UsageTracker.swift` — polls `npx ccusage` for cost/token data; resolves npx/bunx from login shell PATH
- `Sources/UpdateChecker.swift` — checks GitHub Releases API for newer versions

## Conventions

- No external dependencies — pure Swift + AppKit
- No comments unless they explain non-obvious logic
- Keep code DRY; extract shared patterns into helpers
- Version must be kept in sync across `UpdateChecker.appVersion`, `Info.plist` (both keys), and `CHANGELOG.md`
- All status providers use the Atlassian Statuspage API format — add new ones by extending the `StatusProvider` enum

# Contributing

## Prerequisites

- Swift 5.9+
- macOS 13 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)

## Getting Started

```bash
git clone https://github.com/EricBriscoe/claude-status-bar.git
cd claude-status-bar
make run
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make build` | Compile universal binary (arm64 + x86_64) |
| `make app` | Build and assemble the .app bundle |
| `make run` | Build and launch the app |
| `make install` | Build and copy to /Applications |
| `make clean` | Remove build artifacts |

## Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b my-feature`)
3. Make your changes
4. Test by running `make run` and verifying the menu bar behavior
5. Commit and push to your fork
6. Open a Pull Request

## Code Style

- No comments unless they explain non-obvious logic
- Keep code DRY — extract shared patterns into helpers
- Follow existing conventions in the codebase
- No external dependencies — pure Swift + AppKit

## Adding a Status Provider

Status providers are defined in `Sources/StatusProvider.swift`. Both Claude and OpenAI use the [Atlassian Statuspage](https://www.atlassian.com/software/statuspage) API format. To add a new provider:

1. Add a case to the `StatusProvider` enum
2. Provide `displayName`, `apiURL`, and `pageURL`
3. The rest of the app picks it up automatically

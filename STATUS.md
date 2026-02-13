# Status

## In Progress

- None.

## Completed

- Improve `container` executable discovery and error guidance when the CLI is missing.
- Make all buildable targets use Swift 6 mode and macOS 26.2 deployment.
- Resolve strict-concurrency diagnostics introduced by Swift 6 mode.
- Implement Docker CLI parity surface in the desktop app with command catalog + custom command runner/streaming.
- Expand tests with app-level unit tests and dedicated UI-surface tests.
- Verify with `swift test` and `xcodebuild test`.
- Implement CR-001 alignment updates for the container-first MVP (imports/hashability fixes, `container exec` terminal actions, Apple Events usage description, and verification).
- Add Docker API-compatible command translation on top of Apple `container` and implement a dedicated Compose workflow/UI.
- Add automated Docker CLI compatibility contract tests using a fake `container` executable (command mapping order, fallback behavior, and Compose fallback) and fix non-fallback error handling in the compatibility runner.

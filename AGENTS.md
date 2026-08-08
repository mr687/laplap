# laplap — macOS Keyboard Lock Utility

Read CONVENTIONS.md before any GitHub or git operation.

<!-- BEGIN bigpowers:project -->
## Project

macOS utility that locks keyboard, trackpad, and mouse so a cat on the desk cannot type or click.
Two modes:
- **cat** — screen stays visible, all input ignored. Exit: press CMD 6 times within 10 seconds.
- **clean** — same input lock plus a fullscreen black overlay with centered exit instructions. Exit: press CMD 6 times within 10 seconds.

Stack: Swift (SwiftPM), macOS 13+, zero external dependencies. Install via `install.sh`.

## Commands

| Action | Command |
|--------|---------|
| Run    | `swift run laplap cat` / `swift run laplap clean` |
| Test   | `swift test` |
| Build  | `swift build -c release` |
| Lint   | none (zero-dependency project) |
| Preflight | `swift test && swift build` |
| Install | `./install.sh` |
| CI     | `gh pr checks` (when a PR is open) |

## Architecture

`Sources/laplap/main.swift` — argument parsing and mode dispatch.
`InputBlocker` — CGEventTap that consumes keyboard/mouse events and detects the CMD×6 unlock gesture.
`OverlayController` — NSApplication windows: corner status badge (cat mode), fullscreen black overlay (clean mode).
`install.sh` — builds release binary and installs to `~/.local/bin`.

## Conventions

- Swift API Design Guidelines. No external dependencies, ever.
- All planning and specs live in `specs/` before code.
- Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`.
- Any change touching the unlock gesture MUST keep the fail-safe: process exit restores input.
- Accessibility permission (CGEventTap) is required; missing permission must produce a clear message, never a silent failure.

## Never

- Never dismiss reproducible gate failures as pre-existing or out of scope.
- Never proceed on red Preflight or red CI — invoke quick-fix or fix-bug first.
- Never log, record, or transmit keystrokes or other input events. This tool only consumes them.
- Never add file operations to clean mode — it is a visual lock, it deletes nothing.
- Never remove or weaken the CMD×6 exit path, and never make the lock survive process death.
- Never add network access or telemetry.
<!-- END bigpowers:project -->

<!-- BEGIN bigpowers:context-routing -->
## Context Routing

| Glob | File |
|------|------|
| — | (single-module project; no sub-AGENTS.md needed) |
<!-- END bigpowers:context-routing -->

<!-- BEGIN bigpowers:learned-preferences -->
## Learned User Preferences

_None recorded yet._

## Workspace Facts

_None recorded yet._
<!-- END bigpowers:learned-preferences -->

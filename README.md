# laplap

Cat-proof input lock for macOS. One command makes the keyboard, trackpad, and
mouse ignore all input — so a cat walking on the desk cannot type or click.

## Features
- cat — lock input, screen stays visible; status badge with live ⌘ n/6 unlock progress
- clean — lock input behind fullscreen black overlays; cursor hidden; progress shown
- settings — open System Settings → Privacy & Security → Accessibility to grant permission
- Fail-safe: the lock lives only in the running process — kill it and input returns instantly

## Requirements
- macOS 13+
- Swift 6 toolchain (to build from source)
- Accessibility permission (one-time, see Permissions)

## Install
```sh
./install.sh   # builds release and installs to ~/.local/bin/laplap (falls back to /usr/local/bin)
```

Re-running the installer simply overwrites the previous install (idempotent).
No Homebrew, no code signing, no daemon.

Or build manually:

```sh
swift build -c release
cp .build/arm64-apple-macosx/release/laplap ~/.local/bin/   # path may be .build/release on Intel
```

## Usage
```sh
laplap cat      # lock all input, screen visible
laplap clean    # lock all input, black overlay on every display
laplap settings # open System Settings to grant Accessibility permission
laplap --help   # usage, exit codes
```

Unlock: press Command 6 times within 10 seconds (⌘×6) — the badge/overlay shows your progress.
Exit codes: 0 ok, 1 could not open System Settings, 2 usage error, 3 permission missing.

## Permissions
laplap needs the Accessibility permission to intercept input (CGEventTap).
First run without it prints guidance; `laplap settings` opens the right pane for you.
Grant it for laplap or your terminal app in System Settings → Privacy & Security → Accessibility.

## How it works
A single CGEventTap at the HID level consumes every keyboard/trackpad/mouse
event while running. Unlock is detected inside the tap before events are
consumed. Nothing is logged, recorded, or sent anywhere; there is no daemon
and no persistence — process death restores input.

## Development
- Swift 6, SwiftPM, zero external dependencies (Foundation, CoreGraphics, AppKit)
- swift test — 96 headless tests; no accessibility grant or real HID needed
- Architecture: docs in specs/ (AGENTS.md has the overview)

## License
MIT — see LICENSE.

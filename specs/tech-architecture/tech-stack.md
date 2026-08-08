# Tech Stack — laplap

## Language & Runtime
- Swift 6, SwiftPM executable target `laplap`, target macOS 13+
- Zero external dependencies: Foundation, CoreGraphics, AppKit only

## Architecture
- Sources/laplap/main.swift — argument parsing (cat|clean|--help), mode dispatch, exit codes (0 ok, 2 usage, 3 permission missing)
- InputBlocker — CGEventTap at kCGHIDEventTap; callback returns nil to consume every keyboard/trackpad/mouse event; feeds UnlockCounter; tap failure or nil callback pointer → run loop exits (fail-safe)
- UnlockCounter — counts Command key-down transitions (either side, keyCodes 54/55) via flagsChanged events; 6 presses within rolling 10-second window unlocks; stale presses expire
- OverlayController — AppKit NSApplication; cat mode: small corner badge window (floating level, ignoresMouseEvents); clean mode: one black fullscreen NSWindow per NSScreen at screenSaver level with centered exit text, cursor hidden via CGDisplayHideCursor, restored on exit
- PermissionPrompter — AXIsProcessTrusted / AXIsProcessTrustedWithOptions(.setRights); opens System Settings privacy pane when missing
- install.sh — swift build -c release → ~/.local/bin/laplap (fallback /usr/local/bin), idempotent

## Invariants
- Lock lives only in the running process; process death restores input with no cleanup
- Single blocking layer: one event tap, never a second
- No persistence, no config files, no network, no input logging
- Unlock gesture detectable inside the tap before events are consumed

## Key APIs
- CGEventTapCreate, CGEventTapEnable, CGEventSourceCreate, CFRunLoopRun
- CGEventType.flagsChanged, kCGEventFlagMaskCommand, keyCode 54/55
- AXIsProcessTrusted, AXIsProcessTrustedWithOptions
- CGDisplayHideCursor / CGDisplayShowCursor
- NSWindow levels: NSWindow.Level.floating (badge), .screenSaver (clean overlay)

## Test Strategy
- Headless XCTest: construct CGEvent objects directly and invoke the tap callback — no accessibility grant or real HID needed
- UnlockCounter unit tests: synthetic flagsChanged events, window expiry via injected clock
- ArgParser tests: mode dispatch and exit codes
- UI overlay smoke: manual verification script (verify-script) in story specs, not unit tests

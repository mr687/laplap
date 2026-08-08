# e01s01 — Tracer bullet: laplap cat locks input, CMDx6 unlocks

### Story [1.1]: Tracer bullet: laplap cat locks input, CMDx6 unlocks — Implementation Steps

**type:** feat
**risk:** P0
**context:** domain

**Context**: This is the tracer bullet for the whole laplap product. It proves the
core loop end to end: `laplap cat` consumes every keyboard, trackpad, and mouse
event through a single `CGEventTap` at `kCGHIDEventTap`, detects the unlock
gesture (Command pressed 6 times within a rolling 10-second window) inside the
tap callback before events are consumed, and exits 0 on unlock. Fail-safe is
structural: the lock exists only in the running process; tap failure or a NULL
callback pointer exits the run loop so input returns immediately. Permission is
gated minimally here (clear message, exit 3) — the rich prompt flow is epic e03
and is explicitly out of scope. Everything below the AppKit activation layer is
headless-testable with injected `CGEvent` objects and an injected clock, so no
real HID device or Accessibility grant is required for `swift test`.

## Steps

1. Scaffold SwiftPM package: `Package.swift` (Swift 6, macOS 13+, zero external deps), `Sources/laplap/main.swift` stub, `Tests/laplapTests/` test target → verify: `swift build`
2. Implement `ArgParser`: accept `cat`, `clean`, `--help`; unknown mode prints usage to stderr and exits 2 → verify: `swift test`
3. Implement permission gate: `AXIsProcessTrusted()` false → print exact guidance message, exit code 3 → verify: `swift test`
4. Implement `UnlockCounter`: Command key-down transitions only (keyCodes 54/55, either side), 6 presses within rolling 10s window → unlocked, stale presses expire, no overflow; injected clock for headless expiry tests → verify: `swift test`
5. Implement `InputBlocker`: `CGEventTapCreate` at `kCGHIDEventTap`, callback returns nil to consume every event, feeds `UnlockCounter` before consuming; tap failure or NULL callback → run loop exits (fail-safe); callback invokable headless with constructed `CGEvent` objects → verify: `swift test && swift build`
6. Wire cat mode end-to-end: `main` runs run loop with tap enabled, unlock exits 0, SIGTERM/SIGINT exit cleanly (input restored by process exit) → verify: `swift test && swift build`
7. Set `NSApplication` activation policy to `.accessory` (no Dock icon) in cat mode → verify: `swift build`
8. Human smoke: run `swift run laplap cat`, confirm real input locked and CMDx6 unlocks → verify: verify-script: 1, 2, 3, 4 (manual steps below)

## Verification Script (Step-by-Step)

1. Run the binary: `swift run laplap cat` from a terminal (grant Accessibility
   permission to the terminal if prompted; first run without permission must
   print the guidance message and exit 3 instead).
2. Observation: with the process running, typing in any other app has no effect;
   trackpad clicks and cursor drags do nothing; moving an external mouse does
   not move the cursor.
3. Observation: press Command (either side) 6 times within 10 seconds — the
   process exits with code 0 and all input works again immediately.
4. Observation: kill the process from another terminal (`kill <pid>`) — input
   returns immediately with no cleanup step (fail-safe).

## Out of scope

- Rich Accessibility permission prompt / System Settings handoff (epic e03)
- `laplap clean` overlay behavior (epic e02) — ArgParser must accept `clean` but
  no lock behavior is wired for it in this story
- Hotkey/configurable unlock gesture, custom gestures, daemon, login-item
  auto-start, persistence, config files, input logging, network access

## Risks

- Tap silently fails to create (no permission, no HID tap available): detect via
  nil return from `CGEventTapCreate` → unit test asserting run loop exits; exit
  code 3 path covered by permission-gate test.
- Unlock gesture misfires: cat mashing Command could unlock, or a legit unlock
  could fail. Detect via UnlockCounter unit tests: 6-down window, stale expiry,
  key-up exclusion, only keyCodes 54/55 counted.
- Callback becomes NULL (tap dies mid-run) leaving input permanently locked:
  covered by fail-safe test — NULL callback exits the run loop.
- Counter overflow / unbounded memory: fixed-size ring of timestamps with
  explicit overflow test.
- End-to-end wiring breaks headless tests: tap callback must be invokable with
  constructed CGEvent objects — no real HID in tests; any test that requires a
  grant or device is a defect in this story.

## Requirements

- **[ADDED] REQ-1 — SwiftPM executable target**: Package builds a Swift 6
  executable target `laplap` for macOS 13+ with zero external dependencies
  (Foundation, CoreGraphics, AppKit only) and a test target; `swift build`
  succeeds.
- **[ADDED] REQ-2 — Argument parsing**: `laplap cat`, `laplap clean`, and
  `laplap --help` are accepted; any unknown mode prints usage to stderr and
  exits with code 2.
- **[ADDED] REQ-3 — Permission gate (minimal)**: when `AXIsProcessTrusted()`
  is false, laplap prints a clear guidance message and exits with code 3. No
  prompt flow in this story.
- **[ADDED] REQ-4 — Unlock gesture counting**: the unlock gesture is Command
  (either side, keyCodes 54/55) key-down transitions only, 6 presses within a
  rolling 10-second window; stale presses expire; the counter is overflow-safe;
  the clock is injectable so all of this is testable headless.
- **[ADDED] REQ-5 — Input blocking**: a single `CGEventTap` at `kCGHIDEventTap`
  consumes every keyboard/trackpad/mouse event by returning nil from the
  callback; the callback feeds UnlockCounter before consuming; tap creation
  failure or a NULL callback exits the run loop (fail-safe).
- **[ADDED] REQ-6 — Cat mode lifecycle**: `laplap cat` runs the run loop with
  the tap enabled, exits with code 0 on unlock, and exits cleanly on
  SIGTERM/SIGINT; the lock lives only in the running process.
- **[ADDED] REQ-7 — Accessory activation**: NSApplication runs with
  `.accessory` activation policy so no Dock icon appears in cat mode.

## Acceptance Criteria

- **AC-1**: `swift build` succeeds and produces the `laplap` executable
  (task 1, P0).
- **AC-2**: ArgParser unit tests pass: `cat`, `clean`, `--help` accepted;
  unknown mode → usage on stderr, exit 2 (task 2, P1).
- **AC-3**: Permission gate unit test passes: `AXIsProcessTrusted() == false` →
  exact guidance message, exit code 3 (task 3, P0).
- **AC-4**: UnlockCounter unit tests pass: Command key-down counting, 6-within-
  10s unlock, stale-press expiry, no overflow, injected clock (task 4, P0).
- **AC-5**: InputBlocker tests + build pass: tap consumes events (nil return),
  feeds UnlockCounter, tap failure / NULL callback exits run loop; callback is
  invokable headless with constructed CGEvent objects (task 5, P0).
- **AC-6**: Cat mode end-to-end: run loop starts, tap consumes input, unlock
  exits 0, SIGTERM/SIGINT exit cleanly — `swift test && swift build` pass and
  manual smoke (verify-script 1–4) confirms real input is locked and restored
  (task 6, P0).

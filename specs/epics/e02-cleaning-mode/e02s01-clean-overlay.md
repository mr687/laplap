### Story [2.1]: Fullscreen black overlay + hidden cursor + CMDx6 exit — Implementation Steps

**type:** feat
**risk:** P0
**context:** domain
**Context**: `laplap clean` reuses the e01 input lock (single `CGEventTap` at `kCGHIDEventTap` consuming all HID events, CMDx6 unlock within a rolling 10-second window — see e01s01, do not re-plan) and adds a fullscreen black overlay on every display with centered "press CMD 6 times to exit" text, plus a hidden cursor while armed. One `NSWindow` per `NSScreen` at `NSWindow.Level.screenSaver` with `ignoresMouseEvents`, rebuilt on `NSScreen.didChangeNotification`. Cursor hidden via `CGDisplayHideCursor` on arm, restored via `CGDisplayShowCursor` on every exit path (unlock, SIGTERM). Unlock restores cursor, closes all overlays, exits 0. Overlay window configuration (count, level, `ignoresMouseEvents`, label text) must be unit-testable headless where possible; the visual smoke is manual via verify-script.

## Requirements

- REQ-1 (ADDED): Clean mode arms one black fullscreen `NSWindow` per `NSScreen` at `NSWindow.Level.screenSaver` with `ignoresMouseEvents`; overlays are re-created on `NSScreen.didChangeNotification`.
- REQ-2 (ADDED): Each overlay shows a centered instruction label "CLEANING MODE — press CMD 6 times to exit", plain white text on black.
- REQ-3 (ADDED): Cursor hidden via `CGDisplayHideCursor` while clean mode is armed (clean mode only) and restored via `CGDisplayShowCursor` on every exit path, including SIGTERM.
- REQ-4 (ADDED): CMDx6 unlock (rolling 10-second window, e01 semantics) restores the cursor, closes all overlays, and exits with code 0.

## Acceptance Criteria

- AC-1: Overlay window configuration is headless-testable and correct — one window per `NSScreen`, level `.screenSaver`, `ignoresMouseEvents`, rebuilt on `NSScreen.didChangeNotification`; `swift test && swift build` passes.
- AC-2: Each overlay renders the centered label "CLEANING MODE — press CMD 6 times to exit" as plain white text on black; `swift test` passes.
- AC-3: Cursor hide/show is scoped to clean mode and restored on all exit paths including SIGTERM; `swift test` passes.
- AC-4: `laplap clean` runs end-to-end — input lock + overlays + hidden cursor; CMDx6 unlock restores cursor, closes overlays, exits 0; `swift test && swift build` passes and manual smoke confirms on real displays.

## Steps

1. Create `OverlayController` with a headless-testable configuration value: `OverlayConfig` carrying window level `.screenSaver`, `ignoresMouseEvents = true`, black background color, and the label text constant `"CLEANING MODE — press CMD 6 times to exit"`; expose `windowCount` derived from `NSScreen.screens.count` (injectable for tests) → verify: `swift test`
2. Implement arm: for each `NSScreen`, create one borderless `NSWindow` sized to the screen frame, black background, level `.screenSaver`, `ignoresMouseEvents = true`, ordered front; register an `NSScreen.didChangeNotification` observer that tears down and re-creates all overlays on the main queue → verify: `swift test`
3. Add the centered label: each overlay window hosts an `NSTextField` with the instruction text, white text on black, centered in the window frame via constraints or frame math; expose the configured text/color for unit tests → verify: `swift test`
4. Add cursor control scoped to clean mode: on arm call `CGDisplayHideCursor` for each screen's `CGDirectDisplayID` and record that clean mode hid it; expose `restoreCursor()` that calls `CGDisplayShowCursor` only when clean mode armed it → verify: `swift test`
5. Restore cursor and tear down overlays on every exit path: wire `restoreCursor()` + overlay teardown into the unlock path and a `SIGTERM` handler so killing the process from another terminal restores input immediately (fail-safe) → verify: `swift test`
6. Wire clean mode end-to-end in `main.swift`: `laplap clean` reuses the e01 `InputBlocker`/`UnlockCounter` lock (reference e01s01 — no re-planning of the lock), arms overlays and hides cursor; on unlock restore cursor, close overlays, exit 0 → verify: `swift test && swift build`
7. Manual smoke on real displays: overlay covers every screen, label centered, cursor hidden, CMDx6 exits and restores → verify-script: steps 1–8 of the Verification Script below

## Verification Script (Step-by-Step)

1. Action: Build and run `swift run laplap clean` on a machine with at least one real display.
2. Observation: every display is covered by a fullscreen black overlay; centered white text reads "CLEANING MODE — press CMD 6 times to exit"; cursor is invisible; typing, trackpad, and mouse have zero effect.
3. Action: press the Command key (either side) 6 times within a rolling 10-second window.
4. Observation: overlays close, cursor reappears, and the process exits with code 0 (`echo $?` prints `0`).
5. Action: repeat on a multi-display setup (2+ screens); while armed, unplug one monitor.
6. Observation: an overlay appears on each screen with the label centered on each; after unplugging, the overlay set rebuilds for the remaining screen without user action.
7. Action: arm clean mode again, then from another terminal run `kill -TERM $(pgrep laplap)`.
8. Observation: cursor is restored, overlays disappear, and input works immediately — no cleanup step required.

## Out of scope

- File deletion or disk cleanup — clean mode is visual-only by design
- Sound effects, countdown timer, or pre-exit warning animation
- Customizable exit gesture or hotkey config — fixed CMDx6 gesture
- CAT MODE status badge or any CAT MODE visual changes (e01)
- Accessibility permission flow (e03), installer and `--help` polish (e04)
- Persistent daemon, login-item auto-start, or lock surviving process death

## Risks

- Multi-display race: `NSScreen.didChangeNotification` firing while the event tap is consuming input; overlay rebuild must be dispatched to the main queue so the run loop never blocks.
- Missed cursor restore on an unexpected exit path leaves the cursor hidden after process death; mitigated by the SIGTERM handler plus an unconditional restore on the exit path — every path must be tested.
- `CGDisplayHideCursor`/`CGDisplayShowCursor` are per-display-ID; hide must be issued per screen and restore must pair with the same IDs so every display's cursor comes back.
- Wiring regression on the shared e01 input lock: clean mode must not alter tap behavior or CMDx6 rolling-window semantics.
- `.screenSaver`-level windows cover system UI while armed; acceptable because overlays ignore mouse events and CMDx6 unlock always works while the process runs.

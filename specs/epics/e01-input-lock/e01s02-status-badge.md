# e01s02 — Status badge window in cat mode

### Story e01s02: Status badge window in cat mode — Implementation Steps

**type:** feat
**risk:** P2
**context:** domain

**Context**: While `laplap cat` is armed, the user (and the cat) needs visible
feedback that the lock is active — otherwise the screen looks frozen and the
owner may panic. This story adds a small, semi-transparent AppKit pill window in
the top-right corner of the main screen showing "CAT MODE — CMD x6 to exit". The
badge is purely informational: it is mouse-transparent (`ignoresMouseEvents`),
floats above normal windows but never blocks input, appears only in cat mode,
disappears on unlock/exit, and is released on exit so the process can terminate.
All verification of the visible behavior is manual (verify-script) — badge
rendering is not unit-testable headless; what IS testable headless is that the
badge is only ever created in cat mode and torn down on exit.

## Steps

1. Implement `BadgeView`: small semi-transparent `NSWindow` pill "CAT MODE — CMD x6 to exit", `ignoresMouseEvents = true`, `NSWindow.Level.floating`, top-right of main screen (`NSScreen.main`), borderless, non-activating → verify: `swift build`
2. Create badge only when cat mode starts; hide/close on unlock or exit; release window reference on exit so process can terminate without lingering window server connection → verify: `swift build`
3. Wire badge lifecycle to cat-mode run loop: badge visible exactly while input is locked, gone before process exits → verify: `swift test && swift build`
4. Human smoke: run `swift run laplap cat`, confirm badge appears, never intercepts clicks, disappears on unlock → verify: verify-script: 1, 2, 3, 4 (manual steps below)

## Verification Script (Step-by-Step)

1. Run the binary: `swift run laplap cat` (terminal already has Accessibility
   permission from e01s01 smoke).
2. Observation: a small semi-transparent pill reading "CAT MODE — CMD x6 to
   exit" appears in the top-right corner of the main screen, above other windows
   but not fullscreen.
3. Observation: clicking/tracking directly over the badge area does nothing —
   the badge never intercepts mouse events; input stays locked.
4. Observation: press Command 6 times within 10 seconds — the process exits
   with code 0 and the badge disappears with it (no stray window left behind;
   the process terminates cleanly, confirming the window was released).

## Out of scope

- Clean-mode black fullscreen overlay, exit text, cursor hiding (epic e02)
- Badge on every display (main screen only in this story)
- Configurable badge text, position, opacity, or styling
- Menu bar item, Dock icon, notifications, any non-NSWindow presentation

## Risks

- Badge window keeps the process alive after unlock (window not released): the
  process would hang on exit. Detect via verify-script 4 — process must exit
  promptly with code 0; keep a single owned window reference released in the
  exit path.
- Badge intercepts mouse events (ignoresMouseEvents misapplied): a locked cat
  could appear to move the cursor. Detect via verify-script 3 — clicks over the
  badge must have zero effect; assert the property is set before display.
- Badge appears in non-cat modes or clean mode: creation is gated on cat-mode
  entry in the run loop; step 3 build/test catches wiring regressions.
- Badge off-screen or wrong screen on multi-display setups: anchored to
  `NSScreen.main` visibleFrame, clamped inside the screen bounds.

## Requirements

- **[ADDED] REQ-1 — Badge window**: a small semi-transparent borderless
  `NSWindow` pill labeled "CAT MODE — CMD x6 to exit" at the top-right of the
  main screen, at `NSWindow.Level.floating`, with `ignoresMouseEvents = true`
  and no activation.
- **[ADDED] REQ-2 — Badge lifecycle**: the badge appears only while cat mode is
  armed, disappears on unlock/exit, and is released on exit so the process
  terminates cleanly.

## Acceptance Criteria

- **AC-1**: `swift build` succeeds with the badge window implemented per
  REQ-1 — pill label, semi-transparent, `ignoresMouseEvents`, floating level,
  top-right of main screen; manual smoke confirms appearance and
  mouse-transparency (task 1, P2).
- **AC-2**: Badge lifecycle verified — appears only in cat mode, disappears on
  unlock/exit, window released so the process exits cleanly with code 0;
  `swift test && swift build` pass and verify-script 1–4 confirm behavior
  (task 2, P2).

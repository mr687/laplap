# e06s02 — Visual polish: fades and typography

### Story e06s02: Visual polish: fades and typography — Implementation Steps

**type:** feat
**risk:** P2
**context:** domain

**Context**: The badge pops in/out abruptly and the clean overlay's flat text
does not communicate hierarchy. This story adds a 0.15s fade-in on arm and
fade-out before close for the badge and every overlay window, plus a refined
overlay typography hierarchy: a bold title "CLEANING MODE", a subtitle
"Press ⌘ 6 times to exit" at ~0.85 alpha, and the progress line from e06s01
below. The badge baseline label uses the ⌘ glyph. Animations are capped at
0.15s and must never block the run loop or delay unlock meaningfully.

## Requirements

- [ ] (ADDED) REQ-1 — Fades: on arm, after `orderFront`, window `alphaValue`
  starts at 0 and animates to 1 via `NSAnimationContext` (0.15s); on teardown,
  animate to 0 then orderOut/close; total exit time ≤ 0.15s; applied to badge
  and every overlay window; duration constant exposed for tests. — P2
- [ ] (ADDED) REQ-2 — Overlay typography: bold title "CLEANING MODE" (34pt
  white), subtitle "Press ⌘ 6 times to exit" (18pt, white ~0.85 alpha),
  progress line from e06s01; centered and stays centered on screen resize;
  badge baseline uses the ⌘ glyph. — P2
- [ ] (ADDED) REQ-3 — Manual visual smoke steps documented in the story's
  Verification Script. — P3

## Steps

1. Add fade constants (e.g. `fadeDuration: TimeInterval = 0.15`) exposed for tests; badge + overlay windows: after `orderFront`, set `alphaValue = 0`, then `NSAnimationContext.runAnimationGroup(duration: 0.15)` → `alphaValue = 1`. → verify: `swift test && swift build`
2. Teardown: animate `alphaValue` to 0 over 0.15s, then orderOut/close in the completion handler; do not block the run loop; total exit time ≤ 0.15s. → verify: `swift test && swift build`
3. BadgeView: baseline label literal updated to use the ⌘ glyph ("CAT MODE — ⌘ ×6 to exit", same string constant); keep pill style (corner radius, shadow, alpha 0.55 black). → verify: `swift test && swift build`
4. OverlayController: two NSTextFields — title "CLEANING MODE" (bold 34pt white) and subtitle "Press ⌘ 6 times to exit" (regular 18pt, white ~0.85 alpha) — plus the e06s01 progress field; centered stack keeping centering on screen resize. → verify: `swift test && swift build`
5. Tests: initial `alphaValue == 0` after creation with constants asserted; title/subtitle texts asserted; progress field present. → verify: `swift test`
6. Manual visual smoke steps documented (verify-script below). → verify: `swift build`
7. Human smoke: run `laplap cat` — badge fades in, shows ⌘ glyph, fades out on unlock; `laplap clean` — overlay fades in with title/subtitle/progress, stays centered on resize, fades out on unlock. → verify: verify-script: 1, 2, 3, 4 (manual steps below)

## Acceptance Criteria

- **AC-1** (P2, task 1): Badge and every overlay window fade in on arm and fade out before close via NSAnimationContext at the 0.15s constant; initial alphaValue == 0 asserted headless; teardown does not delay unlock beyond 0.15s and does not block the run loop.
- **AC-2** (P2, task 2): Overlay shows bold title "CLEANING MODE" and subtitle "Press ⌘ 6 times to exit" (18pt, ~0.85 alpha) with the progress line below; centered and re-centered on resize; badge baseline uses the ⌘ glyph with the pill style preserved.
- **AC-3** (P3, task 3): Manual visual smoke steps are documented in the Verification Script and executed for both modes.

## Verification Script (Step-by-Step)

1. Run `swift run laplap cat` — the badge fades in (≈0.15s), reads
   "CAT MODE — ⌘ ×6 to exit" with the ⌘ glyph; press Command — the badge shows
   "⌘ n/6" progress; unlock on 6 presses — the badge fades out before the
   process exits with code 0.
2. Run `swift run laplap clean` — every overlay fades in simultaneously with a
   bold "CLEANING MODE" title, a "Press ⌘ 6 times to exit" subtitle, and the
   progress line; resize the screen (or rotate) — text stays centered; unlock
   on 6 presses — overlays fade out and the process exits 0.
3. Observation: no animation exceeds ~0.3s; unlock is not perceptibly delayed.
4. Observation: no sounds, no strobing; badge pill look unchanged apart from
   the glyph and fade.

## Out of scope

- Sounds or haptics
- Animations longer than 0.3s (fade is fixed at 0.15s)
- Configurable styling, colors, or theme files
- Badge on every display
- Any change to unlock semantics, consumption, or exit codes

## Risks

- Animation delaying unlock exit: fade-out is 0.15s and the completion handler
  runs on the main queue without blocking the run loop; unlock semantics
  unchanged (process exits after fade completes).
- Stale display after expiry: progress resets via the e06s01 onProgress path;
  the overlay hides the progress line at 0.
- Text not re-centered on screen resize: autoresizing fill keeps the stack
  centered; verified in smoke step 2.

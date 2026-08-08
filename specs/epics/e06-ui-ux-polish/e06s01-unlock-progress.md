# e06s01 — Live unlock progress in badge and overlay

### Story e06s01: Live unlock progress in badge and overlay — Implementation Steps

**type:** feat
**risk:** P1
**context:** domain

**Context**: Today the badge shows a static "CAT MODE — ⌘ ×6 to exit" and the
clean overlay a static instruction line, so the owner cannot tell how many of
the 6 Command presses have landed or whether the rolling 10-second window has
expired. This story adds live progress: the badge and the clean overlay show
"⌘ n/6" as presses accumulate, resetting to the baseline when the window
expires. Progress is driven by a single `onProgress(count, required)` callback
fired from the input blocker after every event (flagsChanged press or any other
event), so the display always reflects the expiry-aware count and resets
automatically on window expiry. Consumption behavior, unlock semantics
(CMD×6 within 10s), and fail-safe exit codes are unchanged.

## Requirements

- [x] (ADDED) REQ-1 — `UnlockCounter.liveCount`: a computed getter that runs
  window expiry with the injected clock and returns the current in-window press
  count; `register()` is unchanged and still returns the unlock Bool. — P1
- [x] (ADDED) REQ-2 — `InputBlocker.State.onProgress: (Int, Int) -> Void`
  (default no-op), fired after every event with `(liveCount, requiredPresses)`:
  after register/attempt for flagsChanged events and for all other event types,
  so any event refreshes the display and window expiry resets it. — P1
- [x] (ADDED) REQ-3 — Badge live label via `BadgeView.setProgress(_:of:)`:
  count > 0 → "CAT MODE — ⌘ n/6"; count == 0 → baseline "CAT MODE — ⌘ ×6 to
  exit"; BadgeLabel `text` becomes settable and redraws on set. — P1
- [x] (ADDED) REQ-4 — Clean overlay progress line via
  `OverlayController.setProgress(_:of:)`: second NSTextField under the
  instruction label showing "⌘ n/6" while count > 0, hidden at 0; exposed via
  OverlayConfig for headless asserts. — P2
- [x] (ADDED) REQ-5 — Wiring: CatMode sets `blocker.state.onProgress` to update
  the badge label; CleanMode updates the overlay controller; both on the main
  queue. — P1

## Steps

1. Add `var liveCount: Int` to UnlockCounter: computed getter runs `expireStale()` (injected clock) then returns the in-window press count; `register()` unchanged. → verify: `swift test`
2. Unit tests for `liveCount`: presses → count; expiry via injected clock → 0; boundary at exactly 10s. → verify: `swift test`
3. Add `State.onProgress: (Int, Int) -> Void` (default `{ _, _ in }`); in the tap callback fire `onProgress(counter.liveCount, counter.requiredPresses)` after register/attempt for flagsChanged and for every other event type; consumption behavior identical. → verify: `swift test`
4. Unit tests for `onProgress`: each CMD down fires counts 1..6; a non-command event fires with the current count; expiry via injected clock fires 0 (resets display). → verify: `swift test`
5. BadgeLabel: make `text` settable with redraw on set; BadgeView `setProgress(_:of:)`: count > 0 → "CAT MODE — ⌘ \(count)/\(required)", count == 0 → baseline "CAT MODE — ⌘ ×6 to exit". → verify: `swift test && swift build`
6. Badge label tests: `setProgress` updates BadgeLabel.text; 0 restores baseline. → verify: `swift test`
7. OverlayController: add progress NSTextField under the instruction label; `setProgress(_:of:)`: count > 0 → "⌘ \(count)/\(required)" + hidden = false; count == 0 → hidden = true; expose via OverlayConfig. → verify: `swift test && swift build`
8. Overlay progress tests: hidden + text asserted for counts 0 and >0. → verify: `swift test`
9. Wire CatMode: `blocker.state.onProgress` updates badge label (main queue; direct call OK on main run loop thread, DispatchQueue.main.async if Swift 6 isolation requires). → verify: `swift test && swift build`
10. Wire CleanMode: same `onProgress` → overlay controller. → verify: `swift test && swift build`
11. Manual smoke: run `laplap cat`, press CMD repeatedly — badge shows ⌘ 1/6, 2/6 …; wait 10s idle — resets to baseline; 6th press unlocks; repeat for `laplap clean` overlay. → verify: verify-script: 1, 2, 3, 4 (manual steps below)

## Acceptance Criteria

- **AC-1** (P1, task 1): `liveCount` is expiry-aware — returns in-window press count, resets to 0 after window expiry via the injected clock, boundary at exactly 10s handled; all prior UnlockCounter tests still pass.
- **AC-2** (P1, task 2): `onProgress` fires after every event with `(liveCount, requiredPresses)` — CMD downs fire 1..6, non-command events refresh with the current count, expiry resets to 0; consumption behavior unchanged.
- **AC-3** (P1, task 3): Badge shows "CAT MODE — ⌘ n/6" during the gesture and resets to "CAT MODE — ⌘ ×6 to exit" when the window expires; label text is settable and redraws.
- **AC-4** (P2, task 4): Clean overlay shows "⌘ n/6" during the gesture and hides it at 0; updated via the same onProgress path.

## Verification Script (Step-by-Step)

1. Run `swift run laplap cat`; press Command 1, 2, 3, 4, 5 times — the badge
   label reads "CAT MODE — ⌘ 1/6", "⌘ 2/6" … "⌘ 5/6" after each press.
2. Stop pressing for ~10 seconds — the badge resets to "CAT MODE — ⌘ ×6 to exit".
3. Press Command 6 times within 10 seconds — the process exits with code 0.
4. Run `swift run laplap clean`; press Command — the overlay shows "⌘ n/6"
   under the instruction line; wait 10s idle — the line disappears; 6 presses
   within 10s unlock and exit with code 0.

## Out of scope

- Sounds, haptics, or any non-visual feedback
- Animations longer than 0.3s
- Configurable styling or progress text
- Badge on every display (main screen only)
- Changing unlock semantics (still CMD×6 within rolling 10s), consumption, or exit codes

## Risks

- Window-expiry display staleness: display must refresh on expiry, not only on
  presses — the onProgress path fires on every event so expiry is reflected on
  the next event; verify-script 2 covers the 10s-idle reset.
- Progress leaks across modes: onProgress wiring is set per-mode on entry and
  dropped with the mode's state; both modes verified independently in smoke.
- BadgeLabel set without redraw: label shows stale text — setter must trigger
  redraw; asserted by unit test.

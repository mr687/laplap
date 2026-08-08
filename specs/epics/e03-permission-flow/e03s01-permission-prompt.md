### Story e03s01: Prompt, System Settings handoff, documented error codes — Implementation Steps

**type:** feat
**risk:** P0
**context:** infra
**Context**: CGEventTap requires the Accessibility permission before any event can be consumed. e01s01 already ships a minimal fail-fast permission gate: when `AXIsProcessTrusted()` is false the process prints an error and exits non-zero. This story ENHANCES that gate with a real first-run flow: a `PermissionPrompter` that raises the system Accessibility prompt via `AXIsProcessTrustedWithOptions`, hands off to the System Settings privacy pane when the user does not grant, polls `AXIsProcessTrusted` for up to 60s, and exits with a documented error code when permission is still missing. The lock must never fail silently (graceful degradation). Exit-code contract is 0 ok / 2 usage / 3 permission missing; `--help` and README document these codes. No rich permission UX beyond this fail-fast flow is in scope.

## Requirements

- [x] (ADDED) PermissionPrompter: when `AXIsProcessTrusted()` is false, call `AXIsProcessTrustedWithOptions([.preflight] + [.setRights])` to raise the system prompt — P0
- [x] (ADDED) Handoff: if the user does not grant, offer to open the System Settings privacy pane (`open x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`) and wait up to 60s polling `AXIsProcessTrusted` — P1
- [x] (ADDED) Error contract: exit 3 with an actionable message when permission is missing; document codes 0/2/3 in `--help` and a README section — P1

## Steps

1. Add a `PermissionPrompter` type in the laplap target: when `AXIsProcessTrusted()` returns false, call `AXIsProcessTrustedWithOptions([.preflight, .setRights])` to trigger the system Accessibility prompt. → verify: `swift build`
2. Keep the existing fail-fast gate from e01s01 reachable: if preflight indicates no prompt can be raised, fall back to the actionable error path, never a silent hang. → verify: `swift build`
3. After raising the prompt, if `AXIsProcessTrusted()` is still false, offer the handoff by running `open x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` to open the System Settings privacy pane. → verify: `swift build`
4. Poll `AXIsProcessTrusted()` on an interval for up to 60 seconds after the handoff; if the user grants within the window, proceed with the lock as normal. → verify: `swift build`
5. If permission is still missing after the 60s window, exit 3 with an actionable message telling the user how to grant Accessibility permission. → verify: `swift build`
6. Document the exit-code contract (0 ok, 2 usage, 3 permission missing) in `--help` output. → verify: `swift run laplap --help`
7. Document the exit-code contract in a README section on permissions. → verify: `swift test`
8. Add headless tests that exercise the poll/exit logic with an injectable permission-check closure, so the flow is testable without a real Accessibility grant. → verify: `swift test && swift build`

## Acceptance Criteria

- **AC-1** (P0): When `AXIsProcessTrusted()` is false, the flow calls `AXIsProcessTrustedWithOptions` with `.preflight` and `.setRights`, raising the system Accessibility prompt.
- **AC-2** (P1): If the user does not grant, the flow opens the System Settings privacy pane and polls `AXIsProcessTrusted` for up to 60s.
- **AC-3** (P1): If permission is still missing after the wait, the process exits 3 with an actionable message; exit codes 0/2/3 are documented in `--help` and README.

## Verification Script (Step-by-Step)

1. In a fresh terminal where Accessibility is not yet granted, run `swift run laplap cat`.
2. Observe the system Accessibility prompt appears (from `AXIsProcessTrustedWithOptions`).
3. Decline/ignore the prompt; observe the flow offers to open the System Settings privacy pane and launches it.
4. Grant Accessibility in System Settings while the process waits; observe the lock proceeds (or, if the 60s window expires un-granted, the process exits 3 with an actionable message).
5. Run `laplap --help` and confirm it lists exit codes 0/2/3.

## Out of scope

- Rich permission UX (per-pane guidance, progress UI, auto-detect retry) beyond the fail-fast prompt + handoff.
- Replacing the existing e01s01 fail-fast gate; this story enhances it.
- Any GUI, daemon, or persistent permission handling.

## Risks

- P0: raising the Accessibility prompt is user-interruptible; the 60s poll may still end with no grant, so exit 3 must be reachable and messageable.
- P1: `AXIsProcessTrustedWithOptions(.setRights)` behavior varies across macOS versions; the fallback actionable-error path must remain intact.
- P1: tests must stay headless — permission-check must be injectable, never requiring a real grant in CI.

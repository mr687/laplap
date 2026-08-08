# CONVENTIONS.md — laplap

Rules for all AI agents working in this repo.

## Always Green / Shift Left

The cost of a defect grows roughly 10× per stage it survives: 1 (writing) → 10 (test) → 100 (production).

- **Preflight** = `swift test && swift build`. It MUST pass before any work is called done.
- **CI green** = `gh pr checks` passing on the open PR.
- A red gate blocks forward work. Fix it or log it. Never ignore it.

## Discovered Defects

When a defect is found outside the current task:

1. **quick-fix** — trivial, data-only, no logic risk → fix in a separate commit.
2. **fix-bug** — everything else → write `specs/bugs/BUG-*.md`, fix with TDD.
3. Discovered fixes MUST land as their own commit, never buried in feature work.

### Banned dismissive phrases

| Phrase | Why it is banned |
|--------|------------------|
| "pre-existing" | Shifts blame; the red gate is still red. |
| "unrelated to this session" | Breaks the always-green contract. |
| "not introduced by my changes" | Same contract violation. |
| "out of scope" | Scope is a planning input, not a red-gate excuse. |

## Tests

- Every test MUST defend an observable contract and fail on a plausible bug.
- Keep tests deterministic, isolated, full-suite safe. F.I.R.S.T: Fast, Isolated, Repeatable, Self-validating, Timely.
- Headless-safe: input-lock tests MUST NOT require a real HID device or real accessibility grant (inject events, mock the tap).

## Commits

Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`.
One logical change per commit. Separate commits for discovered fixes.

## Defensive Code Categories

Applied in this project:

- **Graceful degradation** — missing Accessibility permission: print clear instructions and open System Settings; never fail silently.
- **Fail-safe** — the lock lives only in the running process. If the event tap or the app dies, input returns. Never daemonize, never install a persistent hook.
- **Timeout** — unlock gesture is CMD×6 within a rolling 10-second window, so a cat mashing modifiers cannot unlock (or lock you out) by accident.
- **Fail-fast on preconditions** — wrong mode name, missing permission, or tap creation failure exits with a specific error code and message.

## Stack Conventions

- Swift 6, SwiftPM, macOS 13+ target. Zero external dependencies — Foundation + CoreGraphics + AppKit only.
- `CGEventTap` (kCGHIDEventTap) is the ONLY input-blocking mechanism. Consume events by returning `nil` from the callback; never install a second blocking layer.
- Unlock detection happens INSIDE the tap callback (the tap sees events before consuming them). CMD key-down (either Command key) counts; 6 within 10 s exits.
- Overlays: one NSWindow per NSScreen, `.screenSaver` window level, `ignoresMouseEvents`. Cursor hidden in clean mode, restored on exit.
- CLI: `laplap cat` and `laplap clean`; `--help` lists modes. No argument-parser dependency.

## Specs Output

All planning artifacts MUST be written to `specs/` before code:

- `specs/product/SCOPE_LATEST.yaml`, `VISION_LATEST.yaml`, `GLOSSARY_LATEST.yaml`
- `specs/release-plan.yaml`, `specs/state.yaml`, `specs/planning-status.yaml`
- `specs/epics/eNN-slug/` epic capsules
- `specs/tech-architecture/tech-stack.md`
- `specs/bugs/registry.yaml` + `specs/bugs/BUG-*.md`

## Agent Rules

- Workflow Mandate: use the bigpowers skills (`plan-work`, `develop-tdd`, `orchestrate-project`) for tasks. DO NOT write code directly in response to a prompt like "build this feature".
- Read `specs/` before writing code.
- Write the minimum code that solves the stated problem. Nothing extra.
- Run tests after every change. Show evidence before declaring done.
- One clarifying question beats a wrong assumption baked into 200 lines.

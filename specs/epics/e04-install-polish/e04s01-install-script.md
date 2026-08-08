### Story e04s01: install.sh: idempotent release install — Implementation Steps

**type:** feat
**risk:** P2
**context:** infra
**Context**: The project builds via SwiftPM but has no turnkey install path. This story adds `install.sh`: a strict shell script (`set -euo pipefail`) that runs `swift build -c release`, installs the resulting `.build/release/laplap` binary to `~/.local/bin/laplap` (falling back to `/usr/local/bin/laplap` when that is writable), creates the destination directory, sets the executable bit, and prints post-install instructions (first-run permission note and the CMDx6 unlock gesture). Re-running the script must overwrite cleanly — idempotent. No Homebrew formula, no signing/notarization, no daemon, no auto-start.

## Requirements

- [x] (ADDED) install.sh: `swift build -c release`, install binary to `~/.local/bin/laplap` (fallback `/usr/local/bin` if writable), `chmod +x`, `mkdir -p`, `set -euo pipefail` — P2
- [x] (ADDED) Idempotent: re-run overwrites cleanly; prints post-install instructions (first-run permission note, CMDx6 gesture) — P2

## Steps

1. Create `install.sh` in the repo root starting with a `#!/usr/bin/env bash` shebang and `set -euo pipefail`. → verify: `bash -n install.sh`
2. Run `swift build -c release` so `.build/release/laplap` exists before install. → verify: `bash -n install.sh`
3. Determine the install destination: prefer `~/.local/bin/laplap`; if that directory is not writable, fall back to `/usr/local/bin/laplap` when writable. → verify: `bash -n install.sh`
4. `mkdir -p` the chosen destination directory so it exists before copy. → verify: `bash -n install.sh`
5. Copy `.build/release/laplap` to the destination and `chmod +x` it. → verify: `bash -n install.sh`
6. Make the install idempotent: a re-run overwrites the existing binary cleanly (plain copy over the prior install). → verify: `bash -n install.sh`
7. Print post-install instructions: the first-run Accessibility permission note and the CMDx6 unlock gesture. → verify: `bash -n install.sh`
8. Guard against a failed build aborting mid-script (strict mode) so no partial install is left behind. → verify: `bash -n install.sh`

## Acceptance Criteria

- **AC-1** (P2): `install.sh` builds with `swift build -c release` and installs `.build/release/laplap` to `~/.local/bin/laplap`, with a `/usr/local/bin` fallback when writable, including `mkdir -p` and `chmod +x`, under `set -euo pipefail`.
- **AC-2** (P2): Re-running `install.sh` overwrites cleanly (idempotent) and prints post-install instructions covering the first-run permission note and the CMDx6 gesture.

## Verification Script (Step-by-Step)

1. Run `bash -n install.sh` and confirm it parses without syntax errors.
2. Run `./install.sh` on a clean clone; confirm it builds the release binary and installs it to `~/.local/bin/laplap`.
3. Confirm the binary is executable and prints the post-install instructions (permission note + CMDx6 gesture).
4. Run `./install.sh` a second time and confirm it completes cleanly, overwriting the prior install without error.
5. Run `~/.local/bin/laplap --help` and confirm the installed binary runs.

## Out of scope

- Homebrew formula.
- Code signing or notarization.
- Daemon, login-item auto-start, or any persistent installation beyond the binary.
- Upstream dependency/network fetch in the script beyond the SwiftPM build.

## Risks

- P2: destination-directory writability varies per machine; the `/usr/local/bin` fallback must be decided without erroring on a read-only default.
- P2: a failed release build must abort cleanly (strict mode) without leaving a partial install.
- P2: idempotent copy must not clobber a running binary in a way that fails silently.

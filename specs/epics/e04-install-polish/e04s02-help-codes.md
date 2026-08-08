### Story e04s02: --help and error-code documentation — Implementation Steps

**type:** feat
**risk:** P2
**context:** infra
**Context**: The CLI currently parses `cat|clean|--help` with minimal documentation and no formal exit-code contract surfaced to the user. This story polishes the CLI surface: `laplap --help` prints both modes, the CMDx6 unlock gesture, the Accessibility permission requirement, and the exit codes (0 ok, 2 usage, 3 permission missing), then exits 0. An unknown mode prints usage to stderr and exits 2. No new modes, no arg-parser dependency, no GUI.

## Requirements

- [x] (ADDED) `--help` prints both modes, the CMDx6 unlock gesture, the permission requirement, and exit codes (0 ok, 2 usage, 3 permission); exits 0 — P2
- [x] (ADDED) Unknown mode prints usage to stderr and exits 2 — P2

## Steps

1. Update the argument parser so `laplap --help` prints a help block listing both modes (`cat`, `clean`), the CMDx6 unlock gesture, the Accessibility permission requirement, and the exit codes (0 ok, 2 usage, 3 permission missing). → verify: `swift run laplap --help`
2. Ensure `--help` exits 0 (help is a valid request, not an error). → verify: `swift run laplap --help; test $? -eq 0`
3. Ensure an unknown mode (anything other than `cat`, `clean`, `--help`) prints usage to stderr and exits 2. → verify: `swift run laplap bogus; test $? -eq 2`
4. Confirm the exit-2 usage message goes to stderr (not stdout) so callers can distinguish it. → verify: `swift run laplap bogus 2>/dev/null; test $? -eq 2`
5. Add a headless test asserting `--help` exits 0 and the unknown-mode path exits 2, so the contract is guarded without a real accessibility grant. → verify: `swift test`

## Acceptance Criteria

- **AC-1** (P2): `laplap --help` prints both modes, the CMDx6 unlock gesture, the Accessibility permission requirement, and exit codes (0 ok, 2 usage, 3 permission), and exits 0.
- **AC-2** (P2): An unknown mode prints usage to stderr and exits 2.

## Verification Script (Step-by-Step)

1. Run `swift run laplap --help`; confirm the help block lists `cat` and `clean`, the CMDx6 gesture, the permission requirement, and exit codes 0/2/3; confirm the exit code is 0.
2. Run `swift run laplap bogus`; confirm usage is printed to stderr and the exit code is 2.
3. Run `swift run laplap bogus 2>/dev/null` and confirm the exit code is still 2 (usage went to stderr).

## Out of scope

- Adding new modes or subcommands.
- A third-party argument-parser dependency.
- Any GUI or interactive help.

## Risks

- P2: help/exit-code output is an observable CLI contract; it must stay stable and covered by a headless test.
- P2: the exit-2 usage path must go to stderr so scripting callers can distinguish it from a successful help call.

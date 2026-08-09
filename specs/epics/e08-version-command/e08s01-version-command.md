### Story e08s01: laplap version prints version info — Implementation Steps

**type:** feat
**risk:** P1
**context:** infra
**Context**: laplap currently has no way to report its own version. This story adds a `laplap version` subcommand that prints the version string (`laplap 0.1.0`) and exits 0. The version string lives in a single constant (`LaplapVersion.current`) that must be kept in sync with the git tag at release time — the release checklist notes this coupling so the constant and tag cannot drift silently. Parser integration mirrors the existing `cat`/`clean`/`settings` modes; no `--version` flag alias, no semver parsing, no build-date metadata.

## Requirements

- [ ] (ADDED) `version` mode accepted by the arg parser; usage lists it with a one-line description — P2
- [ ] (ADDED) `laplap version` prints `laplap 0.1.0` and exits 0 — P1
- [ ] (ADDED) Version string is a single source of truth: one constant (`LaplapVersion.current`) used by both the print and any future consumers — P1

## Steps

1. Add `case version` to `Mode` in ArgParser.swift and parse `"version"` → `.version`. → verify: `swift test`
2. Extend the usage Modes block with `version  Print version information`. → verify: `swift test`
3. Create Sources/laplap/LaplapVersion.swift with `enum LaplapVersion { static let current = "0.1.0" }` — the single source of truth for the version string. → verify: `swift test`
4. main.swift: `case .success(.version): print("laplap \(LaplapVersion.current)"); exitCode = 0`. → verify: `swift test && swift build`
5. ArgParserTests: `version` mode accepted; unknown modes still exit 2 (existing test stays); usage string contains the `version` line. → verify: `swift test`
6. README.md Usage block: add `laplap version # print version information`. → verify: `swift test`

## Acceptance Criteria

- **AC-1** (P2): `laplap version` is accepted by the parser, and usage lists it with a one-line description.
- **AC-2** (P1): `laplap version` prints `laplap 0.1.0` and exits 0.
- **AC-3** (P1): The version string is defined in exactly one place (`LaplapVersion.current`); the print path reads only that constant.

## Verification Script (Step-by-Step)

1. Run `swift run laplap version`; confirm it prints `laplap 0.1.0` and exits 0.
2. Run `swift run laplap --help`; confirm usage lists the `version` mode line.

## Out of scope

- `--version` flag alias — the subcommand form only.
- Semver parsing or comparison logic.
- Build-date or git-sha metadata in the version output.

## Risks

- P1: the version constant can drift from the git tag if a release forgets to update it — the release checklist must include "bump LaplapVersion.current to the new tag" as a step.

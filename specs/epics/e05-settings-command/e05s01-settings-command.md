### Story e05s01: Settings command opens Accessibility pane — Implementation Steps

**type:** feat
**risk:** P1
**context:** domain
**Context**: laplap's input lock requires the Accessibility permission (CGEventTap), and today the only guidance is the e03 prompt shown when a lock mode starts. This story adds a dedicated `laplap settings` subcommand that opens System Settings on the Privacy & Security → Accessibility pane and prints step-by-step instructions for granting the permission, so the user can grant (or verify) access before running a lock mode. The command prints whether the process is already trusted (AXIsProcessTrusted), opens the pane via the system `open` URL scheme, prints grant guidance, and exits 0 on success or 1 when the pane cannot be opened. Parser integration mirrors the existing `cat`/`clean` modes; no GUI, no auto-grant, no daemon.

## Requirements

- [ ] (ADDED) `settings` mode accepted by the arg parser; usage lists it with a one-line description; the exit-code block gains `1  Could not open System Settings` — P2
- [ ] (ADDED) SettingsCommand prints granted/not-granted status (AXIsProcessTrusted), opens the Accessibility pane via an injectable open-runner, prints step-by-step grant guidance, exits 0 on success, 1 when open fails — P1
- [ ] (ADDED) Exit contract: 0 on success, 1 when the pane fails to open, unknown modes stay 2 (usage error) — P1

## Steps

1. Add `case settings` to `Mode` in ArgParser.swift and parse `"settings"` → `.settings`. → verify: `swift test`
2. Extend the usage Modes block with `settings  Open System Settings to grant Accessibility permission`. → verify: `swift test`
3. Extend the Exit codes block with `1  Could not open System Settings`. → verify: `swift test`
4. Create Sources/laplap/SettingsCommand.swift with injectable seams: `trustedCheck: () -> Bool` (default PermissionGate.isTrusted), `openRunner: () -> Bool` (default: `/usr/bin/open x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`, waitUntilExit, terminationStatus == 0), `printer: (String) -> Void`. → verify: `swift test`
5. `run()` prints "Accessibility permission: granted" or "Accessibility permission: not granted" from trustedCheck. → verify: `swift test`
6. If openRunner() succeeds, print the step-by-step guidance block (pane location, find laplap/terminal, toggle ON, return and run `laplap cat` or `laplap clean`) and return 0. → verify: `swift test`
7. If openRunner() fails, print `laplap: could not open System Settings (run: open x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility)` to stderr and return 1. → verify: `swift test`
8. main.swift: `case .success(.settings): exitCode = SettingsCommand().run()`. → verify: `swift test && swift build`
9. ArgParserTests: `settings` accepted; unknown mode still exits 2; usage contains "settings" and the new exit-code line. → verify: `swift test`
10. SettingsCommandTests: openRunner called exactly once; exit 0 when openRunner true; exit 1 when openRunner false; status line reflects trustedCheck; guidance printed; no real /usr/bin/open or AXIsProcessTrusted in tests. → verify: `swift test`

## Acceptance Criteria

- **AC-1** (P2): `laplap settings` is accepted by the parser, usage lists it with a one-line description, and the exit-code block documents `1  Could not open System Settings`.
- **AC-2** (P1): `laplap settings` prints granted/not-granted status, opens the Accessibility pane, prints step-by-step grant guidance, and exits 0 on success.
- **AC-3** (P1): When the pane cannot be opened, `laplap settings` prints the manual `open` command to stderr and exits 1; unknown modes still exit 2.

## Verification Script (Step-by-Step)

1. Run `swift run laplap settings`; confirm System Settings opens on Privacy & Security → Accessibility.
2. Confirm the granted/not-granted status line and the step-by-step guidance are printed.
3. Confirm the command exits 0.
4. Run `swift run laplap bogus` and confirm it still exits 2.

## Out of scope

- GUI or preferences UI — the command only opens the system pane and prints text.
- Auto-grant of the Accessibility permission — user action required by macOS.
- Daemon or persistent permission watcher.
- Opening other System Settings panes.

## Risks

- P1: `open` can fail (missing URL scheme support, launchd hiccup); the exit-1 path is covered via the injectable open-runner test.
- P2: permission already granted — the command still opens the pane and prints guidance so the user can verify the toggle.

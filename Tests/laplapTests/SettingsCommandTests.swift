import XCTest
@testable import laplap

/// SettingsCommand tests: fully injectable seams — no real /usr/bin/open,
/// no real AXIsProcessTrusted. F.I.R.S.T.: Fast, Isolated, Repeatable.
final class SettingsCommandTests: XCTestCase {
    private func makeCommand(
        trusted: Bool = true,
        openResult: Bool = true,
        printer: @escaping (String) -> Void = { _ in },
        errorPrinter: @escaping (String) -> Void = { _ in }
    ) -> (command: SettingsCommand, printed: () -> [String], errors: () -> [String]) {
        var printed: [String] = []
        var errors: [String] = []
        let command = SettingsCommand(
            trustedCheck: { trusted },
            openRunner: { openResult },
            printer: { printed.append($0) },
            errorPrinter: { errors.append($0) }
        )
        // Getter closures (not snapshots): the arrays are captured by
        // reference and mutated when run() executes after this returns.
        return (command, { printed }, { errors })
    }

    func testOpenRunnerCalledExactlyOnce() {
        var calls = 0
        let command = SettingsCommand(
            trustedCheck: { true },
            openRunner: {
                calls += 1
                return true
            },
            printer: { _ in },
            errorPrinter: { _ in }
        )
        XCTAssertEqual(command.run(), 0)
        XCTAssertEqual(calls, 1, "openRunner must be called exactly once")
    }

    func testExitZeroWhenOpenRunnerSucceeds() {
        let (command, _, _) = makeCommand(openResult: true)
        XCTAssertEqual(command.run(), 0)
    }

    func testExitOneWhenOpenRunnerFails() {
        let (command, _, _) = makeCommand(openResult: false)
        XCTAssertEqual(command.run(), 1)
    }

    func testStatusLineReflectsTrustedCheck() {
        let (grantedCommand, grantedPrinted, _) = makeCommand(trusted: true)
        _ = grantedCommand.run()
        XCTAssertTrue(grantedPrinted().contains("Accessibility permission: granted"), "printed: \(grantedPrinted())")

        let (deniedCommand, deniedPrinted, _) = makeCommand(trusted: false)
        _ = deniedCommand.run()
        XCTAssertTrue(deniedPrinted().contains("Accessibility permission: not granted"), "printed: \(deniedPrinted())")
    }

    func testGuidancePrintedWhenPaneOpens() {
        let (command, printed, _) = makeCommand(openResult: true)
        _ = command.run()
        let output = printed().joined(separator: "\n")
        XCTAssertTrue(output.contains("1. System Settings opens on Privacy & Security → Accessibility"))
        XCTAssertTrue(output.contains("2. Find \"laplap\" or your terminal app in the list"))
        XCTAssertTrue(output.contains("3. Toggle it ON"))
        XCTAssertTrue(output.contains("4. Return to the terminal and run `laplap cat` or `laplap clean`"))
    }

    func testOpenFailurePrintsManualCommandToStderr() {
        let (command, _, errors) = makeCommand(openResult: false)
        XCTAssertEqual(command.run(), 1)
        XCTAssertTrue(
            errors().contains(where: {
                $0.contains("laplap: could not open System Settings") &&
                $0.contains("open x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            }),
            "errors: \(errors())"
        )
    }

    func testPermissionAlreadyGrantedStillOpensPane() {
        var calls = 0
        let command = SettingsCommand(
            trustedCheck: { true },
            openRunner: {
                calls += 1
                return true
            },
            printer: { _ in },
            errorPrinter: { _ in }
        )
        XCTAssertEqual(command.run(), 0)
        XCTAssertEqual(calls, 1, "pane must still open when permission is already granted")
    }
}

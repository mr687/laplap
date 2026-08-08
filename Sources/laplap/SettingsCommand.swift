import Foundation

/// `laplap settings` (epic e05): opens System Settings on the Privacy &
/// Security → Accessibility pane and prints step-by-step guidance for
/// granting the Accessibility permission laplap needs. Prints granted /
/// not-granted status, then opens the pane regardless (the user may want to
/// verify the toggle). Exits 0 on success, 1 when the pane cannot be opened.
/// Every seam (trust check, open runner, printers) is injectable so the
/// command is fully testable headless — tests never trigger a real open or
/// a real AXIsProcessTrusted.
struct SettingsCommand {
    /// Step-by-step grant guidance printed after the pane opens.
    static let guidance = """
    1. System Settings opens on Privacy & Security → Accessibility
    2. Find "laplap" or your terminal app in the list
    3. Toggle it ON
    4. Return to the terminal and run `laplap cat` or `laplap clean`
    """

    private let trustedCheck: () -> Bool
    private let openRunner: () -> Bool
    private let printer: (String) -> Void
    private let errorPrinter: (String) -> Void

    init(
        trustedCheck: @escaping () -> Bool = { PermissionGate.isTrusted() },
        openRunner: @escaping () -> Bool = { SettingsCommand.openAccessibilityPane() },
        printer: @escaping (String) -> Void = { print($0) },
        errorPrinter: @escaping (String) -> Void = { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
    ) {
        self.trustedCheck = trustedCheck
        self.openRunner = openRunner
        self.printer = printer
        self.errorPrinter = errorPrinter
    }

    /// Runs the settings flow. Returns the process exit code: 0 on success,
    /// 1 when the Accessibility pane cannot be opened.
    func run() -> Int32 {
        printer(trustedCheck() ? "Accessibility permission: granted" : "Accessibility permission: not granted")

        guard openRunner() else {
            errorPrinter("laplap: could not open System Settings (run: open x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility)")
            return 1
        }

        printer(Self.guidance)
        return 0
    }

    /// Opens the Accessibility pane via the built-in `open` command (zero
    /// external deps). Returns true when the process exits 0.
    static func openAccessibilityPane() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]
        guard (try? process.run()) != nil else {
            return false
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}

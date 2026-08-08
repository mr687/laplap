import ApplicationServices
import Foundation

/// First-run Accessibility permission flow (epic e03): raises the system
/// prompt via AXIsProcessTrustedWithOptions, hands off to the System Settings
/// privacy pane when the user does not grant, then polls AXIsProcessTrusted
/// for up to 60 seconds. Every seam (prompt raiser, trust check, clock, poll
/// interval, handoff) is injectable so the flow is fully testable headless —
/// tests never trigger a real prompt, a real `open`, or a real grant.
enum PermissionPrompter {
    /// Runs the full flow. Returns true when the process is trusted (either
    /// immediately after the prompt or within the 60s poll window); false
    /// when the window expires with permission still missing. The caller
    /// decides the exit path (CatMode exits 3 with PermissionGate guidance).
    static func promptAndWait(
        raisePrompt: @escaping () -> Void = { raiseSystemPrompt() },
        isTrusted: @escaping () -> Bool = { PermissionGate.isTrusted() },
        pollInterval: TimeInterval = 0.5,
        maxWait: TimeInterval = 60,
        now: @escaping () -> Date = Date.init,
        handoff: @escaping () -> Void = { openSystemSettings() }
    ) -> Bool {
        raisePrompt()
        if isTrusted() {
            return true
        }
        handoff()
        let deadline = now().addingTimeInterval(maxWait)
        while now() <= deadline {
            if isTrusted() {
                return true
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
        return false
    }

    /// REQ-1: raise the system Accessibility prompt (and request the right,
    /// so clicking Allow in the dialog is sufficient). No-op result: whether
    /// trust is granted is answered by the subsequent AXIsProcessTrusted.
    private static func raiseSystemPrompt() {
        // kAXTrustedCheckOptionPrompt is exported by the SDK; the setRights
        // key (10.14+) is not, but its constant value is the stable string
        // "AXTrustedCheckOptionSetRights" — requesting the right so clicking
        // Allow in the dialog grants it without a relaunch.
        // The SDK exports only kAXTrustedCheckOptionPrompt; both option keys
        // are stable string constants ("AXTrustedCheckOptionPrompt" and
        // "AXTrustedCheckOptionSetRights", the latter macOS 10.14+). The
        // setRights key requests the right so clicking Allow in the dialog
        // grants it without a relaunch.
        let options = [
            "AXTrustedCheckOptionPrompt": true,
            "AXTrustedCheckOptionSetRights": true,
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// REQ-2: open the System Settings Accessibility privacy pane via the
    /// built-in `open` command (zero external deps). Best-effort — failure
    /// leaves the poll window running with the printed guidance as fallback.
    static func openSystemSettings() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]
        try? process.run()
    }
}

import ApplicationServices
import Foundation

/// Minimal Accessibility permission gate (rich prompt flow is epic e03).
enum PermissionGate {
    /// Exact guidance printed when the process is not trusted.
    static let guidanceMessage = """
    laplap needs Accessibility permission to lock input.

    Grant it in System Settings → Privacy & Security → Accessibility,
    then run `laplap cat` again.
    """

    static let missingPermissionExitCode: Int32 = 3

    /// Trust check with injectable stub so the gate is testable headless.
    /// Defaults to the real AXIsProcessTrusted().
    static func isTrusted(
        stub: (() -> Bool)? = nil
    ) -> Bool {
        if let stub {
            return stub()
        }
        return AXIsProcessTrusted()
    }
}

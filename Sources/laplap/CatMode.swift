import AppKit
import CoreGraphics
import Foundation

/// Cat-mode lifecycle: permission gate → tap install → badge → run loop →
/// unlock exits 0. SIGTERM/SIGINT stop the run loop so the process exits
/// cleanly; the lock lives only in the running process (process death restores
/// input, fail-safe). The class itself is nonisolated — only badge creation
/// and teardown run on the main actor (AppKit); the tap callback and signal
/// handlers stop the loop from the main run loop thread via a nonisolated stop.
final class CatMode {
    let blocker: InputBlocker
    private(set) var exitCode: Int32 = 0
    /// Live badge while cat mode is armed; released (nil) once run() returns.
    private(set) var badge: BadgeView?

    private let runLoopRunner: (CFRunLoop) -> Void
    private let permissionCheck: () -> Bool
    private let badgeFactory: (@MainActor () -> BadgeView?)?
    private var signalSources: [DispatchSourceSignal] = []

    init(
        counter: UnlockCounter,
        tapCreator: InputBlocker.TapCreator? = nil,
        runLoopRunner: @escaping (CFRunLoop) -> Void = { _ in CFRunLoopRun() },
        permissionCheck: @escaping () -> Bool = { PermissionGate.isTrusted() },
        badgeFactory: (@MainActor () -> BadgeView?)? = nil
    ) {
        self.blocker = InputBlocker(
            counter: counter,
            onUnlock: {},
            onTapDisabled: {}
        )
        self.runLoopRunner = runLoopRunner
        self.permissionCheck = permissionCheck
        self.badgeFactory = badgeFactory
        // Wire callbacks after all stored properties are initialized (the
        // closures capture self). Both run on the main run loop thread.
        blocker.state.onUnlock = { [weak self] in self?.stop(0) }
        blocker.state.onTapDisabled = { [weak self] in self?.stop(0) }
        if let tapCreator {
            blocker.setTapCreator(tapCreator)
        }
    }

    @MainActor
    func run() -> Int32 {
        guard permissionCheck() else {
            FileHandle.standardError.write(Data((PermissionGate.guidanceMessage + "\n").utf8))
            return PermissionGate.missingPermissionExitCode
        }
        guard blocker.install() else {
            FileHandle.standardError.write(
                Data("laplap: could not install the input tap (is Accessibility permission granted?)\n".utf8)
            )
            return PermissionGate.missingPermissionExitCode
        }
        // Badge appears only once cat mode is armed (tap installed).
        if let badge = (badgeFactory ?? { BadgeView() })() {
            badge.orderFrontRegardless()
            self.badge = badge
        }
        defer {
            // Close and release on unlock/signal/exit so the process can
            // terminate without a lingering window-server connection.
            badge?.orderOut(nil)
            badge?.close()
            badge = nil
        }
        blocker.addRunLoopSource(to: CFRunLoopGetCurrent())
        installSignalHandlers()
        runLoopRunner(CFRunLoopGetCurrent())
        return exitCode
    }

    /// Stops the current run loop. Invoked from the tap callback and signal
    /// handlers, both of which run on the main run loop thread.
    nonisolated func stop(_ code: Int32) {
        exitCode = code
        CFRunLoopStop(CFRunLoopGetCurrent())
    }

    /// SIGTERM/SIGINT stop the loop and exit 0 (input restored by process exit).
    private func installSignalHandlers() {
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)
        for sig in [SIGINT, SIGTERM] {
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in
                self?.stop(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }
}

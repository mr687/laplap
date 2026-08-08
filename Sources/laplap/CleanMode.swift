import AppKit
import CoreGraphics
import Foundation

/// Clean-mode lifecycle: permission gate → tap install → black overlays +
/// hidden cursor → run loop → CMDx6 unlock restores the cursor, closes the
/// overlays, exits 0. SIGTERM/SIGINT stop the run loop so the process exits
/// cleanly; input and cursor return because the lock lives only in the
/// running process (fail-safe). Reuses the e01 input lock unchanged.
/// Nonisolated like CatMode: only overlay creation and teardown run on the
/// main actor; the tap callback and signal handlers stop the loop via a
/// nonisolated stop.
final class CleanMode {
    let blocker: InputBlocker
    private(set) var exitCode: Int32 = 0
    /// Live overlay controller while clean mode is armed; released once
    /// run() returns.
    private(set) var overlays: OverlayController?

    private let runLoopRunner: (CFRunLoop) -> Void
    private let permissionCheck: () -> Bool
    private let overlayFactory: (@MainActor () -> OverlayController?)?
    private var signalSources: [DispatchSourceSignal] = []

    init(
        counter: UnlockCounter,
        tapCreator: InputBlocker.TapCreator? = nil,
        runLoopRunner: @escaping (CFRunLoop) -> Void = { _ in CFRunLoopRun() },
        permissionCheck: @escaping () -> Bool = { PermissionGate.isTrusted() },
        overlayFactory: (@MainActor () -> OverlayController?)? = nil
    ) {
        self.blocker = InputBlocker(
            counter: counter,
            onUnlock: {},
            onTapDisabled: {}
        )
        self.runLoopRunner = runLoopRunner
        self.permissionCheck = permissionCheck
        self.overlayFactory = overlayFactory
        // Wire callbacks after all stored properties are initialized (the
        // closures capture self). All run on the main run loop thread.
        blocker.state.onUnlock = { [weak self] in self?.stop(0) }
        blocker.state.onTapDisabled = { [weak self] in self?.stop(0) }
        // Live unlock progress: every tap event refreshes the overlay progress
        // line and hides it when the rolling window expires. The tap callback
        // runs on the main run loop thread, so the main actor can be assumed;
        // only the controller (main-actor Sendable) crosses into the isolated
        // closure.
        blocker.state.onProgress = { [weak self] count, required in
            let controller = self?.overlays
            MainActor.assumeIsolated {
                controller?.setProgress(count, of: required)
            }
        }
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
        // Overlays and the hidden cursor appear only once clean mode is armed.
        if let controller = (overlayFactory ?? { OverlayController() })() {
            controller.arm()
            self.overlays = controller
        }
        defer {
            // Restore the cursor and close the overlays on unlock, signal,
            // or any other exit from the run loop (fail-safe).
            overlays?.disarm()
            overlays = nil
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

    /// SIGTERM/SIGINT stop the loop and exit 0 (input and cursor restored by
    /// the defer above).
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

import AppKit
import CoreGraphics
import Foundation

/// Cat-mode lifecycle: permission gate → tap install → run loop → unlock exits 0.
/// SIGTERM/SIGINT stop the run loop so the process exits cleanly; the lock
/// lives only in the running process (process death restores input, fail-safe).
final class CatMode {
    let blocker: InputBlocker
    private(set) var exitCode: Int32 = 0

    private let runLoopRunner: (CFRunLoop) -> Void
    private let permissionCheck: () -> Bool
    private var signalSources: [DispatchSourceSignal] = []

    init(
        counter: UnlockCounter,
        tapCreator: InputBlocker.TapCreator? = nil,
        runLoopRunner: @escaping (CFRunLoop) -> Void = { _ in CFRunLoopRun() },
        permissionCheck: @escaping () -> Bool = { PermissionGate.isTrusted() }
    ) {
        self.blocker = InputBlocker(
            counter: counter,
            onUnlock: {},
            onTapDisabled: {}
        )
        self.runLoopRunner = runLoopRunner
        self.permissionCheck = permissionCheck
        // Wire callbacks after all stored properties are initialized (the
        // closures capture self).
        blocker.state.onUnlock = { [weak self] in self?.stop(0) }
        blocker.state.onTapDisabled = { [weak self] in self?.stop(0) }
        if let tapCreator {
            blocker.setTapCreator(tapCreator)
        }
    }

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
        blocker.addRunLoopSource(to: CFRunLoopGetCurrent())
        installSignalHandlers()
        runLoopRunner(CFRunLoopGetCurrent())
        return exitCode
    }

    private func stop(_ code: Int32) {
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

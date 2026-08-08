import CoreGraphics
import XCTest
@testable import laplap

/// CatMode wiring: permission gate -> tap install -> run loop -> unlock exits 0.
/// All headless: injectable permission check, tap creator, and run-loop runner.
final class CatModeTests: XCTestCase {
    private static func dummyTap() -> CFMachPort {
        var context = CFMachPortContext()
        return CFMachPortCreate(kCFAllocatorDefault, dummyCallout, &context, nil)!
    }

    private static func commandKeyDown(_ keyCode: UInt16) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)!
        event.type = .flagsChanged
        event.flags = .maskCommand
        return event
    }

    func testMissingPermissionExitsThree() {
        let mode = CatMode(
            counter: UnlockCounter(),
            tapCreator: { _ in CatModeTests.dummyTap() },
            runLoopRunner: { _ in XCTFail("run loop must not start without permission") },
            permissionCheck: { false }
        )
        XCTAssertEqual(mode.run(), PermissionGate.missingPermissionExitCode)
    }

    func testUnlockStopsRunLoopWithExitZero() {
        var mode: CatMode?
        let runner: (CFRunLoop) -> Void = { _ in
            guard let mode else { return }
            // Simulate the unlock gesture arriving on the tap while the loop
            // runs: six Command key-downs through the real callback.
            let refcon = Unmanaged.passUnretained(mode.blocker.state).toOpaque()
            let proxy = OpaquePointer(bitPattern: 1)!
            for _ in 0..<6 {
                _ = InputBlocker.callback(proxy, .flagsChanged, CatModeTests.commandKeyDown(54), refcon)
            }
        }
        mode = CatMode(
            counter: UnlockCounter(),
            tapCreator: { _ in CatModeTests.dummyTap() },
            runLoopRunner: runner,
            permissionCheck: { true }
        )
        XCTAssertEqual(mode?.run(), 0, "unlock must stop the run loop and exit 0")
    }
}

private func dummyCallout(
    _ port: CFMachPort?,
    _ message: UnsafeMutableRawPointer?,
    _ size: CFIndex,
    _ info: UnsafeMutableRawPointer?
) {
}

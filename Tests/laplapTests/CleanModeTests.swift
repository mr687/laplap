import CoreGraphics
import XCTest
@testable import laplap

private let cleanModeTestScreen = OverlayScreen(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080), displayID: 7)

/// CleanMode wiring: permission gate -> tap install -> overlays + hidden
/// cursor -> run loop -> CMDx6 unlock restores the cursor, closes the
/// overlays, exits 0. All headless: injectable permission check, tap creator,
/// overlay factory, and run-loop runner; cursor hide/show tracked via a
/// recording controller.
@MainActor
final class CleanModeTests: XCTestCase {
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
        var created = 0
        let mode = CleanMode(
            counter: UnlockCounter(),
            tapCreator: { _ in CleanModeTests.dummyTap() },
            runLoopRunner: { _ in XCTFail("run loop must not start without permission") },
            permissionCheck: { false },
            overlayFactory: {
                created += 1
                return OverlayController(screenProvider: { [cleanModeTestScreen] })
            }
        )
        XCTAssertEqual(mode.run(), PermissionGate.missingPermissionExitCode)
        XCTAssertEqual(created, 0, "no overlays without permission")
    }

    func testTapCreationFailureExitsThree() {
        var created = 0
        let mode = CleanMode(
            counter: UnlockCounter(),
            tapCreator: { _ in nil },
            runLoopRunner: { _ in XCTFail("run loop must not start when tap creation fails") },
            permissionCheck: { true },
            overlayFactory: {
                created += 1
                return OverlayController(screenProvider: { [cleanModeTestScreen] })
            }
        )
        XCTAssertEqual(mode.run(), PermissionGate.missingPermissionExitCode)
        XCTAssertEqual(created, 0, "no overlays when the tap cannot be installed")
    }

    func testOverlaysArmedOnlyWhenCleanModeArms() {
        let recording = RecordingCursorController()
        var created: [OverlayController] = []
        let mode = CleanMode(
            counter: UnlockCounter(),
            tapCreator: { _ in CleanModeTests.dummyTap() },
            runLoopRunner: { _ in },
            permissionCheck: { true },
            overlayFactory: {
                let controller = OverlayController(screenProvider: { [cleanModeTestScreen] }, cursor: recording)
                created.append(controller)
                return controller
            }
        )
        XCTAssertEqual(mode.run(), 0)
        XCTAssertEqual(created.count, 1, "overlay controller created exactly once, only when clean mode arms")
        XCTAssertNil(mode.overlays, "overlay controller released before run() returns")
        XCTAssertEqual(created.first?.overlayWindows.count, 0, "overlays closed before run() returns")
        XCTAssertEqual(recording.hiddenIDs, [7], "cursor hidden on arm")
        XCTAssertEqual(recording.shownIDs, [7], "cursor restored on exit")
    }

    func testOverlaysNotCreatedWithoutPermission() {
        var created = 0
        let mode = CleanMode(
            counter: UnlockCounter(),
            tapCreator: { _ in CleanModeTests.dummyTap() },
            runLoopRunner: { _ in XCTFail("run loop must not start") },
            permissionCheck: { false },
            overlayFactory: {
                created += 1
                return OverlayController(screenProvider: { [cleanModeTestScreen] })
            }
        )
        _ = mode.run()
        XCTAssertEqual(created, 0, "no overlays without permission")
        XCTAssertNil(mode.overlays)
    }

    func testOverlaysNotCreatedWhenTapInstallFails() {
        var created = 0
        let mode = CleanMode(
            counter: UnlockCounter(),
            tapCreator: { _ in nil },
            runLoopRunner: { _ in XCTFail("run loop must not start") },
            permissionCheck: { true },
            overlayFactory: {
                created += 1
                return OverlayController(screenProvider: { [cleanModeTestScreen] })
            }
        )
        _ = mode.run()
        XCTAssertEqual(created, 0, "no overlays when the tap cannot be installed")
        XCTAssertNil(mode.overlays)
    }

    func testUnlockRestoresCursorAndClosesOverlays() {
        let recording = RecordingCursorController()
        var armed: OverlayController?
        var mode: CleanMode?
        let runner: (CFRunLoop) -> Void = { _ in
            guard let mode else { return }
            // Clean mode is fully armed while the loop runs: cursor hidden.
            XCTAssertEqual(recording.hiddenIDs, [7], "cursor hidden while armed")
            // Simulate the unlock gesture arriving on the tap while the loop
            // runs: six Command key-downs through the real callback.
            let refcon = Unmanaged.passUnretained(mode.blocker.state).toOpaque()
            let proxy = OpaquePointer(bitPattern: 1)!
            for _ in 0..<6 {
                _ = InputBlocker.callback(proxy, .flagsChanged, CleanModeTests.commandKeyDown(54), refcon)
            }
        }
        mode = CleanMode(
            counter: UnlockCounter(),
            tapCreator: { _ in CleanModeTests.dummyTap() },
            runLoopRunner: runner,
            permissionCheck: { true },
            overlayFactory: {
                let controller = OverlayController(screenProvider: { [cleanModeTestScreen] }, cursor: recording)
                armed = controller
                return controller
            }
        )
        XCTAssertEqual(mode?.run(), 0, "CMDx6 unlock must stop the run loop and exit 0")
        XCTAssertNil(mode?.overlays, "overlays released on unlock")
        XCTAssertEqual(armed?.overlayWindows.count, 0, "overlays closed on unlock")
        XCTAssertFalse(armed?.cursorHidden ?? true, "cursor restored on unlock")
        XCTAssertEqual(recording.shownIDs, [7], "CGDisplayShowCursor called for the hidden display")
    }
}

private func dummyCallout(
    _ port: CFMachPort?,
    _ message: UnsafeMutableRawPointer?,
    _ size: CFIndex,
    _ info: UnsafeMutableRawPointer?
) {
}

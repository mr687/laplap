import CoreGraphics
import XCTest
@testable import laplap

/// CatMode wiring: permission gate -> tap install -> badge -> run loop ->
/// unlock exits 0. All headless: injectable permission check, tap creator,
/// badge factory, and run-loop runner.
@MainActor
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
            permissionCheck: { false },
            // User declines the raised prompt / 60s handoff window — the
            // e01 fail-fast contract (exit 3, no lock) must hold unchanged.
            promptFlow: { false }
        )
        XCTAssertEqual(mode.run(), PermissionGate.missingPermissionExitCode)
    }

    func testDeclinedPermissionWritesExactGuidanceMessage() {
        // Capture stderr (fd 2) so the exact e01 guidance message written on
        // the decline path is asserted verbatim.
        let savedFD = dup(STDERR_FILENO)
        let pipe = Pipe()
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        let mode = CatMode(
            counter: UnlockCounter(),
            tapCreator: { _ in CatModeTests.dummyTap() },
            runLoopRunner: { _ in XCTFail("run loop must not start") },
            permissionCheck: { false },
            promptFlow: { false }
        )
        let code = mode.run()
        pipe.fileHandleForWriting.closeFile()
        dup2(savedFD, STDERR_FILENO)
        close(savedFD)
        let stderr = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertEqual(code, PermissionGate.missingPermissionExitCode)
        XCTAssertEqual(
            stderr.trimmingCharacters(in: .whitespacesAndNewlines),
            PermissionGate.guidanceMessage,
            "decline path must print the exact e01 guidance message"
        )
    }

    func testGrantDuringPermissionFlowProceedsWithLock() {
        var started = false
        let mode = CatMode(
            counter: UnlockCounter(),
            tapCreator: { _ in CatModeTests.dummyTap() },
            runLoopRunner: { _ in started = true },
            permissionCheck: { false },
            promptFlow: { true }  // granted during the 60s poll window
        )
        XCTAssertEqual(mode.run(), 0)
        XCTAssertTrue(started, "lock must proceed once permission is granted during the flow")
    }

    func testTapCreationFailureExitsThree() {
        let mode = CatMode(
            counter: UnlockCounter(),
            tapCreator: { _ in nil },
            runLoopRunner: { _ in XCTFail("run loop must not start when tap creation fails") },
            permissionCheck: { true }
        )
        XCTAssertEqual(mode.run(), PermissionGate.missingPermissionExitCode)
    }

    func testBadgeCreatedOnlyWhenCatModeArms() {
        var created: [BadgeView] = []
        let mode = CatMode(
            counter: UnlockCounter(),
            tapCreator: { _ in CatModeTests.dummyTap() },
            runLoopRunner: { _ in },
            permissionCheck: { true },
            badgeFactory: { let badge = BadgeView(); created.append(badge); return badge }
        )
        XCTAssertEqual(mode.run(), 0)
        XCTAssertEqual(created.count, 1, "badge must be created exactly once, only when cat mode arms")
        XCTAssertNil(mode.badge, "badge must be released before run() returns")
    }

    func testBadgeNotCreatedWithoutPermission() {
        var created = 0
        let mode = CatMode(
            counter: UnlockCounter(),
            tapCreator: { _ in CatModeTests.dummyTap() },
            runLoopRunner: { _ in XCTFail("run loop must not start") },
            permissionCheck: { false },
            promptFlow: { false },
            badgeFactory: { created += 1; return BadgeView() }
        )
        _ = mode.run()
        XCTAssertEqual(created, 0, "no badge without permission")
        XCTAssertNil(mode.badge)
    }

    func testBadgeNotCreatedWhenTapInstallFails() {
        var created = 0
        let mode = CatMode(
            counter: UnlockCounter(),
            tapCreator: { _ in nil },
            runLoopRunner: { _ in XCTFail("run loop must not start") },
            permissionCheck: { true },
            badgeFactory: { created += 1; return BadgeView() }
        )
        _ = mode.run()
        XCTAssertEqual(created, 0, "no badge when the tap cannot be installed")
        XCTAssertNil(mode.badge)
    }

    func testBadgeTeardownOnUnlock() {
        var mode: CatMode?
        let runner: (CFRunLoop) -> Void = { _ in
            guard let mode else { return }
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
        XCTAssertNil(mode?.badge, "badge must be closed and released on unlock")
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

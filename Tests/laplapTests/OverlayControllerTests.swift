import AppKit
import CoreGraphics
import XCTest
@testable import laplap

private let overlayFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
private let overlaySecondFrame = NSRect(x: 1920, y: 0, width: 1440, height: 900)

/// Headless overlay asserts on real NSWindow instances (AppKit window
/// creation works in XCTest; on-screen rendering stays manual). Screens and
/// the cursor are injected so no real display or cursor API is touched.
@MainActor
final class OverlayControllerTests: XCTestCase {
    func testLabelText() {
        XCTAssertEqual(OverlayController.OverlayConfig.standard.titleText, "CLEANING MODE")
        XCTAssertEqual(OverlayController.OverlayConfig.standard.subtitleText, "Press ⌘ 6 times to exit")
    }

    func testWindowConfiguration() {
        let controller = OverlayController(
            screenProvider: { [OverlayScreen(frame: overlayFrame, displayID: 1)] },
            cursor: RecordingCursorController()
        )
        controller.arm()
        defer { controller.disarm() }
        XCTAssertEqual(controller.overlayWindows.count, 1)
        let window = controller.overlayWindows[0]
        XCTAssertEqual(window.level, .screenSaver)
        XCTAssertTrue(window.ignoresMouseEvents, "overlay must never intercept mouse events")
        XCTAssertEqual(window.styleMask, [.borderless])
        XCTAssertTrue(window.isOpaque, "overlay must be fully opaque black")
        XCTAssertEqual(window.backgroundColor, .black)
        XCTAssertEqual(window.frame, overlayFrame, "overlay covers the full screen frame")
    }

    func testOneWindowPerScreen() {
        let screens = [
            OverlayScreen(frame: overlayFrame, displayID: 1),
            OverlayScreen(frame: overlaySecondFrame, displayID: 2),
            OverlayScreen(frame: NSRect(x: 0, y: 1080, width: 1920, height: 1080), displayID: 3),
        ]
        let controller = OverlayController(screenProvider: { screens }, cursor: RecordingCursorController())
        controller.arm()
        defer { controller.disarm() }
        XCTAssertEqual(controller.windowCount, screens.count, "window count derived from the screen provider")
        XCTAssertEqual(controller.overlayWindows.count, screens.count, "one overlay per screen")
    }

    func testLabelConfiguration() {
        let controller = OverlayController(
            screenProvider: { [OverlayScreen(frame: overlayFrame, displayID: 1)] },
            cursor: RecordingCursorController()
        )
        controller.arm()
        defer { controller.disarm() }
        let window = controller.overlayWindows[0] as! OverlayWindow
        XCTAssertEqual(window.titleLabel.stringValue, "CLEANING MODE")
        XCTAssertEqual(window.titleLabel.font, NSFont.systemFont(ofSize: 34, weight: .bold), "title must be bold 34pt")
        XCTAssertEqual(window.label.stringValue, "Press ⌘ 6 times to exit")
        XCTAssertEqual(window.label.textColor, .white.withAlphaComponent(0.85), "subtitle at ~0.85 white alpha")
        XCTAssertEqual(window.label.font, NSFont.systemFont(ofSize: 18, weight: .regular))
        XCTAssertEqual(window.label.alignment, .center, "instruction text must be centered")
    }

    func testProgressFieldHiddenInitially() {
        let controller = OverlayController(
            screenProvider: { [OverlayScreen(frame: overlayFrame, displayID: 1)] },
            cursor: RecordingCursorController()
        )
        controller.arm()
        defer { controller.disarm() }
        let window = controller.overlayWindows[0] as! OverlayWindow
        XCTAssertTrue(window.progressField.isHidden, "progress line hidden before any press")
    }

    func testSetProgressShowsAndHidesCount() {
        let controller = OverlayController(
            screenProvider: { [OverlayScreen(frame: overlayFrame, displayID: 1)] },
            cursor: RecordingCursorController()
        )
        controller.arm()
        defer { controller.disarm() }
        let window = controller.overlayWindows[0] as! OverlayWindow
        controller.setProgress(3, of: 6)
        XCTAssertFalse(window.progressField.isHidden)
        XCTAssertEqual(window.progressField.stringValue, "⌘ 3/6")
        controller.setProgress(0, of: 6)
        XCTAssertTrue(window.progressField.isHidden, "count 0 must hide the progress line")
    }

    func testFadeDurationConstant() {
        XCTAssertEqual(OverlayWindow.fadeDuration, 0.15, accuracy: 0.001)
    }

    func testOverlayStartsTransparentOnArm() {
        let controller = OverlayController(
            screenProvider: { [OverlayScreen(frame: overlayFrame, displayID: 1)] },
            cursor: RecordingCursorController()
        )
        controller.arm()
        defer { controller.disarm() }
        XCTAssertEqual(controller.overlayWindows[0].alphaValue, 0, "fade-in must start at alpha 0")
    }

    func testRebuildOnScreenChangeNotification() {
        var screens = [OverlayScreen(frame: overlayFrame, displayID: 1)]
        let controller = OverlayController(screenProvider: { screens }, cursor: RecordingCursorController())
        controller.arm()
        XCTAssertEqual(controller.overlayWindows.count, 1)
        // A display is added while armed.
        screens = [
            OverlayScreen(frame: overlayFrame, displayID: 1),
            OverlayScreen(frame: overlaySecondFrame, displayID: 2),
        ]
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let deadline = Date().addingTimeInterval(2)
        while controller.overlayWindows.count != 2 && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertEqual(controller.overlayWindows.count, 2, "overlays rebuilt after screen configuration change")
        controller.disarm()
    }

    func testCursorHiddenOnArm() {
        let recording = RecordingCursorController()
        let controller = OverlayController(
            screenProvider: {
                [OverlayScreen(frame: overlayFrame, displayID: 1), OverlayScreen(frame: overlaySecondFrame, displayID: 2)]
            },
            cursor: recording
        )
        controller.arm()
        defer { controller.disarm() }
        XCTAssertEqual(recording.hiddenIDs, [1, 2], "cursor hidden per screen display ID on arm")
        XCTAssertTrue(controller.cursorHidden)
    }

    func testCursorRestoredOnDisarm() {
        let recording = RecordingCursorController()
        let controller = OverlayController(
            screenProvider: {
                [OverlayScreen(frame: overlayFrame, displayID: 1), OverlayScreen(frame: overlaySecondFrame, displayID: 2)]
            },
            cursor: recording
        )
        controller.arm()
        controller.disarm()
        XCTAssertEqual(recording.shownIDs, [1, 2], "cursor restored for the same IDs that were hidden")
        XCTAssertFalse(controller.cursorHidden)
        XCTAssertEqual(controller.overlayWindows.count, 0, "overlays closed on disarm")
    }

    func testCursorRestoreIdempotent() {
        let recording = RecordingCursorController()
        let controller = OverlayController(
            screenProvider: { [OverlayScreen(frame: overlayFrame, displayID: 1)] },
            cursor: recording
        )
        controller.arm()
        controller.disarm()
        controller.disarm()
        XCTAssertEqual(recording.shownIDs, [1], "second disarm must not show the cursor again")
    }

    func testRebuildRepairsCursorPairing() {
        let recording = RecordingCursorController()
        var screens = [OverlayScreen(frame: overlayFrame, displayID: 1)]
        let controller = OverlayController(screenProvider: { screens }, cursor: recording)
        controller.arm()
        screens = [
            OverlayScreen(frame: overlayFrame, displayID: 1),
            OverlayScreen(frame: overlaySecondFrame, displayID: 2),
        ]
        controller.rebuild()
        XCTAssertEqual(recording.shownIDs, [1], "old display cursor restored before re-hide")
        XCTAssertEqual(
            recording.hiddenIDs, [1, 1, 2],
            "cursor hidden on arm and re-hidden for the current display set"
        )
        XCTAssertEqual(controller.overlayWindows.count, 2, "overlays re-created for the new screen set")
    }

    func testArmIsIdempotent() {
        let recording = RecordingCursorController()
        let controller = OverlayController(
            screenProvider: { [OverlayScreen(frame: overlayFrame, displayID: 1)] },
            cursor: recording
        )
        controller.arm()
        controller.arm()
        XCTAssertEqual(controller.overlayWindows.count, 1, "second arm must not duplicate overlays")
        XCTAssertEqual(recording.hiddenIDs, [1], "second arm must not re-hide the cursor")
        controller.disarm()
    }

    func testDisarmBeforeArmIsNoOp() {
        let recording = RecordingCursorController()
        let controller = OverlayController(
            screenProvider: { [OverlayScreen(frame: overlayFrame, displayID: 1)] },
            cursor: recording
        )
        controller.disarm()
        XCTAssertTrue(recording.shownIDs.isEmpty, "no cursor call without arm")
        XCTAssertTrue(controller.overlayWindows.isEmpty)
    }
}

/// Test double: records hide/show calls instead of touching the real cursor.
final class RecordingCursorController: CursorControlling {
    private(set) var hiddenIDs: [CGDirectDisplayID] = []
    private(set) var shownIDs: [CGDirectDisplayID] = []

    func hide(on displayID: CGDirectDisplayID) {
        hiddenIDs.append(displayID)
    }

    func show(on displayID: CGDirectDisplayID) {
        shownIDs.append(displayID)
    }
}

import CoreGraphics
import XCTest
@testable import laplap

/// InputBlocker: CGEventTap at kCGHIDEventTap; callback consumes every event
/// (returns nil), feeds UnlockCounter, stops on unlock; tap creation failure
/// is detected headless via an injectable creator. Constructed CGEvent objects
/// need no Accessibility grant.
final class InputBlockerTests: XCTestCase {
    private var counter: UnlockCounter!
    private var unlocks = 0
    private var tapDisabledCalls = 0
    private var blocker: InputBlocker!

    override func setUp() {
        counter = UnlockCounter()
        unlocks = 0
        tapDisabledCalls = 0
        blocker = InputBlocker(
            counter: counter,
            onUnlock: { self.unlocks += 1 },
            onTapDisabled: { self.tapDisabledCalls += 1 }
        )
    }

    private var stateRefcon: UnsafeMutableRawPointer {
        Unmanaged.passUnretained(blocker.state).toOpaque()
    }

    /// The callback never dereferences the proxy; a non-nil dummy suffices.
    private var dummyProxy: CGEventTapProxy {
        OpaquePointer(bitPattern: 1)!
    }

    private func commandKeyDown(_ keyCode: UInt16) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)!
        event.type = .flagsChanged
        event.flags = .maskCommand
        return event
    }

    private func commandKeyUp(_ keyCode: UInt16) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)!
        event.type = .flagsChanged
        event.flags = []
        return event
    }

    private func regularKeyDown(_ keyCode: UInt16 = 0) -> CGEvent {
        CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)!
    }

    private func mouseEvent() -> CGEvent {
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: .zero, mouseButton: .left)!
    }

    private func invoke(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        InputBlocker.callback(dummyProxy, type, event, stateRefcon)
    }

    // MARK: consumption

    func testCallbackConsumesKeyboardEvents() {
        XCTAssertNil(invoke(.keyDown, regularKeyDown()))
        XCTAssertNil(invoke(.flagsChanged, commandKeyDown(54)))
    }

    func testCallbackConsumesMouseEvents() {
        XCTAssertNil(invoke(.leftMouseDown, mouseEvent()))
        XCTAssertNil(invoke(.mouseMoved, mouseEvent()))
    }

    // MARK: unlock feeding

    func testSixCommandDownsUnlock() {
        for i in 0..<6 {
            _ = invoke(.flagsChanged, commandKeyDown(54))
            XCTAssertEqual(unlocks, i < 5 ? 0 : 1, "unlock fires only on the 6th press")
        }
    }

    func testKeyUpDoesNotUnlock() {
        for _ in 0..<6 {
            _ = invoke(.flagsChanged, commandKeyUp(54))
        }
        XCTAssertEqual(unlocks, 0)
    }

    func testNonCommandKeyCodeDoesNotUnlock() {
        for _ in 0..<6 {
            _ = invoke(.flagsChanged, commandKeyDown(53))
        }
        XCTAssertEqual(unlocks, 0)
    }

    func testOrdinaryKeyDownsDoNotUnlock() {
        for _ in 0..<6 {
            _ = invoke(.keyDown, regularKeyDown())
        }
        XCTAssertEqual(unlocks, 0)
    }

    // MARK: fail-safe

    func testTapDisabledEventsInvokeFailSafe() {
        _ = invoke(.tapDisabledByTimeout, regularKeyDown())
        _ = invoke(.tapDisabledByUserInput, regularKeyDown())
        XCTAssertEqual(tapDisabledCalls, 2)
        XCTAssertEqual(unlocks, 0)
    }

    func testNullEventIsConsumedWithoutSideEffects() {
        XCTAssertNil(invoke(.null, regularKeyDown()))
        XCTAssertEqual(tapDisabledCalls, 0)
        XCTAssertEqual(unlocks, 0)
    }

    // MARK: install

    func testInstallFailsWhenTapCreationFails() {
        let blocker = InputBlocker(
            counter: UnlockCounter(),
            onUnlock: {},
            onTapDisabled: {},
            tapCreator: { _ in nil }
        )
        XCTAssertFalse(blocker.install())
    }

    func testInstallSucceedsWithCreatedTap() {
        let blocker = InputBlocker(
            counter: UnlockCounter(),
            onUnlock: {},
            onTapDisabled: {},
            tapCreator: { _ in InputBlockerTests.makeDummyTap() }
        )
        XCTAssertTrue(blocker.install())
        XCTAssertNotNil(blocker.tap)
    }

    // MARK: mask

    func testAllEventsMaskCoversKeyboardAndMouse() {
        let mask = InputBlocker.allEventsMask
        for type in [CGEventType.keyDown, .flagsChanged, .leftMouseDown, .mouseMoved, .scrollWheel] {
            let bit = (mask >> CGEventMask(type.rawValue)) & 1
            XCTAssertEqual(bit, 1, "mask must cover \(type)")
        }
    }

    // MARK: helpers

    private static func makeDummyTap() -> CFMachPort {
        var context = CFMachPortContext()
        let port = CFMachPortCreate(kCFAllocatorDefault, dummyCallout, &context, nil)!
        return port
    }
}

private func dummyCallout(
    _ port: CFMachPort?,
    _ message: UnsafeMutableRawPointer?,
    _ size: CFIndex,
    _ info: UnsafeMutableRawPointer?
) {
}

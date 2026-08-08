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
    private var progress: [(Int, Int)] = []
    private var blocker: InputBlocker!

    override func setUp() {
        counter = UnlockCounter()
        unlocks = 0
        tapDisabledCalls = 0
        progress = []
        blocker = InputBlocker(
            counter: counter,
            onUnlock: { self.unlocks += 1 },
            onTapDisabled: { self.tapDisabledCalls += 1 }
        )
        blocker.state.onProgress = { count, required in
            self.progress.append((count, required))
        }
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

    // MARK: onProgress

    func testOnProgressReportsCountsOneThroughSix() {
        for i in 1...6 {
            _ = invoke(.flagsChanged, commandKeyDown(54))
            XCTAssertEqual(progress.last?.0, i, "each CMD down must report its live count")
            XCTAssertEqual(progress.last?.1, 6, "required presses always reported")
        }
        XCTAssertEqual(progress.count, 6, "one progress report per CMD down")
    }

    func testOnProgressFiresForNonCommandEvents() {
        _ = invoke(.flagsChanged, commandKeyDown(54))
        _ = invoke(.flagsChanged, commandKeyDown(55))
        _ = invoke(.keyDown, regularKeyDown())
        XCTAssertEqual(progress.last?.0, 2, "any event must refresh with the current count")
    }

    func testOnProgressResetsAfterWindowExpiry() {
        var now: Double = 0
        let counter = UnlockCounter(clock: { now })
        let blocker = InputBlocker(counter: counter, onUnlock: {}, onTapDisabled: {})
        var recorded: [(Int, Int)] = []
        blocker.state.onProgress = { recorded.append(($0, $1)) }
        let refcon = Unmanaged.passUnretained(blocker.state).toOpaque()
        let proxy = OpaquePointer(bitPattern: 1)!
        for _ in 0..<5 {
            _ = InputBlocker.callback(proxy, .flagsChanged, commandKeyDown(54), refcon)
        }
        now = 10.001
        _ = InputBlocker.callback(proxy, .mouseMoved, mouseEvent(), refcon)
        XCTAssertEqual(recorded.last?.0, 0, "window expiry must reset the reported count")
    }

    func testOnProgressNotFiredForNullEvents() {
        _ = invoke(.null, regularKeyDown())
        XCTAssertTrue(progress.isEmpty, "null padding events must not refresh progress")
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

import XCTest
@testable import laplap

/// UnlockCounter: Command key-down transitions (keyCodes 54/55), 6 within a
/// rolling 10s window unlocks; stale presses expire; fixed-size ring; injected clock.
final class UnlockCounterTests: XCTestCase {
    private var now: Double = 0
    private var counter: UnlockCounter!

    override func setUp() {
        now = 0
        counter = UnlockCounter(clock: { self.now })
    }

    private func press(_ keyCode: UInt16 = 54, down: Bool = true) -> Bool {
        counter.register(keyCode: keyCode, isCommandDown: down)
    }

    func testSixPressesWithinWindowUnlocks() {
        for _ in 0..<5 {
            XCTAssertFalse(press(), "fewer than 6 presses must not unlock")
        }
        XCTAssertTrue(press(), "6th press within window must unlock")
    }

    func testBothCommandSidesCount() {
        XCTAssertFalse(press(54))
        XCTAssertFalse(press(55))
        XCTAssertFalse(press(54))
        XCTAssertFalse(press(55))
        XCTAssertFalse(press(54))
        XCTAssertTrue(press(55), "mix of both command keys must count toward 6")
    }

    func testKeyUpDoesNotCount() {
        for _ in 0..<6 {
            XCTAssertFalse(press(down: false), "key-up must never count")
        }
    }

    func testOtherKeyCodesDoNotCount() {
        for _ in 0..<6 {
            XCTAssertFalse(press(53), "non-command keyCode must never count")
        }
    }

    func testStalePressesExpire() {
        // 5 presses at t=0.
        for _ in 0..<5 {
            XCTAssertFalse(press())
        }
        // 6th press after the window closes: the 5 old presses expire first.
        now = 10.001
        XCTAssertFalse(press(), "stale presses must expire, so this is 1 in window")
    }

    func testWindowBoundaryIsInclusive() {
        for _ in 0..<5 {
            XCTAssertFalse(press())
        }
        now = 10.0
        XCTAssertTrue(press(), "press exactly at the window edge still counts")
    }

    func testRollingWindowAllowsContinuedUnlock() {
        // Press every 2s: after the 6th the oldest is exactly at the edge.
        for i in 1...6 {
            now = Double(i) * 2
            if i < 6 {
                XCTAssertFalse(press())
            }
        }
        now = 12
        XCTAssertTrue(press(), "presses at 2,4,6,8,10,12 all inside a 10s window")
    }

    func testOverflowIsBounded() {
        for _ in 0..<100 {
            now += 0.1
            _ = press()
        }
        // 100 rapid presses must not grow memory or crash; count is capped by
        // the fixed ring. A fresh press still reports unlocked.
        XCTAssertTrue(press())
    }

    func testDefaultClockAdvances() {
        let live = UnlockCounter()
        // Real clock: six sequential presses are inside any 10s window.
        var unlocked = false
        for _ in 0..<6 {
            unlocked = live.register(keyCode: 54, isCommandDown: true)
        }
        XCTAssertTrue(unlocked)
    }

    // MARK: liveCount

    func testLiveCountTracksPresses() {
        for _ in 0..<3 {
            XCTAssertFalse(press())
        }
        XCTAssertEqual(counter.liveCount, 3, "liveCount must reflect in-window presses")
    }

    func testLiveCountResetsToZeroAfterWindowExpiry() {
        for _ in 0..<5 {
            XCTAssertFalse(press())
        }
        now = 10.001
        XCTAssertEqual(counter.liveCount, 0, "reading liveCount must expire stale presses")
    }

    func testLiveCountKeepsPressesAtExactlyWindowBoundary() {
        for _ in 0..<5 {
            XCTAssertFalse(press())
        }
        now = 10.0
        XCTAssertEqual(counter.liveCount, 5, "press at exactly the window edge still counts")
    }

    func testLiveCountReadsArePure() {
        XCTAssertFalse(press())
        XCTAssertEqual(counter.liveCount, 1)
        XCTAssertEqual(counter.liveCount, 1, "reads must not mutate the count")
    }
}

import Foundation

/// Counts Command key-down transitions (either side, keyCodes 54/55).
/// `requiredPresses` key-downs within a rolling `windowSeconds` unlock.
/// Timestamps live in a fixed-size ring so memory is bounded; the clock is
/// injectable so expiry is testable headless.
final class UnlockCounter {
    let requiredPresses: Int
    let windowSeconds: Double

    private let clock: () -> Double
    private var ring: [Double]
    private var head = 0
    private var count = 0

    init(
        requiredPresses: Int = 6,
        windowSeconds: Double = 10,
        clock: @escaping () -> Double = { Date().timeIntervalSinceReferenceDate }
    ) {
        precondition(requiredPresses > 0, "requiredPresses must be positive")
        self.requiredPresses = requiredPresses
        self.windowSeconds = windowSeconds
        self.clock = clock
        // Ring needs at most one slot per press in the gesture.
        self.ring = Array(repeating: 0, count: requiredPresses)
    }

    /// Registers one event. Only Command key-down transitions (keyCode 54 or
    /// 55 with the command mask set) count toward the gesture. Returns true
    /// when this press completes the unlock sequence.
    @discardableResult
    func register(keyCode: UInt16, isCommandDown: Bool) -> Bool {
        guard isCommandDown, keyCode == 54 || keyCode == 55 else {
            return false
        }
        let now = clock()
        expireStale(now: now)

        ring[head] = now
        head = (head + 1) % ring.count
        if count < ring.count {
            count += 1
        }
        return count >= requiredPresses
    }

    /// The current in-window press count, expiry-aware: reading it runs
    /// window expiry with the injected clock, so the value is always current
    /// even when no press just arrived. Lets the UI show live "n/6" progress
    /// and reset to 0 when the rolling window closes.
    var liveCount: Int {
        expireStale(now: clock())
        return count
    }

    /// Drops entries older than the window. The oldest live entry sits just
    /// before the next insertion slot.
    private func expireStale(now: Double) {
        while count > 0 {
            let oldestIndex = (head - count + ring.count) % ring.count
            if now - ring[oldestIndex] > windowSeconds {
                count -= 1
            } else {
                break
            }
        }
    }
}

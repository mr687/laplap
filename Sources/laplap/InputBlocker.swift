import CoreGraphics
import Foundation

/// Single CGEventTap at kCGHIDEventTap. The callback returns nil for every
/// event (consume), feeding UnlockCounter first so the unlock gesture is seen
/// before consumption. Fail-safe: tap creation failure returns false, and a
/// tap-disabled callback stops the run loop — input returns because the lock
/// lives only in this process.
final class InputBlocker {
    /// Injects the CGEventTapCreate call so failure is testable headless.
    typealias TapCreator = (UnsafeMutableRawPointer?) -> CFMachPort?

    /// Boxed context passed to the C callback through the tap's userInfo
    /// pointer — no globals, no captures in the C function pointer.
    final class State {
        let counter: UnlockCounter
        /// Wired post-init by CatMode (closures may capture the owner).
        var onUnlock: () -> Void
        var onTapDisabled: () -> Void

        init(counter: UnlockCounter, onUnlock: @escaping () -> Void, onTapDisabled: @escaping () -> Void) {
            self.counter = counter
            self.onUnlock = onUnlock
            self.onTapDisabled = onTapDisabled
        }
    }

    let state: State
    private(set) var tap: CFMachPort?
    private var tapCreator: TapCreator

    init(
        counter: UnlockCounter,
        onUnlock: @escaping () -> Void,
        onTapDisabled: @escaping () -> Void,
        tapCreator: TapCreator? = nil
    ) {
        self.state = State(counter: counter, onUnlock: onUnlock, onTapDisabled: onTapDisabled)
        self.tapCreator = tapCreator ?? Self.defaultTapCreator
    }

    /// Creates and enables the HID event tap. Returns false on failure —
    /// caller treats that as fail-safe (no lock installed).
    @discardableResult
    func install() -> Bool {
        let refcon = Unmanaged.passUnretained(state).toOpaque()
        guard let tap = tapCreator(refcon) else {
            return false
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        return true
    }

    /// Test seam: override the tap creator before install (used by CatMode
    /// wiring tests to run headless).
    func setTapCreator(_ creator: @escaping TapCreator) {
        tapCreator = creator
    }

    /// Wires the tap into a run loop. No-op if the tap was never installed.
    func addRunLoopSource(to runLoop: CFRunLoop) {
        guard let tap else { return }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(runLoop, source, .commonModes)
    }

    // MARK: - Tap plumbing

    nonisolated(unsafe) static let defaultTapCreator: TapCreator = { refcon in
        CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: InputBlocker.allEventsMask,
            callback: InputBlocker.callback,
            userInfo: refcon
        )
    }

    /// Every event type: keyboard, modifier, mouse, tablet, scroll. All valid
    /// CGEventType raw values sit below 32, so bits 0..<32 cover them all
    /// (the synthetic tap-disable types are not part of the interest mask).
    static var allEventsMask: CGEventMask {
        var mask: CGEventMask = 0
        for raw in 0..<32 {
            mask |= CGEventMask(1) << CGEventMask(raw)
        }
        return mask
    }

    /// C-compatible callback. Returns nil to consume every event; feeds the
    /// counter for Command flagsChanged transitions; stops the loop on unlock
    /// or tap-disable.
    nonisolated(unsafe) static let callback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else {
            return nil
        }
        let state = Unmanaged<State>.fromOpaque(refcon).takeUnretainedValue()
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            state.onTapDisabled()
        case .null:
            break
        default:
            if type == .flagsChanged {
                let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
                let isCommandDown = event.flags.contains(.maskCommand)
                if state.counter.register(keyCode: keyCode, isCommandDown: isCommandDown) {
                    state.onUnlock()
                }
            }
        }
        return nil
    }
}

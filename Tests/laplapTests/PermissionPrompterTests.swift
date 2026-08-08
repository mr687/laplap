import XCTest
@testable import laplap

/// PermissionPrompter flow, fully headless: every seam (prompt raiser, trust
/// check, clock, poll interval, handoff) is injected, so no real system
/// prompt, no real `open`, and no real Accessibility grant ever happens.
final class PermissionPrompterTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    /// Clock that returns `t0` for the first `stableCalls` reads, then jumps
    /// 61s into the future so the 60s poll window terminates.
    private func advancingClock(stableCalls: Int) -> () -> Date {
        var calls = 0
        return {
            calls += 1
            return calls <= stableCalls ? self.t0 : self.t0.addingTimeInterval(61)
        }
    }

    // MARK: REQ-1 — prompt raised when untrusted

    func testPromptRaisedWhenUntrusted() {
        var promptCalls = 0
        let trusted = PermissionPrompter.promptAndWait(
            raisePrompt: { promptCalls += 1 },
            isTrusted: { false },
            pollInterval: 0.001,
            maxWait: 60,
            now: advancingClock(stableCalls: 1),
            handoff: {}
        )
        XCTAssertFalse(trusted)
        XCTAssertEqual(promptCalls, 1, "system Accessibility prompt must be raised exactly once when untrusted")
    }

    func testImmediateGrantSkipsHandoff() {
        var handoffCalls = 0
        let trusted = PermissionPrompter.promptAndWait(
            raisePrompt: {},
            isTrusted: { true },
            pollInterval: 0.001,
            maxWait: 60,
            now: { self.t0 },
            handoff: { handoffCalls += 1 }
        )
        XCTAssertTrue(trusted)
        XCTAssertEqual(handoffCalls, 0, "no System Settings handoff when trust is granted at the prompt")
    }

    // MARK: REQ-2 — handoff + poll up to 60s

    func testHandoffRunsWhenStillUntrusted() {
        var handoffCalls = 0
        var trustCalls = 0
        let trusted = PermissionPrompter.promptAndWait(
            raisePrompt: {},
            isTrusted: { trustCalls += 1; return false },
            pollInterval: 0.001,
            maxWait: 60,
            now: advancingClock(stableCalls: 2),
            handoff: { handoffCalls += 1 }
        )
        XCTAssertFalse(trusted)
        XCTAssertEqual(handoffCalls, 1, "System Settings handoff must run when still untrusted after the prompt")
        XCTAssertGreaterThanOrEqual(trustCalls, 2, "trust must be re-checked after the prompt")
    }

    func testGrantDuringPollProceeds() {
        var trustCalls = 0
        var handoffCalls = 0
        let trusted = PermissionPrompter.promptAndWait(
            raisePrompt: {},
            isTrusted: { trustCalls += 1; return trustCalls >= 3 },
            pollInterval: 0.001,
            maxWait: 60,
            now: { self.t0 },
            handoff: { handoffCalls += 1 }
        )
        XCTAssertTrue(trusted, "grant arriving during the poll window must be accepted")
        XCTAssertEqual(handoffCalls, 1)
        XCTAssertGreaterThanOrEqual(trustCalls, 3, "must poll repeatedly until granted")
    }

    // MARK: REQ-3 — 60s expiry leaves the flow untrusted (caller exits 3)

    func testExpiryAfterSixtySecondsReturnsUntrusted() {
        var trustCalls = 0
        let trusted = PermissionPrompter.promptAndWait(
            raisePrompt: {},
            isTrusted: { trustCalls += 1; return false },
            pollInterval: 0.001,
            maxWait: 60,
            now: advancingClock(stableCalls: 2),
            handoff: {}
        )
        XCTAssertFalse(trusted, "flow must report untrusted once the 60s window expires")
        XCTAssertGreaterThanOrEqual(trustCalls, 2, "trust must be polled inside the window before expiry")
    }
}

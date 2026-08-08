import XCTest
@testable import laplap

final class PermissionGateTests: XCTestCase {
    func testGuidanceMessageMentionsAccessibility() {
        XCTAssertTrue(PermissionGate.guidanceMessage.contains("Accessibility"))
        XCTAssertTrue(PermissionGate.guidanceMessage.contains("System Settings"))
    }

    func testTrustedProcessPassesGate() {
        // Stub says trusted -> no exit, gate opens.
        XCTAssertTrue(PermissionGate.isTrusted(stub: { true }))
    }

    func testUntrustedProcessFailsGate() {
        XCTAssertFalse(PermissionGate.isTrusted(stub: { false }))
    }
}

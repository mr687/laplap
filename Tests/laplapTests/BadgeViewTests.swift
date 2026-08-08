import AppKit
import XCTest
@testable import laplap

/// BadgeView config asserts on a real NSWindow (AppKit window creation works
/// in XCTest; rendering appearance itself stays manual).
@MainActor
final class BadgeViewTests: XCTestCase {
    func testLabelText() {
        XCTAssertEqual(BadgeView.labelText, "CAT MODE — CMD x6 to exit")
    }

    func testWindowConfiguration() {
        let badge = BadgeView()
        XCTAssertEqual(badge.level, .floating)
        XCTAssertTrue(badge.ignoresMouseEvents, "badge must never intercept mouse events")
        XCTAssertFalse(badge.isOpaque, "badge must be semi-transparent")
        XCTAssertEqual(badge.styleMask, [.borderless])
        XCTAssertEqual(badge.label.text, BadgeView.labelText)
        XCTAssertNotNil(badge.backgroundColor)
    }

    func testAnchoredTopRightOfScreen() {
        let visible = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = BadgeView.anchor(in: visible, pillSize: CGSize(width: 200, height: 34))
        XCTAssertEqual(frame.maxX, visible.maxX - 12, accuracy: 0.5, "hug right edge")
        XCTAssertEqual(frame.maxY, visible.maxY - 12, accuracy: 0.5, "hug top edge")
        XCTAssertTrue(visible.contains(frame))
    }

    func testAnchorClampedInsideTinyScreen() {
        let tiny = NSRect(x: 0, y: 0, width: 100, height: 40)
        let frame = BadgeView.anchor(in: tiny, pillSize: CGSize(width: 200, height: 34))
        // Pill is wider than the screen: it cannot be fully contained, but its
        // origin must stay inside the visible frame (clamped).
        XCTAssertGreaterThanOrEqual(frame.minX, tiny.minX)
        XCTAssertGreaterThanOrEqual(frame.minY, tiny.minY)
        XCTAssertEqual(frame.minX, tiny.minX, accuracy: 0.5, "clamped to the left edge for an oversized pill")
    }
}

import AppKit

/// Small semi-transparent borderless pill window: "CAT MODE — CMD x6 to exit",
/// top-right of the main screen, floating above normal windows but
/// mouse-transparent and non-activating. Purely informational.
@MainActor
final class BadgeView: NSWindow {
    static let labelText = "CAT MODE — CMD x6 to exit"

    private static let margin: CGFloat = 12

    /// The pill's content view; exposed so tests can assert the label.
    var label: BadgeLabel { contentView as! BadgeLabel }

    /// Places the pill at the top-right of `screenFrame`, clamped inside it.
    /// Pure so clamping is testable headless.
    static func anchor(in screenFrame: NSRect, pillSize: CGSize, margin: CGFloat = BadgeView.margin) -> NSRect {
        var origin = CGPoint(
            x: screenFrame.maxX - pillSize.width - margin,
            y: screenFrame.maxY - pillSize.height - margin
        )
        origin.x = min(max(origin.x, screenFrame.minX), max(screenFrame.minX, screenFrame.maxX - pillSize.width))
        origin.y = min(max(origin.y, screenFrame.minY), max(screenFrame.minY, screenFrame.maxY - pillSize.height))
        return NSRect(origin: origin, size: pillSize)
    }

    convenience init() {
        self.init(screen: NSScreen.main)
    }

    convenience init(screen: NSScreen?) {
        let text = Self.labelText as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold)
        ]
        let textSize = text.size(withAttributes: attributes)
        let padding: CGFloat = 16
        let pillSize = CGSize(
            width: ceil(textSize.width) + padding * 2,
            height: ceil(textSize.height) + 10
        )
        let screenFrame = screen?.visibleFrame ?? .zero
        let frame = Self.anchor(in: screenFrame, pillSize: pillSize)

        self.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)

        contentView = BadgeLabel(text: Self.labelText)
        isReleasedWhenClosed = false
        level = .floating
        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }
}

/// Pill-shaped label drawn by the badge.
@MainActor
final class BadgeLabel: NSView {
    let text: String

    init(text: String) {
        self.text = text
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 17
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(
            at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2),
            withAttributes: attributes
        )
    }
}

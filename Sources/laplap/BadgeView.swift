import AppKit

/// Small semi-transparent borderless pill window: "CAT MODE — ⌘ ×6 to exit",
/// top-right of the main screen, floating above normal windows but
/// mouse-transparent and non-activating. Purely informational.
@MainActor
final class BadgeView: NSWindow {
    static let labelText = "CAT MODE — ⌘ ×6 to exit"
    /// Fade duration for arm/teardown (see FadeAnimation).
    static let fadeDuration: TimeInterval = FadeAnimation.duration

    private static let margin: CGFloat = 12

    /// The pill's content view; exposed so tests can assert the label.
    var label: BadgeLabel { contentView as! BadgeLabel }

    /// Live unlock progress: count > 0 shows "CAT MODE — ⌘ n/6", count == 0
    /// restores the baseline label (window expired or not yet started).
    func setProgress(_ count: Int, of required: Int) {
        label.text = count > 0 ? "CAT MODE — ⌘ \(count)/\(required)" : Self.labelText
    }

    /// Fade-in from alpha 0 to 1. Call right after orderFrontRegardless.
    func fadeIn() {
        alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            animator().alphaValue = 1
        }
    }

    /// Fade out to 0, then order out and close. The bounded main-run-loop
    /// spin lets the fade render before the process exits; the input tap is
    /// already stopped at this point, so only the fade itself (≤ 0.15s)
    /// delays exit — never input.
    func fadeOutAndClose() {
        guard alphaValue > 0 else {
            orderOut(nil)
            close()
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.fadeDuration
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.close()
        })
        RunLoop.main.run(until: Date().addingTimeInterval(Self.fadeDuration + 0.05))
    }

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
    var text: String {
        didSet { needsDisplay = true }
    }

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

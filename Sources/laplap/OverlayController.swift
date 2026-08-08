import AppKit
import CoreGraphics
import Foundation

/// One screen as seen by the overlay controller: the frame to cover and the
/// display ID for cursor control. Decouples the controller from NSScreen so
/// headless tests inject synthetic screens.
struct OverlayScreen {
    let frame: NSRect
    let displayID: CGDirectDisplayID

    static func from(_ screen: NSScreen) -> OverlayScreen {
        OverlayScreen(frame: screen.frame, displayID: screen.displayID)
    }
}

extension NSScreen {
    /// The screen's CGDirectDisplayID, read from the device-description
    /// "NSScreenNumber" key (AppKit exposes no direct property).
    var displayID: CGDirectDisplayID {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return 0 }
        return CGDirectDisplayID(number.uint32Value)
    }
}

/// Injectable seam over the per-display cursor APIs so hide/show is trackable
/// headless (real calls are visual and per-display).
protocol CursorControlling: AnyObject {
    func hide(on displayID: CGDirectDisplayID)
    func show(on displayID: CGDirectDisplayID)
}

/// Production cursor controller: delegates straight to CoreGraphics.
final class SystemCursorController: CursorControlling {
    func hide(on displayID: CGDirectDisplayID) {
        CGDisplayHideCursor(displayID)
    }

    func show(on displayID: CGDirectDisplayID) {
        CGDisplayShowCursor(displayID)
    }
}

/// One fullscreen black overlay window hosting the centered exit-instruction
/// stack: bold title, subtitle, and the live progress line (e06s01). Purely
/// visual: ignores mouse events so the lock underneath keeps consuming input.
@MainActor
final class OverlayWindow: NSWindow {
    /// Fade duration for arm/teardown (see FadeAnimation).
    static let fadeDuration: TimeInterval = FadeAnimation.duration

    /// Bold 34pt title.
    let titleLabel: NSTextField
    /// 18pt subtitle (the instruction line).
    let subtitleLabel: NSTextField
    /// Live "⌘ n/6" progress line; hidden until a press lands.
    let progressField: NSTextField

    /// The instruction subtitle; kept for headless asserts.
    var label: NSTextField { subtitleLabel }

    init(config: OverlayController.OverlayConfig, frame: NSRect) {
        let title = NSTextField(labelWithString: config.titleText)
        title.textColor = .white
        title.font = NSFont.systemFont(ofSize: 34, weight: .bold)
        title.alignment = .center

        let subtitle = NSTextField(labelWithString: config.subtitleText)
        subtitle.textColor = .white.withAlphaComponent(0.85)
        subtitle.font = NSFont.systemFont(ofSize: 18, weight: .regular)
        subtitle.alignment = .center

        let progress = NSTextField(labelWithString: "")
        progress.textColor = .white
        progress.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        progress.alignment = .center
        progress.isHidden = true

        self.titleLabel = title
        self.subtitleLabel = subtitle
        self.progressField = progress

        let stack = NSStackView(views: [title, subtitle, progress])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        super.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)

        contentView = container
        isReleasedWhenClosed = false
        level = config.level
        ignoresMouseEvents = config.ignoresMouseEvents
        isOpaque = true
        backgroundColor = config.backgroundColor
        hasShadow = false
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
}

/// Fullscreen black overlays: one NSWindow per screen at screenSaver level,
/// mouse-transparent, rebuilt on NSScreen.didChangeNotification, with the
/// cursor hidden per display while armed. All headless-testable seams are
/// injectable: the screen provider, the cursor controller, and the config.
@MainActor
final class OverlayController {
    /// Headless-testable configuration surface for the overlay windows.
    struct OverlayConfig {
        static let standard = OverlayConfig()

        let level: NSWindow.Level
        let ignoresMouseEvents: Bool
        let backgroundColor: NSColor
        let titleText: String
        let subtitleText: String

        init(
            level: NSWindow.Level = .screenSaver,
            ignoresMouseEvents: Bool = true,
            backgroundColor: NSColor = .black,
            titleText: String = "CLEANING MODE",
            subtitleText: String = "Press ⌘ 6 times to exit"
        ) {
            self.level = level
            self.ignoresMouseEvents = ignoresMouseEvents
            self.backgroundColor = backgroundColor
            self.titleText = titleText
            self.subtitleText = subtitleText
        }
    }

    let config: OverlayConfig
    private let screenProvider: () -> [OverlayScreen]
    private let cursor: CursorControlling

    private(set) var overlayWindows: [NSWindow] = []
    private(set) var cursorHidden = false
    private var hiddenDisplayIDs: [CGDirectDisplayID] = []
    private var screenObserver: NSObjectProtocol?

    /// Screen count from the injectable provider — the window count the
    /// controller arms one overlay for.
    var windowCount: Int { screenProvider().count }

    init(
        config: OverlayConfig = .standard,
        screenProvider: @escaping () -> [OverlayScreen] = { NSScreen.screens.map(OverlayScreen.from) },
        cursor: CursorControlling = SystemCursorController()
    ) {
        self.config = config
        self.screenProvider = screenProvider
        self.cursor = cursor
    }

    /// Arms the overlays: one window per screen, cursor hidden for each
    /// display, observer registered for screen configuration changes.
    func arm() {
        guard overlayWindows.isEmpty else { return }
        createOverlays()
        hideCursor()
        registerScreenObserver()
    }

    /// Tears down overlays (fade out) and restores the cursor. Idempotent;
    /// safe to call before arm.
    func disarm() {
        restoreCursor()
        fadeOutAndCloseOverlays()
        unregisterScreenObserver()
    }

    /// Live unlock progress: shows "⌘ n/6" on every overlay while count > 0,
    /// hides the line at 0 (window expired or not yet started). Driven by the
    /// same onProgress path as the badge.
    func setProgress(_ count: Int, of required: Int) {
        for window in overlayWindows {
            guard let overlay = window as? OverlayWindow else { continue }
            overlay.progressField.isHidden = count == 0
            overlay.progressField.stringValue = count > 0 ? "⌘ \(count)/\(required)" : ""
        }
    }

    /// Screen configuration changed (display plugged/unplugged): tear down
    /// and re-create all overlays, re-pairing the cursor with the current
    /// display IDs. Delivered on the main queue by the notification observer.
    /// Rebuild uses plain close (no fade spin) — the lock is still active
    /// while input is being consumed, so the run loop must not stall.
    func rebuild() {
        restoreCursor()
        closeOverlays()
        createOverlays()
        hideCursor()
    }

    /// Restores the cursor for every display clean mode hid. No-op when clean
    /// mode never hid it (cursor control is scoped to clean mode only).
    func restoreCursor() {
        guard cursorHidden else { return }
        for id in hiddenDisplayIDs {
            cursor.show(on: id)
        }
        hiddenDisplayIDs = []
        cursorHidden = false
    }

    // MARK: - Private

    private func createOverlays() {
        for screen in screenProvider() {
            let window = OverlayWindow(config: config, frame: screen.frame)
            window.orderFrontRegardless()
            window.fadeIn()
            overlayWindows.append(window)
        }
    }

    private func closeOverlays() {
        for window in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows = []
    }

    /// Animated close used on disarm (process exiting): fades each overlay out
    /// before closing. Fast path (no spin) when never faded in — the state
    /// headless tests see.
    private func fadeOutAndCloseOverlays() {
        for window in overlayWindows {
            if let overlay = window as? OverlayWindow {
                overlay.fadeOutAndClose()
            } else {
                window.orderOut(nil)
                window.close()
            }
        }
        overlayWindows = []
    }

    private func hideCursor() {
        guard !cursorHidden else { return }
        let ids = screenProvider().map(\.displayID)
        for id in ids {
            cursor.hide(on: id)
        }
        hiddenDisplayIDs = ids
        cursorHidden = true
    }

    private func registerScreenObserver() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Defer the rebuild to the main queue so the run loop that is
            // consuming input is never blocked by overlay work.
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.rebuild()
                }
            }
        }
    }

    private func unregisterScreenObserver() {
        guard let screenObserver else { return }
        NotificationCenter.default.removeObserver(screenObserver)
        self.screenObserver = nil
    }
}

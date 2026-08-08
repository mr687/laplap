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
/// label. Purely visual: ignores mouse events so the lock underneath keeps
/// consuming input.
@MainActor
final class OverlayWindow: NSWindow {
    /// The centered instruction label (the content view); exposed for
    /// headless asserts.
    var label: NSTextField { contentView as! NSTextField }

    init(config: OverlayController.OverlayConfig, frame: NSRect) {
        let label = NSTextField(labelWithString: config.labelText)
        label.textColor = .white
        label.backgroundColor = .black
        label.drawsBackground = true
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 28, weight: .medium)
        label.autoresizingMask = [.width, .height]
        label.frame = NSRect(origin: .zero, size: frame.size)

        super.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)

        contentView = label
        isReleasedWhenClosed = false
        level = config.level
        ignoresMouseEvents = config.ignoresMouseEvents
        isOpaque = true
        backgroundColor = config.backgroundColor
        hasShadow = false
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
        let labelText: String

        init(
            level: NSWindow.Level = .screenSaver,
            ignoresMouseEvents: Bool = true,
            backgroundColor: NSColor = .black,
            labelText: String = "CLEANING MODE — press CMD 6 times to exit"
        ) {
            self.level = level
            self.ignoresMouseEvents = ignoresMouseEvents
            self.backgroundColor = backgroundColor
            self.labelText = labelText
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

    /// Tears down overlays and restores the cursor. Idempotent; safe to call
    /// before arm.
    func disarm() {
        restoreCursor()
        closeOverlays()
        unregisterScreenObserver()
    }

    /// Screen configuration changed (display plugged/unplugged): tear down
    /// and re-create all overlays, re-pairing the cursor with the current
    /// display IDs. Delivered on the main queue by the notification observer.
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

import Foundation

/// Shared fade duration for the badge and every overlay window. Capped at
/// 0.15s (story budget ≤ 0.3s) so the unlock exit is never delayed by more
/// than the fade itself; animations never block the run loop.
enum FadeAnimation {
    static let duration: TimeInterval = 0.15
}

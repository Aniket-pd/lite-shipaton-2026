import Observation
import SwiftUI

/// Uses finger movement, not layout-driven content offsets, so resizing the
/// viewport cannot cause the toolbar to oscillate between its two states.
@Observable
@MainActor
final class BrowserChromeState {
    private(set) var isCollapsed = false
    var isKeyboardVisible = false
    @ObservationIgnored private var travel: CGFloat = 0
    @ObservationIgnored private var direction: CGFloat = 0

    // Match WebPage's workaround for the Swift isolated-deinit runtime bug on
    // iOS 26.2 and earlier (swiftlang/swift#88036).
    nonisolated deinit {}

    func beginGesture() {
        travel = 0
        direction = 0
    }

    func expand() {
        isCollapsed = false
        travel = 0
        direction = 0
    }

    func scroll(delta: CGFloat, distanceFromTop: CGFloat, canCollapse: Bool) {
        guard canCollapse, !isKeyboardVisible else { expand(); return }
        guard delta.isFinite, distanceFromTop.isFinite, abs(delta) > 0.5 else { return }
        if distanceFromTop <= 4 {
            expand()
            return
        }
        let nextDirection: CGFloat = delta > 0 ? 1 : -1
        if direction != nextDirection { travel = 0; direction = nextDirection }
        travel += abs(delta)
        if !isCollapsed, direction > 0, distanceFromTop > 80, travel >= 64 {
            isCollapsed = true
            travel = 0
        } else if isCollapsed, direction < 0, travel >= 24 {
            expand()
        }
    }
}

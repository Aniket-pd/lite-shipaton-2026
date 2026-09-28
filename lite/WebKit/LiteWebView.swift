import SwiftUI
import WebKit

struct LiteWebView: UIViewRepresentable {
    let webView: WKWebView
    var websiteColorScheme: ColorScheme?
    var bottomObscuredInset: CGFloat = 0
    var onScrollBegan: (() -> Void)?
    var onScroll: ((CGFloat, CGFloat) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.attach(to: webView)
        updateUIView(webView, context: context)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onScrollBegan = onScrollBegan
        context.coordinator.onScroll = onScroll
        if #available(iOS 26, *) {
            // This public WebKit API keeps fixed/sticky website controls above
            // native chrome while allowing page content to paint behind its glass.
            // The host measures the changing footprint while the toolbar morphs.
            let insets = UIEdgeInsets(top: 0, left: 0, bottom: max(0, bottomObscuredInset), right: 0)
            if uiView.obscuredContentInsets != insets {
                uiView.obscuredContentInsets = insets
            }
        }
        if let websiteColorScheme {
            // The presentation's color scheme controls status-bar contrast.
            // Web content continues to follow the user's actual appearance.
            uiView.overrideUserInterfaceStyle = websiteColorScheme == .dark ? .dark : .light
            uiView.backgroundColor = UIColor.systemBackground.resolvedColor(with: uiView.traitCollection)
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject {
        var onScrollBegan: (() -> Void)?
        var onScroll: ((CGFloat, CGFloat) -> Void)?
        private weak var webView: WKWebView?
        private var previousTranslation: CGFloat = 0

        func attach(to webView: WKWebView) {
            self.webView = webView
            webView.scrollView.panGestureRecognizer.addTarget(self, action: #selector(panned(_:)))
        }

        func detach() {
            webView?.scrollView.panGestureRecognizer.removeTarget(self, action: #selector(panned(_:)))
            onScrollBegan = nil
            onScroll = nil
            webView = nil
        }

        @objc private func panned(_ gesture: UIPanGestureRecognizer) {
            guard let scrollView = webView?.scrollView else { return }
            let translation = gesture.translation(in: scrollView)
            if gesture.state == .began {
                previousTranslation = translation.y
                onScrollBegan?()
                return
            }
            let delta = previousTranslation - translation.y
            previousTranslation = translation.y
            guard gesture.state == .changed else { return }
            let velocity = gesture.velocity(in: scrollView)
            let distance = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
            let extent = scrollView.contentSize.height + scrollView.adjustedContentInset.top +
                scrollView.adjustedContentInset.bottom - scrollView.bounds.height
            // Ignore horizontal history gestures, short documents, and bounce.
            guard abs(velocity.y) > abs(velocity.x), extent > 100,
                  distance >= 0, distance <= extent else { return }
            onScroll?(delta, distance)
        }
    }
}

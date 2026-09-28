import SwiftUI
import UIKit

/// A cover in the containing window also conceals native previews and sheets,
/// which are presented above the SwiftUI container's own privacy cover.
struct ContainerPrivacyShield: UIViewRepresentable {
    let isProtected: Bool
    let isActive: Bool

    func makeUIView(context: Context) -> ShieldAnchor {
        ShieldAnchor()
    }

    func updateUIView(_ view: ShieldAnchor, context: Context) {
        view.isProtected = isProtected
        view.setCovered(isProtected && !isActive)
    }

    static func dismantleUIView(_ view: ShieldAnchor, coordinator: ()) {
        view.dispose()
    }

    final class ShieldAnchor: UIView {
        var isProtected = false
        private weak var protectedWindow: UIWindow?
        private var cover: UIView?
        private var needsCover = false

        init() {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            NotificationCenter.default.addObserver(self, selector: #selector(willResignActive),
                                                  name: UIApplication.willResignActiveNotification, object: nil)
        }

        required init?(coder: NSCoder) { nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            // A fullscreen presentation may detach its presenter's view. Keep
            // the same window protected for the lifetime of this access scope.
            if let window { protectedWindow = window }
            if needsCover { setCovered(true) }
        }

        @objc private func willResignActive() {
            if isProtected { setCovered(true) }
        }

        func setCovered(_ covered: Bool) {
            needsCover = covered
            guard covered else {
                cover?.removeFromSuperview()
                cover = nil
                return
            }
            guard let window = window ?? protectedWindow else { return }
            if let cover {
                window.bringSubviewToFront(cover)
                return
            }
            let cover = UIView(frame: window.bounds)
            cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            cover.backgroundColor = .systemBackground
            cover.accessibilityViewIsModal = true
            let label = UILabel()
            label.text = "Lite is locked"
            label.font = .preferredFont(forTextStyle: .headline)
            label.adjustsFontForContentSizeCategory = true
            label.translatesAutoresizingMaskIntoConstraints = false
            cover.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: cover.centerYAnchor)
            ])
            window.addSubview(cover)
            self.cover = cover
        }

        func dispose() {
            NotificationCenter.default.removeObserver(self)
            setCovered(false)
        }
    }
}

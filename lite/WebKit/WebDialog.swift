import Foundation

/// Owns the WebKit callback and guarantees it is completed at most once.
@MainActor
final class WebDialog: Identifiable {
    enum Kind { case notice, alert, confirm, text, external }

    let id = UUID()
    let kind: Kind
    let title: String
    let message: String
    let defaultText: String
    private var completion: ((String?) -> Void)?

    init(kind: Kind, title: String, message: String, defaultText: String = "", completion: ((String?) -> Void)? = nil) {
        self.kind = kind
        self.title = title
        self.message = message
        self.defaultText = defaultText
        self.completion = completion
    }

    func complete(with text: String?) {
        let callback = completion
        completion = nil
        callback?(text)
    }
}

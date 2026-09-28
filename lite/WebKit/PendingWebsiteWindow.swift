import Foundation
import Observation
import WebKit

/// Retain WebKit's original window/request until the person opens or dismisses it.
/// Holding the policy callback preserves POST bodies and the opener relationship.
@MainActor
@Observable
final class PendingWebsiteWindow {
    let page: WebPage
    let openerID: UUID
    let sourceOrigin: String?
    var destination: URL
    @ObservationIgnored private var decision: ((WKNavigationActionPolicy) -> Void)?

    nonisolated deinit {}

    init(page: WebPage, opener: WebPage, sourceURL: URL?, destination: URL) {
        self.page = page
        openerID = opener.id
        sourceOrigin = WebNavigationPolicy.origin(of: sourceURL)
        self.destination = destination
    }

    var destinationLabel: String { destination.host ?? "New website window" }

    func hold(_ callback: @escaping (WKNavigationActionPolicy) -> Void, destination: URL) {
        // Always resolve an older request if the website changes its destination.
        resolve(.cancel)
        self.destination = destination
        decision = callback
    }

    func resolve(_ policy: WKNavigationActionPolicy) {
        let callback = decision
        decision = nil
        callback?(policy)
    }
}

import Foundation
import Observation

struct OpenAppRequest: Identifiable, Equatable {
    let id = UUID()
    let appID: UUID
}

@Observable
@MainActor
final class AppOpenCoordinator {
    // Avoid Swift 6.2.4 isolated-deinit back-deployment crash on iOS 26.2.
    nonisolated deinit {}

    private(set) var request: OpenAppRequest?
    private(set) var invalidRequestMessage: String?

    func open(_ appID: UUID) {
        invalidRequestMessage = nil
        request = OpenAppRequest(appID: appID)
    }

    func close() {
        request = nil
    }

    func handle(_ url: URL) {
        guard url.scheme?.lowercased() == "lite",
              url.host?.lowercased() == "open",
              url.user == nil, url.password == nil, url.port == nil,
              url.query == nil, url.fragment == nil, url.pathComponents.count == 2,
              let rawID = url.pathComponents.dropFirst().first,
              let id = UUID(uuidString: rawID) else {
            invalidRequestMessage = "That Lite App link is invalid."
            return
        }
        open(id)
    }

    func consumePendingIntent() {
        if let id = LiteMetadataStore.takePendingOpen() { open(id) }
    }

    func markMissing() {
        request = nil
        invalidRequestMessage = "That Lite App was deleted or is no longer available."
    }

    func clearMessage() { invalidRequestMessage = nil }
}

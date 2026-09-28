import SwiftData
import WebKit

@MainActor
enum ProfileDeletionService {
    private static var inFlight: Set<UUID> = []

    static func delete(_ app: LiteApp, in context: ModelContext) throws {
        context.insert(PendingProfileDeletion(identifier: app.dataStoreIdentifier))
        context.delete(app)
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    // Only identified stores whose owning models were deleted are touched.
    // Called again on launch, so an interrupted or busy WebKit process is retryable.
    static func finishPendingDeletions(in context: ModelContext) async throws {
        let pending = try context.fetch(FetchDescriptor<PendingProfileDeletion>())
        var firstError: Error?
        for receipt in pending {
            try Task.checkCancellation()
            let identifier = receipt.identifier
            // MainActor is reentrant during WebKit's async call. A launch drain and
            // a user deletion may overlap, but must never remove one profile twice.
            guard inFlight.insert(identifier).inserted else { continue }
            do {
                // Bootstraps WebKit if needed, without creating a profile or page.
                WebProfileStore.prepareForRemoval(identifier: identifier)
                try await WKWebsiteDataStore.remove(forIdentifier: identifier)
                try ProxyCredentialStore.remove(profile: identifier)
                try SavedContentStore.shared.removeProfile(identifier)
                try WebDownload.removeTemporaryFiles(profileID: identifier)
                let liveReceipts = try context.fetch(FetchDescriptor<PendingProfileDeletion>(
                    predicate: #Predicate { $0.identifier == identifier }
                ))
                liveReceipts.forEach { context.delete($0) }
                try context.save()
            } catch {
                context.rollback()
                if firstError == nil { firstError = error }
            }
            inFlight.remove(identifier)
        }
        if let firstError { throw firstError }
    }
}

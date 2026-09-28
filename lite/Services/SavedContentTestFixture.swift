#if DEBUG
import Foundation
import SwiftData

/// Separate UI-test storage and deterministic profiles; never used in a normal launch.
enum SavedContentTestFixture {
    static func seed(in context: ModelContext) throws {
        let store = SavedContentStore.shared
        let publicApp = LiteApp(name: "Public Fixture", url: URL(string: "https://example.com")!)
        publicApp.id = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAA1")!
        publicApp.dataStoreIdentifier = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBB1")!
        let lockedApp = LiteApp(name: "Locked Fixture", url: publicApp.url, isBiometricLocked: true)
        lockedApp.id = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAA2")!
        lockedApp.dataStoreIdentifier = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBB2")!
        let emptyApp = LiteApp(name: "Empty Locked Fixture", url: publicApp.url, isBiometricLocked: true)
        emptyApp.id = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAA3")!
        emptyApp.dataStoreIdentifier = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBB3")!
        for app in [publicApp, lockedApp, emptyApp] {
            context.insert(app)
            if !ProcessInfo.processInfo.arguments.contains("--uitesting-preserve-saved") {
                try store.removeProfile(app.dataStoreIdentifier)
            }
        }
        try context.save()
        guard !ProcessInfo.processInfo.arguments.contains("--uitesting-preserve-saved") else { return }
        if !ProcessInfo.processInfo.arguments.contains("--uitesting-saved-locked-only") {
            try store.addBookmark(profileID: publicApp.dataStoreIdentifier, title: "Public saved article",
                                  url: URL(string: "https://example.com/public-saved")!)
            try addFile(name: "public-guide.txt", content: "Public saved download", app: publicApp, store: store)
        }
        try store.addBookmark(profileID: lockedApp.dataStoreIdentifier, title: "Confidential saved article",
                              url: URL(string: "https://example.com/confidential")!)
        try addFile(name: "confidential-report.txt", content: "Confidential saved download", app: lockedApp, store: store)
        if ProcessInfo.processInfo.arguments.contains("--uitesting-saved-layout-fixture") {
            for (index, title) in ["Zebra reference", "Alpha reference", "Guide 10", "Guide 2"].enumerated() {
                try store.addBookmark(profileID: publicApp.dataStoreIdentifier, title: title,
                                      url: URL(string: "https://example.com/layout/\(index)")!)
            }
            try addFile(name: "Guide 10.txt", content: "Guide ten", app: publicApp, store: store)
            try addFile(name: "Guide 2.txt", content: "Guide two", app: publicApp, store: store)
            let activeID = UUID()
            try store.beginDownload(id: activeID, profileID: publicApp.dataStoreIdentifier,
                                    filename: "design-assets.zip", sourceURL: publicApp.url)
            store.updateDownload(id: activeID, profileID: publicApp.dataStoreIdentifier, progress: 0.64, byteCount: 18_000_000)
        }
    }

    private static func addFile(name: String, content: String, app: LiteApp, store: SavedContentStore) throws {
        let id = UUID()
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(id.uuidString)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        try Data(content.utf8).write(to: temporaryURL)
        try store.beginDownload(id: id, profileID: app.dataStoreIdentifier, filename: name, sourceURL: app.url)
        try store.finishDownload(id: id, profileID: app.dataStoreIdentifier, temporaryURL: temporaryURL)
    }
}
#endif

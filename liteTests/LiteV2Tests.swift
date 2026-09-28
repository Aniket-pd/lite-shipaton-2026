import Foundation
import SwiftData
import WebKit
import XCTest
@testable import lite

@MainActor
final class LiteV2Tests: XCTestCase {
    func testDuplicateRetainsPreferencesButNeverProfileOrResumeIdentity() {
        let original = LiteApp(name: "Work", url: URL(string: "https://example.com")!, isBiometricLocked: true)
        original.isBlockingEnabled = false
        original.launchPagePreference = .continueLast
        original.lastPageURL = URL(string: "https://example.com/private")
        original.isVisibleInWidget = true
        let copy = original.duplicate()
        XCTAssertNotEqual(original.id, copy.id)
        XCTAssertNotEqual(original.dataStoreIdentifier, copy.dataStoreIdentifier)
        XCTAssertTrue(copy.isBiometricLocked)
        XCTAssertFalse(copy.isBlockingEnabled)
        XCTAssertNil(copy.lastPageURL)
        XCTAssertFalse(copy.isVisibleInWidget)
        XCTAssertEqual(copy.initialURL, original.url)
    }

    func testResumeExcludesAuthenticationForeignOriginsAndQueries() {
        let start = URL(string: "https://www.example.com")!
        for address in ["https://evil.example.com/feed", "https://com/feed", "https://example.com.evil.com/feed", "http://example.com/feed", "https://example.com/login", "https://example.com/oauth/callback", "https://example.com/feed?authToken=secret", "https://example.com:8443/feed", "https://example.com/feed?q=private"] {
            XCTAssertNil(ResumeURLPolicy.sanitizedCandidate(URL(string: address)!, for: start), address)
        }
        XCTAssertEqual(ResumeURLPolicy.sanitizedCandidate(URL(string: "https://example.com/feed#token")!, for: start)?.absoluteString, "https://example.com/feed")
    }

    func testDeepLinksAreStrictAndEveryOpenGetsANewAuthenticationIdentity() {
        let coordinator = AppOpenCoordinator()
        let id = UUID()
        coordinator.handle(URL(string: "lite://open/\(id)")!)
        XCTAssertEqual(coordinator.request?.appID, id)
        let first = coordinator.request?.id
        coordinator.open(id)
        XCTAssertNotEqual(first, coordinator.request?.id)
        coordinator.close()
        for address in ["lite://open/\(id)/extra", "lite://open/\(id)?url=https://evil.com", "lite://open/not-a-uuid", "https://open/\(id)"] {
            coordinator.handle(URL(string: address)!)
            XCTAssertNil(coordinator.request)
            XCTAssertNotNil(coordinator.invalidRequestMessage)
        }
    }

    func testPendingShortcutIsConsumedExactlyOnce() {
        let id = UUID()
        LiteMetadataStore.setPendingOpen(id, notify: false)
        let coordinator = AppOpenCoordinator()
        coordinator.consumePendingIntent()
        XCTAssertEqual(coordinator.request?.appID, id)
        coordinator.close()
        coordinator.consumePendingIntent()
        XCTAssertNil(coordinator.request)
    }

    func testWidgetMetadataIncludesOnlyOptedInAppsAndNoWebsiteURLs() throws {
        let visible = LiteApp(name: "Visible", url: URL(string: "https://example.com/private")!)
        let hidden = LiteApp(name: "Hidden", url: visible.url, isBiometricLocked: true)
        visible.isVisibleInWidget = true
        visible.iconData = Data([1, 2, 3])
        LiteMetadataStore.update(from: [visible, hidden])
        defer { LiteMetadataStore.update(from: []) }
        XCTAssertEqual(LiteMetadataStore.widgetEntries().map(\.id), [visible.id])
        XCTAssertNil(LiteMetadataStore.widgetEntries().first?.iconData)
        XCTAssertEqual(LiteMetadataStore.shortcutEntries().count, 2)
        let text = String(decoding: try JSONEncoder().encode(LiteMetadataStore.widgetEntries()), as: UTF8.self)
        XCTAssertFalse(text.contains("example.com"))
        XCTAssertFalse(text.contains(visible.dataStoreIdentifier.uuidString))
    }

    func testLegacyIconBackfillUpdatesMissingProfilesAndPreservesExistingArt() async throws {
        let container = try ModelContainer(
            for: LiteApp.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = container.mainContext
        let first = LiteApp(name: "First", url: URL(string: "https://example.com/one")!)
        let second = LiteApp(name: "Second", url: URL(string: "https://example.com/two")!)
        let existing = LiteApp(
            name: "Existing",
            url: URL(string: "https://other.example")!,
            iconData: Data([7])
        )
        [first, second, existing].forEach(context.insert)
        try context.save()

        let fetched = Data([1, 2, 3])
        let count = await IconBackfillService.backfill(apps: [first, second, existing], in: context) { url in
            XCTAssertEqual(url.host, "example.com")
            return fetched
        }

        XCTAssertEqual(count, 2)
        XCTAssertEqual(first.iconData, fetched)
        XCTAssertEqual(second.iconData, fetched)
        XCTAssertEqual(existing.iconData, Data([7]))
    }

    func testPopulatedV1StoreMigratesWithoutChangingIdentities() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Library.store")
        let id = UUID(), profileID = UUID(), deletionID = UUID()
        try writeV1Store(url: url, id: id, profileID: profileID, deletionID: deletionID)
        let container = try ModelContainer(for: LiteApp.self, PendingProfileDeletion.self,
            configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let app = try XCTUnwrap(context.fetch(FetchDescriptor<LiteApp>()).first)
        XCTAssertEqual(app.id, id)
        XCTAssertEqual(app.dataStoreIdentifier, profileID)
        XCTAssertEqual(app.name, "Existing Account")
        XCTAssertEqual(app.iconData, Data([1, 2, 3]))
        XCTAssertTrue(app.isBiometricLocked)
        XCTAssertFalse(app.isBlockingEnabled)
        XCTAssertEqual(app.launchPagePreference, .start)
        XCTAssertNil(app.lastPageURL)
        XCTAssertFalse(app.isFavorite)
        XCTAssertFalse(app.isVisibleInWidget)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PendingProfileDeletion>()).first?.identifier, deletionID)
    }

    private func writeV1Store(url: URL, id: UUID, profileID: UUID, deletionID: UUID) throws {
        let container = try ModelContainer(for: V1Fixture.LiteApp.self, V1Fixture.PendingProfileDeletion.self,
            configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        let context = ModelContext(container)
        context.insert(V1Fixture.LiteApp(id: id, profileID: profileID))
        context.insert(V1Fixture.PendingProfileDeletion(identifier: deletionID))
        try context.save()
    }

    func testBlobDownloadUsesWebKitAndPersistsAfterSessionCloses() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("WebDownloadTests-\(UUID())")
        let store = SavedContentStore(rootURL: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = LiteApp(name: "Download", url: URL(string: "https://example.com")!)
        let session = WebSession(app: app, savedStore: store)
        defer { session.close() }
        let protectionReady = await session.setBlockingEnabled(true)
        XCTAssertTrue(protectionReady)
        let webView = session.rootPage.webView
        webView.loadHTMLString("<html><body>Download test</body></html>", baseURL: app.url)
        for _ in 0..<100 {
            if webView.url != nil && !webView.isLoading { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        _ = try await webView.evaluateJavaScript("const a=document.createElement('a');a.href=URL.createObjectURL(new Blob(['Lite download fixture'],{type:'text/plain'}));a.download='fixture.txt';document.body.appendChild(a);a.click();")
        for _ in 0..<200 {
            if session.savedDownloadNotice { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(session.savedDownloadNotice)
        let completed = try XCTUnwrap(store.downloads(for: app.dataStoreIdentifier).first)
        XCTAssertEqual(completed.status, .completed)
        let fileURL = try store.fileURL(for: completed)
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "Lite download fixture")
        session.close()
        let restarted = SavedContentStore(rootURL: directory)
        let restored = try XCTUnwrap(restarted.downloads(for: app.dataStoreIdentifier).first)
        XCTAssertEqual(try String(contentsOf: restarted.fileURL(for: restored), encoding: .utf8), "Lite download fixture")
    }
}

// Exact V1 property names, types and attributes. SwiftData stores the model name,
// not this enclosing fixture namespace, allowing a real on-disk lightweight migration.
private enum V1Fixture {
    @Model final class LiteApp {
        @Attribute(.unique) var id: UUID
        var name: String
        var url: URL
        @Attribute(.externalStorage) var iconData: Data?
        var iconSymbol: String
        var iconColor: String
        @Attribute(.unique) var dataStoreIdentifier: UUID
        var isBiometricLocked: Bool
        var isBlockingEnabled: Bool
        var createdAt: Date
        init(id: UUID, profileID: UUID) {
            self.id = id; name = "Existing Account"; url = URL(string: "https://example.com")!
            iconData = Data([1, 2, 3]); iconSymbol = "globe"; iconColor = "blue"
            dataStoreIdentifier = profileID; isBiometricLocked = true; isBlockingEnabled = false
            createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        }
    }
    @Model final class PendingProfileDeletion {
        @Attribute(.unique) var identifier: UUID
        init(identifier: UUID) { self.identifier = identifier }
    }
}

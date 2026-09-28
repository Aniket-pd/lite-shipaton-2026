import Foundation
import SwiftData
import XCTest
@testable import lite

@MainActor
final class LiteAppPersistenceTests: XCTestCase {
    func testTwoAccountsForOneWebsiteHaveIndependentPersistentIdentities() throws {
        let url = try XCTUnwrap(URL(string: "https://www.instagram.com/"))
        let personal = LiteApp(name: "Instagram Personal", url: url)
        let work = LiteApp(name: "Instagram Work", url: url)

        XCTAssertNotEqual(personal.id, work.id)
        XCTAssertNotEqual(personal.dataStoreIdentifier, work.dataStoreIdentifier)
        XCTAssertNotEqual(personal.id, personal.dataStoreIdentifier)
        XCTAssertEqual(personal.url, work.url)
        XCTAssertFalse(personal.isBiometricLocked)
        XCTAssertTrue(personal.isBlockingEnabled)
    }

    func testSavingAndReopeningRetainsProfileAndSecuritySettings() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LitePersistenceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Lite.store")
        let url = try XCTUnwrap(URL(string: "https://www.reddit.com/"))
        let original = LiteApp(
            name: "Reddit Work",
            url: url,
            iconData: Data([1, 2, 3]),
            iconSymbol: "bubble.left.and.bubble.right.fill",
            iconColor: "orange",
            isBiometricLocked: true
        )
        original.isBlockingEnabled = false
        original.launchPagePreference = .continueLast
        original.lastPageURL = URL(string: "https://www.reddit.com/r/swift")
        original.isFavorite = true
        original.sortOrder = 4
        original.isVisibleInWidget = true
        original.websiteLayout = .desktop
        original.pageZoom = 1.35
        original.cameraPermission = .block
        original.microphonePermission = .block
        original.requiresMediaGesture = false
        original.allowsJavaScript = false
        original.allowsPopups = false
        original.automaticWindowOrigins = ["https://www.reddit.com:443"]
        original.lastOpenedAt = Date(timeIntervalSince1970: 1_700_000_123)
        original.lastConnectionHost = "www.reddit.com"
        original.lastConnectionSecure = true
        original.lastHTTPStatus = 200
        original.lastErrorDomain = NSURLErrorDomain
        original.lastErrorCode = NSURLErrorCannotFindHost
        let id = original.id
        let profile = original.dataStoreIdentifier
        let createdAt = original.createdAt

        do {
            let container = try makeContainer(at: storeURL)
            let context = ModelContext(container)
            context.insert(original)
            try context.save()
        }

        let reopened = try makeContainer(at: storeURL)
        let context = ModelContext(reopened)
        let saved = try XCTUnwrap(context.fetch(FetchDescriptor<LiteApp>()).first)
        XCTAssertEqual(saved.id, id)
        XCTAssertEqual(saved.dataStoreIdentifier, profile)
        XCTAssertEqual(saved.name, "Reddit Work")
        XCTAssertEqual(saved.url, url)
        XCTAssertEqual(saved.iconData, Data([1, 2, 3]))
        XCTAssertEqual(saved.iconSymbol, "bubble.left.and.bubble.right.fill")
        XCTAssertEqual(saved.iconColor, "orange")
        XCTAssertEqual(saved.createdAt.timeIntervalSince1970, createdAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertTrue(saved.isBiometricLocked)
        XCTAssertFalse(saved.isBlockingEnabled)
        XCTAssertEqual(saved.launchPagePreference, .continueLast)
        XCTAssertEqual(saved.lastPageURL, URL(string: "https://www.reddit.com/r/swift"))
        XCTAssertTrue(saved.isFavorite)
        XCTAssertEqual(saved.sortOrder, 4)
        XCTAssertTrue(saved.isVisibleInWidget)
        XCTAssertEqual(saved.websiteLayout, .desktop)
        XCTAssertEqual(saved.effectivePageZoom, 1.35)
        XCTAssertEqual(saved.cameraPermission, .block)
        XCTAssertEqual(saved.microphonePermission, .block)
        XCTAssertFalse(saved.requiresMediaGesture)
        XCTAssertFalse(saved.allowsJavaScript)
        XCTAssertFalse(saved.allowsPopups)
        XCTAssertEqual(saved.automaticWindowOrigins, ["https://www.reddit.com:443"])
        XCTAssertEqual(saved.lastOpenedAt, Date(timeIntervalSince1970: 1_700_000_123))
        XCTAssertEqual(saved.lastConnectionHost, "www.reddit.com")
        XCTAssertEqual(saved.lastConnectionSecure, true)
        XCTAssertEqual(saved.lastHTTPStatus, 200)
        XCTAssertEqual(saved.lastErrorDomain, NSURLErrorDomain)
        XCTAssertEqual(saved.lastErrorCode, NSURLErrorCannotFindHost)
    }

    private func makeContainer(at url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: LiteApp.self, configurations: configuration)
    }
}

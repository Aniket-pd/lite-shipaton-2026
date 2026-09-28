import Foundation
import SQLite3
import SwiftData
import XCTest
@testable import lite

@MainActor
final class LiteAppCollectionTests: XCTestCase {
    func testAddingCollectionsMigratesAnExistingAppStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiteCollectionMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Lite.store")
        let originalID = UUID()
        let pendingDeletionID = UUID()

        do {
            let oldSchema = Schema([CollectionV1Fixture.LiteApp.self, CollectionV1Fixture.PendingProfileDeletion.self])
            let configuration = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            let oldContainer = try ModelContainer(for: oldSchema, configurations: configuration)
            let app = CollectionV1Fixture.LiteApp(id: originalID)
            oldContainer.mainContext.insert(app)
            oldContainer.mainContext.insert(CollectionV1Fixture.PendingProfileDeletion(identifier: pendingDeletionID))
            try oldContainer.mainContext.save()
        }

        let migrated = try makeContainer(at: storeURL)
        let apps = try migrated.mainContext.fetch(FetchDescriptor<LiteApp>())
        let pendingDeletions = try migrated.mainContext.fetch(FetchDescriptor<PendingProfileDeletion>())
        XCTAssertEqual(apps.map(\.id), [originalID])
        XCTAssertEqual(pendingDeletions.map(\.identifier), [pendingDeletionID])
        XCTAssertTrue(try migrated.mainContext.fetch(FetchDescriptor<LiteAppCollection>()).isEmpty)
    }

    func testInterruptedCollectionMigrationIsRepairedWithoutLosingApps() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiteInterruptedMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Lite.store")
        let originalID = UUID()

        do {
            let oldSchema = Schema([CollectionV1Fixture.LiteApp.self, CollectionV1Fixture.PendingProfileDeletion.self])
            let oldContainer = try ModelContainer(
                for: oldSchema,
                configurations: ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            )
            oldContainer.mainContext.insert(CollectionV1Fixture.LiteApp(id: originalID))
            try oldContainer.mainContext.save()
        }

        try executeSQL(
            "ALTER TABLE ZLITEAPP ADD COLUMN Z2APPS INTEGER; " +
            "CREATE INDEX ZLITEAPP_Z2APPS_INDEX ON ZLITEAPP (Z2APPS);",
            at: storeURL
        )

        let backup = try XCTUnwrap(
            SwiftDataStoreRecovery.repairInterruptedCollectionMigration(at: storeURL)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.appendingPathComponent("Lite.store").path))

        let migrated = try makeContainer(at: storeURL)
        let apps = try migrated.mainContext.fetch(FetchDescriptor<LiteApp>())
        XCTAssertEqual(apps.map(\.id), [originalID])
        XCTAssertTrue(try migrated.mainContext.fetch(FetchDescriptor<LiteAppCollection>()).isEmpty)
    }

    func testCollectionPersistsMembershipWithoutChangingAppIdentity() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiteCollectionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Lite.store")

        let first = LiteApp(name: "Mail", url: try XCTUnwrap(URL(string: "https://mail.example.com")))
        let second = LiteApp(name: "Calendar", url: try XCTUnwrap(URL(string: "https://calendar.example.com")))
        let firstProfileID = first.dataStoreIdentifier
        let secondProfileID = second.dataStoreIdentifier

        do {
            let container = try makeContainer(at: storeURL)
            container.mainContext.insert(first)
            container.mainContext.insert(second)
            container.mainContext.insert(LiteAppCollection(name: "Work", apps: [first, second]))
            try container.mainContext.save()
        }

        let reopened = try makeContainer(at: storeURL)
        let collections = try reopened.mainContext.fetch(FetchDescriptor<LiteAppCollection>())
        let savedApps = try reopened.mainContext.fetch(FetchDescriptor<LiteApp>())

        let collection = try XCTUnwrap(collections.first)
        XCTAssertEqual(collection.name, "Work")
        XCTAssertEqual(Set(collection.apps.map(\.name)), ["Mail", "Calendar"])
        XCTAssertEqual(Set(savedApps.map(\.dataStoreIdentifier)), [firstProfileID, secondProfileID])
    }

    func testDeletingCollectionKeepsItsApps() throws {
        let container = try ModelContainer(
            for: LiteApp.self,
            LiteAppCollection.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let first = LiteApp(name: "News", url: try XCTUnwrap(URL(string: "https://news.example.com")))
        let second = LiteApp(name: "Social", url: try XCTUnwrap(URL(string: "https://social.example.com")))
        let collection = LiteAppCollection(name: "Morning", apps: [first, second])
        container.mainContext.insert(first)
        container.mainContext.insert(second)
        container.mainContext.insert(collection)
        try container.mainContext.save()

        container.mainContext.delete(collection)
        try container.mainContext.save()

        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<LiteAppCollection>()).isEmpty)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<LiteApp>()), 2)
    }

    private func makeContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema([LiteApp.self, LiteAppCollection.self, PendingProfileDeletion.self])
        let configuration = ModelConfiguration(url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private func executeSQL(_ sql: String, at url: URL) throws {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
        defer { sqlite3_close(database) }
        guard let database else { return XCTFail("Could not open SQLite fixture") }
        sqlite3_busy_timeout(database, 5_000)
        let result = sqlite3_exec(database, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            return XCTFail(String(cString: sqlite3_errmsg(database)))
        }
    }
}

// Exact schema used by the first shipped build. Using the current LiteApp model
// here would only test adding a table, not a real user's multi-version upgrade.
private enum CollectionV1Fixture {
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

        init(id: UUID) {
            self.id = id
            name = "Existing"
            url = URL(string: "https://example.com")!
            iconSymbol = "globe"
            iconColor = "blue"
            dataStoreIdentifier = UUID()
            isBiometricLocked = false
            isBlockingEnabled = true
            createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        }
    }

    @Model final class PendingProfileDeletion {
        @Attribute(.unique) var identifier: UUID
        init(identifier: UUID) { self.identifier = identifier }
    }
}

import SwiftData
import XCTest
@testable import lite

@MainActor
final class StarterLibraryTests: XCTestCase {
    func testStarterAppsPersistWithSeparateProtectedProfilesAndDoNotDuplicate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        XCTAssertEqual(try StarterLibrary.installIfEmpty(in: context), 6)
        let apps = try ModelContext(container).fetch(FetchDescriptor<LiteApp>(sortBy: [SortDescriptor(\.sortOrder)]))
        XCTAssertEqual(apps.map(\.name), ["Instagram", "Reddit", "X", "LinkedIn", "Gmail", "YouTube"])
        XCTAssertEqual(Set(apps.map(\.dataStoreIdentifier)).count, 6)
        XCTAssertTrue(apps.allSatisfy { $0.isBlockingEnabled && $0.isStarterApp && $0.iconData != nil })
        XCTAssertEqual(try StarterLibrary.installIfEmpty(in: context), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LiteApp>()), 6)
    }

    func testExistingLibraryIsNotChanged() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let existing = LiteApp(name: "My site", url: URL(string: "https://example.com")!)
        context.insert(existing)
        try context.save()
        XCTAssertEqual(try StarterLibrary.installIfEmpty(in: context), 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<LiteApp>()).map(\.id), [existing.id])
    }

    func testStartersLeaveThreeFreeSlotsAndDuplicatesConsumeASlot() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try StarterLibrary.installIfEmpty(in: context)
        let starter = try XCTUnwrap(context.fetch(FetchDescriptor<LiteApp>()).first)
        let pro = ProStore(enabled: false)
        for _ in 0..<3 {
            XCTAssertNoThrow(try pro.requireAppSlot(in: context))
            let duplicate = starter.duplicate()
            XCTAssertFalse(duplicate.isStarterApp)
            context.insert(duplicate)
            try context.save()
        }
        XCTAssertThrowsError(try pro.requireAppSlot(in: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LiteApp>()), 9)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: LiteApp.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}

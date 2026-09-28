import SwiftData
import XCTest
@testable import lite

@MainActor
final class ProAccessTests: XCTestCase {
    func testFreeLimitsCountProfilesAndPreserveAnOverLimitLibrary() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pro = ProStore(enabled: false)
        for index in 0..<3 {
            XCTAssertNoThrow(try pro.requireAppSlot(in: context))
            context.insert(LiteApp(name: "Account \(index)", url: URL(string: "https://example.com")!))
            try context.save()
        }
        XCTAssertThrowsError(try pro.requireAppSlot(in: context)) { XCTAssertEqual($0 as? ProFeature, .apps) }
        let apps = try context.fetch(FetchDescriptor<LiteApp>())
        XCTAssertEqual(apps.count, 3)
        apps[0].name = "Still editable"
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LiteApp>()), 3)
    }

    func testSecondGroupRequiresProWithoutChangingExistingGroup() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pro = ProStore(enabled: false)
        XCTAssertNoThrow(try pro.requireGroupSlot(in: context))
        let group = LiteAppCollection(name: "Work", apps: [], sortOrder: 0)
        context.insert(group)
        try context.save()
        XCTAssertThrowsError(try pro.requireGroupSlot(in: context)) { XCTAssertEqual($0 as? ProFeature, .groups) }
        group.name = "Renamed"
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<LiteAppCollection>()).first?.name, "Renamed")
    }

    func testSubscriptionExpiresEvenWithoutANetworkRefresh() {
        let now = Date(timeIntervalSince1970: 1000)
        let active = ProAccess(isActive: true, expiresAt: now.addingTimeInterval(60))
        XCTAssertTrue(active.canCreateApp(count: 100, at: now))
        XCTAssertTrue(active.canCreateGroup(count: 100, at: now))
        XCTAssertFalse(active.isUnlocked(at: now.addingTimeInterval(60)))
        XCTAssertFalse(active.canCreateApp(count: 3, at: now.addingTimeInterval(61)))
    }

    func testCancellationKeepsAccessUntilExpiryAndLifetimeDoesNotExpire() {
        let now = Date.now
        XCTAssertTrue(ProAccess(isActive: true, expiresAt: now.addingTimeInterval(60), willRenew: false).isUnlocked(at: now))
        XCTAssertTrue(ProAccess(isActive: true, productID: ProCatalog.lifetime).isUnlocked(at: .distantFuture))
        XCTAssertFalse(ProAccess(isActive: false, productID: ProCatalog.lifetime).isUnlocked())
    }

    func testExistingPremiumAppearanceSurvivesExpiry() throws {
        let pro = ProStore(enabled: false)
        let existing = LiteApp(name: "Saved", url: URL(string: "https://example.com")!, iconSymbol: "camera", iconColor: "purple")
        XCTAssertNoThrow(try pro.requireAppearance(symbol: "camera", color: "purple", existing: existing))
        XCTAssertNoThrow(try pro.requireAppearance(symbol: "globe", color: "blue", existing: existing))
        XCTAssertThrowsError(try pro.requireAppearance(symbol: "airplane", color: "purple", existing: existing))
        XCTAssertThrowsError(try pro.requireAppearance(symbol: "globe", color: "red"))
    }

    func testCreationCannotBypassLimit() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        for index in 0..<3 { context.insert(LiteApp(name: "\(index)", url: URL(string: "https://example.com")!)) }
        try context.save()
        let model = CreateAppViewModel()
        model.configure(url: URL(string: "https://another.example")!, service: nil)
        let created = await model.create(in: context, pro: ProStore(enabled: false))
        XCTAssertFalse(created)
        XCTAssertEqual(model.proFeature, .apps)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LiteApp>()), 3)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([LiteApp.self, LiteAppCollection.self, PendingProfileDeletion.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    }
}

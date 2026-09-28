import Foundation
import XCTest
@testable import lite

@MainActor
final class LiteAppGroupingTests: XCTestCase {
    func testSameNormalizedWebsiteBecomesOneVisualGroup() throws {
        let aniket = LiteApp(
            name: "Product Hunt Aniket",
            url: try XCTUnwrap(URL(string: "https://www.producthunt.com/posts/one"))
        )
        let vaibhav = LiteApp(
            name: "Product Hunt Vaibhav",
            url: try XCTUnwrap(URL(string: "https://producthunt.com/topics/ios"))
        )
        let sector = LiteApp(
            name: "Product Hunt Sector",
            url: try XCTUnwrap(URL(string: "https://producthunt.com/"))
        )

        let groups = LiteAppGrouping.groups(from: [aniket, vaibhav, sector])

        let group = try XCTUnwrap(groups.first)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(group.websiteName, "Product Hunt")
        XCTAssertEqual(group.apps.map(group.profileName(for:)), ["Aniket", "Vaibhav", "Sector"])
    }

    func testCatalogAliasesGroupMobileAndDesktopYouTube() throws {
        let mobile = LiteApp(name: "YouTube Personal", url: try XCTUnwrap(URL(string: "https://m.youtube.com")))
        let desktop = LiteApp(name: "YouTube Work", url: try XCTUnwrap(URL(string: "https://www.youtube.com/feed")))

        let group = try XCTUnwrap(LiteAppGrouping.groups(from: [mobile, desktop]).first)

        XCTAssertEqual(group.apps.count, 2)
        XCTAssertEqual(group.websiteName, "YouTube")
        XCTAssertEqual(group.id, "catalog:youtube")
    }

    func testLastUsedProfileWinsWithoutChangingProfileIdentity() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let personal = LiteApp(name: "Example Personal", url: url)
        let work = LiteApp(name: "Example Work", url: url)
        personal.lastOpenedAt = Date(timeIntervalSince1970: 100)
        work.lastOpenedAt = Date(timeIntervalSince1970: 200)
        let personalStore = personal.dataStoreIdentifier
        let workStore = work.dataStoreIdentifier

        let group = try XCTUnwrap(LiteAppGrouping.groups(from: [personal, work]).first)

        XCTAssertEqual(group.lastUsedApp.id, work.id)
        XCTAssertEqual(personal.dataStoreIdentifier, personalStore)
        XCTAssertEqual(work.dataStoreIdentifier, workStore)
        XCTAssertNotEqual(personalStore, workStore)
    }

    func testProfileOnlyNamesRemainProfileOnly() throws {
        let app = LiteApp(
            name: "Aniket",
            url: try XCTUnwrap(URL(string: "https://producthunt.com"))
        )
        let group = try XCTUnwrap(LiteAppGrouping.groups(from: [app]).first)

        XCTAssertEqual(app.name, "Aniket")
        XCTAssertEqual(group.profileName(for: app), "Aniket")
    }

    func testDuplicatedProfileKeepsSettingsButGetsFreshStorage() throws {
        let original = LiteApp(
            name: "Example Personal",
            url: try XCTUnwrap(URL(string: "https://example.com")),
            isBiometricLocked: true
        )
        let copy = original.duplicate(accountName: "Example Work")

        XCTAssertEqual(copy.url, original.url)
        XCTAssertEqual(copy.isBiometricLocked, original.isBiometricLocked)
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertNotEqual(copy.dataStoreIdentifier, original.dataStoreIdentifier)
    }
}

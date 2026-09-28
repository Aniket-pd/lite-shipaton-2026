import XCTest
import WebKit
import UIKit
@testable import lite

@MainActor
final class DiscoverTests: XCTestCase {
    func testEveryCatalogEntryHasVisibleIconArtworkOrSymbol() {
        XCTAssertEqual(DiscoverCatalog.entries.count, 21)
        XCTAssertEqual(Set(DiscoverCatalog.entries.map(\.id)).count, DiscoverCatalog.entries.count)

        for entry in DiscoverCatalog.entries {
            if let data = CatalogIcon.data(for: entry.url) {
                XCTAssertTrue(FaviconService.isVisuallyUsableIconData(data), entry.service.name)
            } else {
                XCTAssertNotNil(UIImage(systemName: entry.service.symbol), entry.service.name)
            }
        }
    }

    func testSearchHandlesNamesTasksCategoriesAndWhitespace() {
        XCTAssertEqual(DiscoverCatalog.search("  notion \n").first?.id, "notion")
        XCTAssertEqual(Set(DiscoverCatalog.search("photo editor").map(\.id)), ["canva", "photopea"])
        XCTAssertTrue(DiscoverCatalog.search("notion", category: .social).isEmpty)
        XCTAssertTrue(DiscoverCatalog.search("", category: .ai).allSatisfy { $0.category == .ai })
        XCTAssertTrue(DiscoverCatalog.search("an app outside our catalog").isEmpty)
    }

    func testAppNamesAreNotMistakenForURLsAndUnsafeAddressesNeverBecomeSearches() {
        for query in ["Notion", "photo editor", "new tool", ""] {
            XCTAssertFalse(DiscoverCatalog.looksLikeAddress(query), query)
        }
        for query in ["example.com", "https://example.com/team", "http://example.com", "javascript:alert(1)", "https://user:secret@example.com"] {
            XCTAssertTrue(DiscoverCatalog.looksLikeAddress(query), query)
        }
        XCTAssertThrowsError(try WebsiteURL.normalized("https://user:secret@example.com"))
    }

    func testSavedServiceMatchingDoesNotConfuseUnrelatedHostsOrPorts() throws {
        let instagram = try XCTUnwrap(DiscoverCatalog.entries.first { $0.id == "instagram" })
        XCTAssertTrue(DiscoverCatalog.matches(instagram, url: URL(string: "https://instagram.com/me")!))
        for value in ["https://instagram.com.evil.com", "https://evilinstagram.com", "https://instagram.com:8443", "http://instagram.com", "https://user:pass@instagram.com"] {
            XCTAssertFalse(DiscoverCatalog.matches(instagram, url: URL(string: value)!), value)
        }
        let youtube = try XCTUnwrap(DiscoverCatalog.entries.first { $0.id == "youtube" })
        XCTAssertTrue(DiscoverCatalog.matches(youtube, url: URL(string: "https://www.youtube.com/")!))
    }

    func testSearchQueryEncodingAndSearchResultExclusion() throws {
        let query = "notes & tasks + 日本語"
        let url = DiscoverCatalog.searchURL(query)
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, query)
        XCTAssertNil(DiscoverWebSession.service(for: url, title: "Search"))
        XCTAssertNil(DiscoverWebSession.service(for: URL(string: "https://duckduckgo.com/?q=mail")!, title: "Search"))
        XCTAssertFalse(DiscoverCatalog.isSearchPage(URL(string: "https://duckduckgo.com.evil.com")!))
    }

    func testWebSelectionUsesStartingPointWithoutTokensAndKeepsKnownAppIdentity() throws {
        let selected = try XCTUnwrap(DiscoverWebSession.service(for: URL(string: "https://example.com/auth/callback?token=private#secret")!, title: "Example"))
        XCTAssertEqual(selected.address, "https://example.com/")
        XCTAssertEqual(selected.name, "Example")
        let gmail = try XCTUnwrap(DiscoverWebSession.service(for: URL(string: "https://mail.google.com/mail/u/0/#inbox")!, title: "Private inbox"))
        XCTAssertEqual(gmail.name, "Gmail")
        XCTAssertEqual(gmail.address, "https://mail.google.com")
        XCTAssertNil(DiscoverWebSession.service(for: URL(string: "http://example.com")!, title: nil))
        XCTAssertNil(DiscoverWebSession.service(for: URL(string: "https://user:password@example.com")!, title: nil))
    }

    func testPreviewUsesTemporaryIsolatedStores() {
        let first = DiscoverWebSession(url: URL(string: "https://example.com")!)
        let second = DiscoverWebSession(url: URL(string: "https://example.com")!)
        XCTAssertFalse(first.page.webView.configuration.websiteDataStore.isPersistent)
        XCTAssertFalse(second.page.webView.configuration.websiteDataStore.isPersistent)
        XCTAssertFalse(first.page.webView.configuration.websiteDataStore === second.page.webView.configuration.websiteDataStore)
        XCTAssertNil(first.selection)
        first.close()
        second.close()
    }
}

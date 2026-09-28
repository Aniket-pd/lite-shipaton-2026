import Foundation
import SwiftData
import WebKit
import XCTest
@testable import lite

/// Uses real persistent WebKit profiles, never mocks or a shared default store.
@MainActor
final class WebKitIsolationTests: XCTestCase {
    func testIndependentCookiesSurviveReopeningAndDeletingOneProfile() async throws {
        let url = try XCTUnwrap(URL(string: "https://accounts.example.com/"))
        let personal = LiteApp(name: "Personal", url: url)
        let work = LiteApp(name: "Work", url: url)
        let personalCookie = try cookie(value: "personal")
        let workCookie = try cookie(value: "work")
        let personalIdentifier = personal.dataStoreIdentifier
        let workIdentifier = work.dataStoreIdentifier
        let container = try ModelContainer(
            for: LiteApp.self, PendingProfileDeletion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.insert(personal)
        context.insert(work)
        try context.save()

        let personalCredential = UUID(), workCredential = UUID()
        let savedStore = SavedContentStore.shared
        try savedStore.addBookmark(profileID: personalIdentifier, title: "Personal page", url: url.appendingPathComponent("personal"))
        try savedStore.addBookmark(profileID: workIdentifier, title: "Work page", url: url.appendingPathComponent("work"))
        try ProxyCredentialStore.save("personal-proxy-password", profile: personalIdentifier, credential: personalCredential)
        try ProxyCredentialStore.save("work-proxy-password", profile: workIdentifier, credential: workCredential)
        defer {
            try? ProxyCredentialStore.remove(profile: personalIdentifier)
            try? ProxyCredentialStore.remove(profile: workIdentifier)
            try? savedStore.removeProfile(personalIdentifier)
            try? savedStore.removeProfile(workIdentifier)
        }

        await populateProfiles(personal, work, personalCookie, workCookie)
        await assertReopenedProfile(personal, hasCookieValue: "personal")
        await assertReopenedProfile(work, hasCookieValue: "work")

        // No WKWebView may retain a profile when WebKit removes its on-disk store.
        try ProfileDeletionService.delete(personal, in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<LiteApp>()).map(\.dataStoreIdentifier), [workIdentifier])
        XCTAssertEqual(try context.fetch(FetchDescriptor<PendingProfileDeletion>()).map(\.identifier), [personalIdentifier])
        do {
            try await finishPendingDeletionsAfterWebKitRelease(in: context)
        } catch {
            let details = error as NSError
            XCTFail("Profile removal failed: \(details.domain) code \(details.code), \(details.userInfo)")
            throw error
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<PendingProfileDeletion>()).isEmpty)
        XCTAssertNil(try ProxyCredentialStore.password(profile: personalIdentifier, credential: personalCredential))
        XCTAssertEqual(try ProxyCredentialStore.password(profile: workIdentifier, credential: workCredential), "work-proxy-password")
        XCTAssertTrue(savedStore.bookmarks(for: personalIdentifier).isEmpty)
        XCTAssertEqual(savedStore.bookmarks(for: workIdentifier).first?.title, "Work page")
        await assertReopenedProfile(work, hasCookieValue: "work")
        let remainingIdentifiers = await WKWebsiteDataStore.allDataStoreIdentifiers
        XCTAssertFalse(remainingIdentifiers.contains(personalIdentifier))
        XCTAssertTrue(remainingIdentifiers.contains(workIdentifier))
        try ProfileDeletionService.delete(work, in: context)
        try await finishPendingDeletionsAfterWebKitRelease(in: context)
    }

    private func finishPendingDeletionsAfterWebKitRelease(in context: ModelContext) async throws {
        // WebKit releases a closed view’s networking session asynchronously. A
        // busy removal must keep its durable receipt; the next drain retries it.
        // This is also reproducible on the unchanged V2 app with Xcode 26.3.
        for attempt in 0..<20 {
            do {
                try await ProfileDeletionService.finishPendingDeletions(in: context)
                return
            } catch {
                let error = error as NSError
                guard error.domain == "WKWebSiteDataStore", error.code == 1, attempt < 19 else { throw error }
                XCTAssertFalse(try context.fetch(FetchDescriptor<PendingProfileDeletion>()).isEmpty)
                try await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func populateProfiles(
        _ personal: LiteApp,
        _ work: LiteApp,
        _ personalCookie: HTTPCookie,
        _ workCookie: HTTPCookie
    ) async {
        let personalSession = WebSession(app: personal)
        let workSession = WebSession(app: work)
        defer { personalSession.close(); workSession.close() }
        let personalStore = personalSession.rootPage.webView.configuration.websiteDataStore
        let workStore = workSession.rootPage.webView.configuration.websiteDataStore
        XCTAssertTrue(personalStore.isPersistent)
        XCTAssertTrue(workStore.isPersistent)
        XCTAssertEqual(personalStore.identifier, personal.dataStoreIdentifier)
        XCTAssertEqual(workStore.identifier, work.dataStoreIdentifier)
        XCTAssertNotEqual(personalStore.identifier, workStore.identifier)

        await personalStore.httpCookieStore.setCookie(personalCookie)
        let cleanWorkCookies = await workStore.httpCookieStore.allCookies()
        XCTAssertFalse(cleanWorkCookies.contains { $0.name == "lite_test_session" })
        await workStore.httpCookieStore.setCookie(workCookie)
        let personalCookies = await personalStore.httpCookieStore.allCookies()
        let workCookies = await workStore.httpCookieStore.allCookies()
        XCTAssertEqual(personalCookies.first { $0.name == "lite_test_session" }?.value, "personal")
        XCTAssertEqual(workCookies.first { $0.name == "lite_test_session" }?.value, "work")
    }

    private func assertReopenedProfile(
        _ app: LiteApp,
        hasCookieValue value: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let bookmarkURL = app.url.appendingPathComponent("saved-page")
        let reopened = WebSession(app: app, initialURL: bookmarkURL)
        defer { reopened.close() }
        XCTAssertEqual(reopened.startURL, bookmarkURL, file: file, line: line)
        XCTAssertEqual(reopened.dataStore.identifier, app.dataStoreIdentifier, file: file, line: line)
        let cookies = await reopened.rootPage.webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        XCTAssertEqual(cookies.first { $0.name == "lite_test_session" }?.value, value, file: file, line: line)
    }

    private func cookie(value: String) throws -> HTTPCookie {
        try XCTUnwrap(HTTPCookie(properties: [
            .domain: "accounts.example.com",
            .path: "/",
            .name: "lite_test_session",
            .value: value,
            .secure: "TRUE",
            .expires: Date(timeIntervalSinceNow: 3_600)
        ]))
    }
}

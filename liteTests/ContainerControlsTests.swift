import Foundation
import SwiftData
import WebKit
import XCTest
@testable import lite

@MainActor
final class ContainerControlsTests: XCTestCase {
    func testPreferencesConfigureRealWebViewAndKeepProfileIdentity() async throws {
        let app = LiteApp(name: "Controls", url: URL(string: "https://example.com")!)
        app.websiteLayout = .desktop
        app.pageZoom = 1.4
        app.requiresMediaGesture = false
        app.allowsJavaScript = false
        app.cameraPermission = .block
        app.microphonePermission = .ask
        let session = WebSession(app: app)
        let webView = session.rootPage.webView
        let config = webView.configuration
        XCTAssertEqual(config.websiteDataStore.identifier, app.dataStoreIdentifier)
        XCTAssertEqual(config.defaultWebpagePreferences.preferredContentMode, .desktop)
        XCTAssertFalse(config.defaultWebpagePreferences.allowsContentJavaScript)
        XCTAssertEqual(config.mediaTypesRequiringUserActionForPlayback, [])
        XCTAssertEqual(webView.pageZoom, 1.4, accuracy: 0.001)
        XCTAssertEqual(session.preferences.mediaDecision(for: .camera), .deny)
        XCTAssertEqual(session.preferences.mediaDecision(for: .microphone), .prompt)
        XCTAssertEqual(session.preferences.mediaDecision(for: .cameraAndMicrophone), .deny)
        try await load("<html><body><script>window.websiteScriptRan = true</script>Settings</body></html>", in: webView, baseURL: app.url)
        let scriptValue = try await webView.evaluateJavaScript("window.websiteScriptRan ?? null")
        XCTAssertTrue(scriptValue is NSNull, "Disabling JavaScript must stop website scripts, not just update a label")
        session.close()
        await ContainerWebsiteData.remove(.all, from: app.dataStoreIdentifier)
    }

    func testCacheClearingPreservesCookiesAndAllDataClearingIsIsolated() async throws {
        let url = URL(string: "https://example.com")!
        let personal = LiteApp(name: "Personal", url: url)
        let work = LiteApp(name: "Work", url: url)
        let personalStore = WebProfileStore.store(for: personal.dataStoreIdentifier)
        let workStore = WebProfileStore.store(for: work.dataStoreIdentifier)
        let personalCookie = try makeCookie(value: "personal")
        let workCookie = try makeCookie(value: "work")
        await personalStore.httpCookieStore.setCookie(personalCookie)
        await workStore.httpCookieStore.setCookie(workCookie)

        let before = await ContainerWebsiteData.records(for: personal.dataStoreIdentifier)
        XCTAssertTrue(before.contains { $0.dataTypes.contains(WKWebsiteDataTypeCookies) })
        await ContainerWebsiteData.remove(.cache, from: personal.dataStoreIdentifier)
        let afterCache = await personalStore.httpCookieStore.allCookies()
        XCTAssertEqual(afterCache.first { $0.name == "container_test" }?.value, "personal")

        await ContainerWebsiteData.remove(.all, from: personal.dataStoreIdentifier)
        let afterAll = await personalStore.httpCookieStore.allCookies()
        let remainingWork = await workStore.httpCookieStore.allCookies()
        XCTAssertFalse(afterAll.contains { $0.name == "container_test" })
        XCTAssertEqual(remainingWork.first { $0.name == "container_test" }?.value, "work")
        XCTAssertEqual(WebProfileStore.store(for: personal.dataStoreIdentifier).identifier, personal.dataStoreIdentifier)
        await ContainerWebsiteData.remove(.all, from: work.dataStoreIdentifier)
    }

    func testCacheRemovalClearsRealFetchCacheButPreservesLocalStorage() async throws {
        let app = LiteApp(name: "Storage", url: URL(string: "https://example.com")!)
        let session = WebSession(app: app)
        try await load("<html><body>Storage test</body></html>", in: session.rootPage.webView, baseURL: app.url)
        _ = try await session.rootPage.webView.callAsyncJavaScript(
            """
            localStorage.setItem('retained', 'value');
            const cache = await caches.open('container-cache-test');
            await cache.put('https://example.com/asset', new Response('cached data'));
            return true;
            """, arguments: [:], in: nil, contentWorld: .page)
        session.close()
        let before = await ContainerWebsiteData.records(for: app.dataStoreIdentifier)
        XCTAssertTrue(before.contains { $0.dataTypes.contains(WKWebsiteDataTypeFetchCache) })
        XCTAssertTrue(before.contains { $0.dataTypes.contains(WKWebsiteDataTypeLocalStorage) })
        await ContainerWebsiteData.remove(.cache, from: app.dataStoreIdentifier)
        let afterCache = await ContainerWebsiteData.records(for: app.dataStoreIdentifier)
        XCTAssertFalse(afterCache.contains { !$0.dataTypes.isDisjoint(with: ContainerWebsiteData.cacheTypes) })
        XCTAssertTrue(afterCache.contains { $0.dataTypes.contains(WKWebsiteDataTypeLocalStorage) })
        await ContainerWebsiteData.remove(.all, from: app.dataStoreIdentifier)
        let afterAll = await ContainerWebsiteData.records(for: app.dataStoreIdentifier)
        XCTAssertFalse(afterAll.contains { $0.dataTypes.contains(WKWebsiteDataTypeLocalStorage) })
    }

    func testRemovingOneRecordPreservesOtherDomainsAndOtherProfiles() async throws {
        let app = LiteApp(name: "Multiple domains", url: URL(string: "https://example.com")!)
        let store = WebProfileStore.store(for: app.dataStoreIdentifier)
        await store.httpCookieStore.setCookie(try makeCookie(value: "first"))
        await store.httpCookieStore.setCookie(try makeCookie(value: "second", domain: "example.org"))
        let records = await ContainerWebsiteData.records(for: app.dataStoreIdentifier)
        let selected = try XCTUnwrap(records.first { $0.displayName == "example.com" })
        await ContainerWebsiteData.remove(.record(selected), from: app.dataStoreIdentifier)
        let cookies = await store.httpCookieStore.allCookies()
        XCTAssertFalse(cookies.contains { $0.domain == "example.com" })
        XCTAssertEqual(cookies.first { $0.domain == "example.org" }?.value, "second")
        await ContainerWebsiteData.remove(.all, from: app.dataStoreIdentifier)
    }

    func testResetKeepsIdentityLockResumeAndWebsiteCookies() async throws {
        let app = LiteApp(name: "Private", url: URL(string: "https://example.com")!, isBiometricLocked: true)
        let identifier = app.dataStoreIdentifier
        app.websiteLayout = .desktop
        app.pageZoom = 1.5
        app.isBlockingEnabled = false
        app.cameraPermission = .block
        app.microphonePermission = .block
        app.requiresMediaGesture = false
        app.allowsJavaScript = false
        app.allowsPopups = false
        app.automaticWindowOrigins = ["https://example.com:443"]
        app.lastPageURL = URL(string: "https://example.com/feed")
        let store = WebProfileStore.store(for: identifier)
        await store.httpCookieStore.setCookie(try makeCookie(value: "retained"))
        app.resetContainerPreferences()
        XCTAssertEqual(app.dataStoreIdentifier, identifier)
        XCTAssertTrue(app.isBiometricLocked)
        XCTAssertEqual(app.name, "Private")
        XCTAssertNotNil(app.lastPageURL)
        XCTAssertEqual(app.websiteLayout, .mobile)
        XCTAssertEqual(app.pageZoom, 1)
        XCTAssertTrue(app.requiresMediaGesture)
        XCTAssertTrue(app.allowsJavaScript)
        XCTAssertTrue(app.allowsPopups)
        XCTAssertTrue(app.automaticWindowOrigins.isEmpty)
        XCTAssertTrue(app.isBlockingEnabled)
        XCTAssertEqual(app.cameraPermission, .ask)
        XCTAssertEqual(app.microphonePermission, .ask)
        let cookies = await store.httpCookieStore.allCookies()
        XCTAssertEqual(cookies.first { $0.name == "container_test" }?.value, "retained")
        await ContainerWebsiteData.remove(.all, from: identifier)
    }

    func testDiagnosticsUseObservedEventsAndNeverRetainSensitiveURLComponents() async throws {
        let app = LiteApp(name: "Diagnostics", url: URL(string: "https://example.com")!)
        let session = WebSession(app: app)
        defer { session.close() }
        XCTAssertNil(app.lastConnectionAt)
        XCTAssertFalse(app.isProxyEnabled)
        XCTAssertEqual(app.proxyHost, "")
        XCTAssertEqual(app.proxyPort, 443)
        XCTAssertNil(app.proxyCredentialID)
        XCTAssertNil(app.lastConnectionSecure)
        XCTAssertNil(app.lastOpenedAt)
        let failingURL = URL(string: "https://auth.example.com/login?token=secret#private")!
        session.webView(session.rootPage.webView, didFailProvisionalNavigation: nil, withError:
            NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost,
                    userInfo: [NSURLErrorFailingURLErrorKey: failingURL]))
        XCTAssertEqual(app.lastErrorHost, "auth.example.com")
        XCTAssertEqual(app.lastErrorCode, NSURLErrorCannotFindHost)
        XCTAssertNotNil(app.lastErrorAt)
        XCTAssertNil(app.lastConnectionSecure, "A failed HTTPS request must never be called a verified secure connection")
        try await load("<html><body>Measured load</body></html>", in: session.rootPage.webView, baseURL: app.url)
        XCTAssertEqual(app.lastConnectionHost, "example.com")
        XCTAssertNotNil(app.lastConnectionAt)
        XCTAssertNotNil(app.lastLoadDuration)
        XCTAssertEqual(app.lastConnectionSecure, false, "A local HTML page must not claim a TLS-verified connection")
        app.clearDiagnostics()
        XCTAssertNil(app.lastConnectionAt)
        XCTAssertNil(app.lastErrorHost)
        XCTAssertNil(app.lastErrorCode)
    }

    func testDuplicateCopiesControlsWithoutActivityOrSession() {
        let app = LiteApp(name: "Work", url: URL(string: "https://example.com")!)
        app.websiteLayout = .desktop
        app.pageZoom = 1.2
        app.cameraPermission = .block
        app.allowsPopups = false
        app.automaticWindowOrigins = ["https://example.com:443"]
        app.lastOpenedAt = .now
        app.lastConnectionHost = "example.com"
        app.lastErrorCode = -1009
        let copy = app.duplicate()
        XCTAssertEqual(copy.websiteLayout, .desktop)
        XCTAssertEqual(copy.pageZoom, 1.2)
        XCTAssertEqual(copy.cameraPermission, .block)
        XCTAssertFalse(copy.allowsPopups)
        XCTAssertEqual(copy.automaticWindowOrigins, app.automaticWindowOrigins)
        XCTAssertNotEqual(copy.dataStoreIdentifier, app.dataStoreIdentifier)
        XCTAssertNil(copy.lastOpenedAt)
        XCTAssertNil(copy.lastConnectionHost)
        XCTAssertNil(copy.lastErrorCode)
    }

    func testPopulatedV2StoreMigratesWithoutLosingExistingSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("V2.store")
        let id = UUID(), profile = UUID()
        try writeV2Store(at: url, id: id, profile: profile)
        let container = try ModelContainer(for: LiteApp.self, PendingProfileDeletion.self,
            configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        let app = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<LiteApp>()).first)
        XCTAssertEqual(app.id, id)
        XCTAssertEqual(app.dataStoreIdentifier, profile)
        XCTAssertEqual(app.launchPagePreference, .continueLast)
        XCTAssertEqual(app.lastPageURL?.path, "/feed")
        XCTAssertTrue(app.isBiometricLocked)
        XCTAssertFalse(app.isBlockingEnabled)
        XCTAssertTrue(app.isFavorite)
        XCTAssertTrue(app.isVisibleInWidget)
        XCTAssertEqual(app.sortOrder, 3)
        XCTAssertEqual(app.websiteLayout, .mobile)
        XCTAssertEqual(app.effectivePageZoom, 1)
        XCTAssertEqual(app.cameraPermission, .ask)
        XCTAssertTrue(app.allowsJavaScript)
        XCTAssertTrue(app.allowsPopups)
        XCTAssertNil(app.lastOpenedAt)
        XCTAssertNil(app.lastConnectionAt)
        XCTAssertFalse(app.isProxyEnabled)
        XCTAssertEqual(app.proxyHost, "")
        XCTAssertEqual(app.proxyPort, 443)
        XCTAssertNil(app.proxyCredentialID)
    }

    private func writeV2Store(at url: URL, id: UUID, profile: UUID) throws {
        let container = try ModelContainer(for: V2ContainerFixture.LiteApp.self, V2ContainerFixture.PendingProfileDeletion.self,
            configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        let context = ModelContext(container)
        context.insert(V2ContainerFixture.LiteApp(id: id, profile: profile))
        try context.save()
    }

    private func makeCookie(value: String, domain: String = "example.com") throws -> HTTPCookie {
        try XCTUnwrap(HTTPCookie(properties: [.domain: domain, .path: "/", .name: "container_test", .value: value,
            .secure: "TRUE", .expires: Date(timeIntervalSinceNow: 3600)]))
    }

    private func load(_ html: String, in webView: WKWebView, baseURL: URL) async throws {
        webView.loadHTMLString(html, baseURL: baseURL)
        for _ in 0..<200 {
            try await Task.sleep(for: .milliseconds(50))
            if webView.url != nil && !webView.isLoading { return }
        }
        XCTFail("WebKit did not complete the local test document")
    }
}

private enum V2ContainerFixture {
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
        var launchPageRawValue: String = "start"
        var lastPageURL: URL?
        var isFavorite: Bool = false
        var sortOrder: Int = 0
        var isVisibleInWidget: Bool = false
        init(id: UUID, profile: UUID) {
            self.id = id; dataStoreIdentifier = profile
            name = "Existing V2"; url = URL(string: "https://example.com")!
            iconSymbol = "globe"; iconColor = "blue"; createdAt = .now
            isBiometricLocked = true; isBlockingEnabled = false
            launchPageRawValue = "continueLast"; lastPageURL = URL(string: "https://example.com/feed")
            isFavorite = true; sortOrder = 3; isVisibleInWidget = true
        }
    }
    @Model final class PendingProfileDeletion {
        @Attribute(.unique) var identifier: UUID
        init(identifier: UUID) { self.identifier = identifier }
    }
}

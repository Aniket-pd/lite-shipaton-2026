import Foundation
import Network
import WebKit
import XCTest
@testable import lite

@MainActor
final class BrowserProtectionTests: XCTestCase {
    func testPendingPopupMakesNoRequestUntilApprovalAndPreservesOriginalState() async throws {
        let server = try await BrowserFixtureServer.start()
        defer { server.stop() }
        let session = try await makeSession(server)
        defer { session.close() }
        let original = session.rootPage.webView
        _ = try await original.evaluateJavaScript("document.getElementById('note').value='keep this'; window.scrollTo(0,400)")
        let originalScroll = try await original.evaluateJavaScript("window.scrollY") as? Double
        // Actual user activation is exercised by UI tests. Lift only WebKit's gesture
        // gate here to exercise the real create-window/policy delegates deterministically.
        original.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        _ = try await original.evaluateJavaScript("window.child = window.open('/popup'); true")
        try await waitUntil { session.pendingWindow != nil }
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(server.requests.contains { $0.path == "/popup" })
        XCTAssertTrue(session.activePage.webView === original)
        XCTAssertEqual(session.pages.count, 1)
        let pending = try XCTUnwrap(session.pendingWindow)
        XCTAssertEqual(pending.page.webView.configuration.websiteDataStore.identifier, session.profileIdentifier)
        session.approvePendingWindow()
        try await waitUntil { session.activePage.webView.url?.path == "/popup" && !session.activePage.webView.isLoading }
        XCTAssertEqual(session.pages.count, 2)
        let opener = try await session.activePage.webView.evaluateJavaScript("window.opener !== null") as? Bool
        XCTAssertEqual(opener, true)
        session.closePopup()
        XCTAssertTrue(session.activePage.webView === original)
        let value = try await original.evaluateJavaScript("document.getElementById('note').value") as? String
        let scroll = try await original.evaluateJavaScript("window.scrollY") as? Double
        XCTAssertEqual(value, "keep this")
        XCTAssertEqual(scroll, originalScroll)
    }

    func testDismissAndCloseCancelPendingRequestWithoutLoadingIt() async throws {
        let server = try await BrowserFixtureServer.start()
        defer { server.stop() }
        let session = try await makeSession(server)
        defer { session.close() }
        let original = session.rootPage.webView
        original.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        _ = try await original.evaluateJavaScript("window.open('/dismissed'); true")
        try await waitUntil { session.pendingWindow != nil }
        session.dismissPendingWindow()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertNil(session.pendingWindow)
        XCTAssertFalse(server.requests.contains { $0.path == "/dismissed" })
        _ = try await original.evaluateJavaScript("window.open('/closed'); true")
        try await waitUntil { session.pendingWindow != nil }
        session.close()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertNil(session.pendingWindow)
        XCTAssertFalse(server.requests.contains { $0.path == "/closed" })
    }

    func testAutomaticWindowsBlockedAndKnownAdRedirectCannotReplaceOriginal() async throws {
        let server = try await BrowserFixtureServer.start()
        defer { server.stop() }
        // The script runs as website content, not evaluateJavaScript (which WebKit
        // can treat as user activation even when it schedules a short timer).
        let session = try await makeSession(server, path: "automatic-source")
        defer { session.close() }
        let original = session.rootPage.webView
        XCTAssertFalse(original.configuration.preferences.javaScriptCanOpenWindowsAutomatically)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(session.pendingWindow)
        XCTAssertFalse(server.requests.contains { $0.path == "/automatic" })
        XCTAssertEqual(session.pages.count, 1)
        _ = try await original.evaluateJavaScript("location.replace('https://doubleclick.net/advert'); true")
        try await waitUntil { session.protectionNotice != nil }
        XCTAssertEqual(original.url?.path, "/automatic-source")
        XCTAssertEqual(session.pages.count, 1)
    }

    func testPendingBlankWindowCannotLoadWrittenAdResources() async throws {
        let server = try await BrowserFixtureServer.start()
        defer { server.stop() }
        let session = try await makeSession(server)
        defer { session.close() }
        session.rootPage.webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        _ = try await session.rootPage.webView.evaluateJavaScript("""
            const w = window.open('about:blank'); w.document.write('<img src="\(server.url)/hidden-resource">'); true
            """)
        try await waitUntil { session.pendingWindow != nil }
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertFalse(server.requests.contains { $0.path == "/hidden-resource" })
        XCTAssertFalse(session.isShowingPopup)
        session.dismissPendingWindow()
    }

    func testReplacementNavigationCanRecoverWithoutAUsefulBackEntry() async throws {
        let server = try await BrowserFixtureServer.start()
        defer { server.stop() }
        let session = try await makeSession(server)
        defer { session.close() }
        let original = session.rootPage.webView
        _ = try await original.evaluateJavaScript("history.replaceState({}, '', '/original?view=detail'); true")
        _ = try await original.evaluateJavaScript("location.replace('/replacement?ad=1'); true")
        try await waitUntil { original.url?.path == "/replacement" && !original.isLoading }
        XCTAssertEqual(session.rootPage.recoveryURL?.path, "/original")
        XCTAssertEqual(session.rootPage.recoveryURL?.query, "view=detail", "Recover the current SPA route, not only its initial URL")
        XCTAssertFalse(original.canGoBack, "location.replace removed the original history entry")
        session.returnToPreviousPage()
        try await waitUntil { original.url?.path == "/original" && !original.isLoading }
        _ = try await original.evaluateJavaScript("location.replace('/replacement?ad=2'); true")
        try await waitUntil { session.protectionNotice != nil }
        XCTAssertEqual(original.url?.path, "/original", "Rotating ad parameters must not trap recovery again")
        // An unrelated JavaScript navigation must still work after recovery.
        _ = try await original.evaluateJavaScript("location.href='/legitimate'; true")
        try await waitUntil { original.url?.path == "/legitimate" && !original.isLoading }
    }

    func testPopupPOSTIsPreservedAndApprovalExceptionIsScopedToContainer() async throws {
        let server = try await BrowserFixtureServer.start()
        defer { server.stop() }
        let session = try await makeSession(server)
        defer { session.close() }
        let original = session.rootPage.webView
        original.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        _ = try await original.evaluateJavaScript("""
            const f=document.createElement('form'); f.action='/post'; f.method='POST'; f.target='_blank';
            const i=document.createElement('input'); i.name='payload'; i.value='original body'; f.append(i); document.body.append(f); f.submit(); true
            """)
        try await waitUntil { session.pendingWindow != nil }
        XCTAssertFalse(server.requests.contains { $0.path == "/post" })
        session.approvePendingWindow(alwaysAllow: true)
        try await waitUntil { session.activePage.webView.url?.path == "/post" && !session.activePage.webView.isLoading }
        let request = try XCTUnwrap(server.requests.first { $0.path == "/post" })
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.body, "payload=original+body")
        session.closePopup()
        _ = try await original.evaluateJavaScript("window.open('/trusted'); true")
        try await waitUntil { session.isShowingPopup }
        XCTAssertNil(session.pendingWindow)
        session.closePopup()
        // A separate container for the same origin must still ask.
        let other = try await makeSession(server)
        defer { other.close() }
        other.rootPage.webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        _ = try await other.rootPage.webView.evaluateJavaScript("window.open('/other-account'); true")
        try await waitUntil { other.pendingWindow != nil }
        XCTAssertFalse(other.isShowingPopup)
    }

    func testPendingWindowCannotRedirectOpenerOrCreateAWindowStorm() async throws {
        let server = try await BrowserFixtureServer.start()
        defer { server.stop() }
        let session = try await makeSession(server)
        defer { session.close() }
        let original = session.rootPage.webView
        original.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        _ = try await original.evaluateJavaScript("window.open('/first'); window.open('/second'); location.href='/takeover'; true")
        try await waitUntil { session.pendingWindow != nil && session.protectionNotice != nil }
        XCTAssertEqual(original.url?.path, "/original")
        XCTAssertEqual(session.pages.count, 1)
        XCTAssertFalse(server.requests.contains { ["/first", "/second", "/takeover"].contains($0.path) })
    }

    func testServerRedirectToAdLeavesOriginalPageUsable() async throws {
        let server = try await BrowserFixtureServer.start()
        defer { server.stop() }
        let session = try await makeSession(server)
        defer { session.close() }
        _ = try await session.rootPage.webView.evaluateJavaScript("location.href='/redirect-ad'; true")
        try await waitUntil { server.requests.contains { $0.path == "/redirect-ad" } && !session.rootPage.webView.isLoading }
        XCTAssertNil(session.rootPage.failure)
        let heading = try await session.rootPage.webView.evaluateJavaScript("document.querySelector('h1').textContent") as? String
        XCTAssertEqual(heading, "/original")
    }

    private func makeSession(_ server: BrowserFixtureServer, path: String = "original") async throws -> WebSession {
        let app = LiteApp(name: "Protection fixture", url: server.url.appendingPathComponent(path))
        let session = WebSession(app: app)
        session.rootPage.webView.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        await session.start()
        try await waitUntil { session.rootPage.committedURL?.path == "/" + path && !session.rootPage.webView.isLoading }
        return session
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<240 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Timed out waiting for WebKit")
        throw NSError(domain: "BrowserProtectionTests", code: 1)
    }
}

/// A loopback HTTP server makes policy/history/POST tests independent of public sites.
@MainActor
private final class BrowserFixtureServer {
    struct Request { let method: String; let path: String; let body: String }
    private let listener: NWListener
    private(set) var requests: [Request] = []
    private var connections: [NWConnection] = []
    var url: URL { URL(string: "http://127.0.0.1:\(listener.port!.rawValue)")! }

    private init() throws { listener = try NWListener(using: .tcp, on: .any) }

    static func start() async throws -> BrowserFixtureServer {
        let server = try BrowserFixtureServer()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var finished = false
            server.listener.stateUpdateHandler = { state in
                Task { @MainActor in
                    guard !finished else { return }
                    switch state {
                    case .ready: finished = true; continuation.resume()
                    case .failed(let error): finished = true; continuation.resume(throwing: error)
                    default: break
                    }
                }
            }
            server.listener.newConnectionHandler = { [weak server] connection in
                Task { @MainActor in
                    guard let server else { connection.cancel(); return }
                    server.connections.append(connection)
                    connection.start(queue: .main)
                    server.receive(connection, data: Data())
                }
            }
            server.listener.start(queue: .main)
        }
        return server
    }

    func stop() {
        listener.cancel()
        connections.forEach { $0.cancel() }
        connections = []
    }

    private func receive(_ connection: NWConnection, data: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] chunk, _, complete, error in
            Task { @MainActor in
                guard let self else { return }
                let accumulated = data + (chunk ?? Data())
                let text = String(decoding: accumulated, as: UTF8.self)
                guard let separator = text.range(of: "\r\n\r\n") else {
                    if !complete && error == nil { self.receive(connection, data: accumulated) }
                    return
                }
                let header = text[..<separator.lowerBound]
                let length = header.components(separatedBy: "\r\n")
                    .first { $0.lowercased().hasPrefix("content-length:") }
                    .flatMap { Int($0.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) } ?? 0
                let body = String(text[separator.upperBound...])
                if body.utf8.count < length, !complete, error == nil { self.receive(connection, data: accumulated); return }
                let first = header.components(separatedBy: "\r\n")[0].split(separator: " ")
                guard first.count >= 2 else { connection.cancel(); return }
                let path = String(first[1]).components(separatedBy: "?")[0]
                self.requests.append(Request(method: String(first[0]), path: path, body: body))
                if path == "/redirect-ad" {
                    let response = "HTTP/1.1 302 Found\r\nLocation: https://doubleclick.net/advert\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                    connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
                    return
                }
                let script = path == "/automatic-source" ? "<script>setTimeout(() => window.open('/automatic'), 20)</script>" : ""
                let html = "<html><meta name='viewport' content='width=device-width'><body><h1>\(path)</h1><input id='note'><div style='height:2000px'>Page content</div>\(script)</body></html>"
                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n\(html)"
                connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
            }
        }
    }
}

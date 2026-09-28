import Foundation
import Network
import SwiftData
import WebKit
import XCTest
@testable import lite

@MainActor
final class ContainerProxyTests: XCTestCase {
    func testEndpointValidationRejectsURLsAndInvalidPorts() throws {
        XCTAssertEqual(try ContainerProxy.validatedHost(" Proxy.Example.com "), "proxy.example.com")
        XCTAssertEqual(try ContainerProxy.validatedHost("[::1]"), "::1")
        for host in ["", "https://proxy.example.com", "user@host", "host:443", "host/path", "a..b", "-host", "host\nname", "host?token=1"] {
            XCTAssertThrowsError(try ContainerProxy.validatedHost(host), host)
        }
        let app = makeApp()
        app.isProxyEnabled = true
        app.proxyHost = "proxy.example.com"
        for port in [0, -1, 65536, Int.max] {
            app.proxyPort = port
            XCTAssertThrowsError(try ContainerProxy(app: app).configuration(profile: app.dataStoreIdentifier))
        }
    }

    func testKeychainIsolationAndAuthenticatedDuplicateBlocksUntilConfigured() async throws {
        let app = makeApp()
        app.isProxyEnabled = true
        app.proxyHost = "proxy.example.com"
        app.proxyUsername = "account"
        let credential = UUID()
        app.proxyCredentialID = credential
        try ProxyCredentialStore.save("test-password", profile: app.dataStoreIdentifier, credential: credential)
        defer { try? ProxyCredentialStore.remove(profile: app.dataStoreIdentifier) }
        XCTAssertEqual(try ProxyCredentialStore.password(profile: app.dataStoreIdentifier, credential: credential), "test-password")
        XCTAssertNil(try ProxyCredentialStore.password(profile: UUID(), credential: credential))
        let configs = try ContainerProxy(app: app).configuration(profile: app.dataStoreIdentifier)
        XCTAssertEqual(configs.count, 1)
        XCTAssertFalse(configs[0].allowFailover)
        XCTAssertTrue(configs[0].excludedDomains.isEmpty)
        let copy = app.duplicate()
        XCTAssertTrue(copy.isProxyEnabled)
        XCTAssertEqual(copy.proxyHost, app.proxyHost)
        XCTAssertNil(copy.proxyCredentialID)
        let session = WebSession(app: copy)
        defer { session.close() }
        await session.start()
        XCTAssertEqual(session.rootPage.failure?.title, "Proxy setup required")
        await session.retry()
        session.goHome()
        XCTAssertFalse(session.dataStore.isPersistent)
        XCTAssertNil(session.rootPage.webView.url)
        XCTAssertNil(copy.lastOpenedAt)
        app.resetContainerPreferences()
        XCTAssertTrue(app.isProxyEnabled, "Resetting browsing preferences must not silently disable proxy routing")
    }

    func testRoutesAreIndependentAndChangesRequireRestart() throws {
        let direct = makeApp(), proxied = makeApp()
        proxied.isProxyEnabled = true
        proxied.proxyHost = "proxy.example.com"
        let first = try WebProfileStore.configuredStore(for: direct)
        let second = try WebProfileStore.configuredStore(for: proxied)
        XCTAssertTrue(first.proxyConfigurations.isEmpty)
        XCTAssertEqual(second.proxyConfigurations.count, 1)
        XCTAssertFalse(second.proxyConfigurations[0].allowFailover)
        XCTAssertTrue(try WebProfileStore.configuredStore(for: proxied) === second)
        proxied.isProxyEnabled = false
        XCTAssertThrowsError(try WebProfileStore.configuredStore(for: proxied))
        XCTAssertEqual(second.proxyConfigurations.count, 1, "Do not mutate an established route")
        direct.isProxyEnabled = true
        direct.proxyHost = "proxy.example.com"
        XCTAssertThrowsError(try WebProfileStore.configuredStore(for: direct))
        WebProfileStore.release(identifier: direct.dataStoreIdentifier)
        XCTAssertThrowsError(try WebProfileStore.configuredStore(for: direct), "Releasing an object is not proof its network connections ended")
        WebProfileStore.prepareForRemoval(identifier: direct.dataStoreIdentifier)
        WebProfileStore.prepareForRemoval(identifier: proxied.dataStoreIdentifier)
    }

    func testSettingsPersistWithoutChangingProfileIdentity() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Proxy.store")
        let profile = try writeStore(at: storeURL)
        let store = try ModelContainer(for: LiteApp.self, configurations: ModelConfiguration(url: storeURL, cloudKitDatabase: .none))
        let app = try XCTUnwrap(ModelContext(store).fetch(FetchDescriptor<LiteApp>()).first)
        XCTAssertEqual(app.dataStoreIdentifier, profile)
        XCTAssertTrue(app.isProxyEnabled)
        XCTAssertEqual(app.proxyHost, "proxy.example.com")
        XCTAssertEqual(app.proxyPort, 8443)
        XCTAssertEqual(app.proxyUsername, "account")
        XCTAssertNotNil(app.proxyCredentialID)
    }

    func testHTTPSFailureReachesProxyWithoutLoadingDirectly() async throws {
        let proxy = try await ProxyProbeServer.start()
        defer { proxy.stop() }
        // WebKit bypasses localhost destinations. A reachable HTTPS origin proves
        // failure is caused by the proxy, not an unreachable destination or DNS.
        let directApp = makeApp()
        let direct = WebSession(app: directApp)
        defer { direct.close() }
        await direct.start()
        try await waitUntil { direct.rootPage.httpStatusCode == 200 || direct.rootPage.failure != nil }
        XCTAssertNil(direct.rootPage.failure, "example.com must be reachable for this integration test")
        XCTAssertEqual(direct.rootPage.httpStatusCode, 200)

        let app = makeApp()
        app.isProxyEnabled = true
        app.proxyHost = "127.0.0.1"
        app.proxyPort = Int(proxy.port)
        let session = WebSession(app: app)
        defer { session.close() }
        await session.start()
        try await waitUntil { session.rootPage.failure != nil || session.rootPage.httpStatusCode != nil }
        XCTAssertNotNil(session.rootPage.failure)
        XCTAssertGreaterThan(proxy.tlsHandshakes, 0, "The client must initiate TLS to its configured proxy")
        XCTAssertEqual(proxy.httpRequests, 0, "No cleartext CONNECT or proxy credentials")
        XCTAssertNil(session.rootPage.httpStatusCode, "Failure must never retry the reachable website directly")
    }

    func testIconRefreshUsesConfiguredTLSProxy() async throws {
        let proxy = try await ProxyProbeServer.start()
        defer { proxy.stop() }
        let app = makeApp()
        app.isProxyEnabled = true
        app.proxyHost = "127.0.0.1"
        app.proxyPort = Int(proxy.port)
        let configs = try ContainerProxy(app: app).configuration(profile: app.dataStoreIdentifier)
        let icon = await FaviconService(proxyConfigurations: configs).fetch(for: app.url)
        XCTAssertNil(icon)
        XCTAssertGreaterThan(proxy.tlsHandshakes, 0)
        XCTAssertEqual(proxy.httpRequests, 0)
    }

    private func makeApp(url: URL = URL(string: "https://example.com")!) -> LiteApp {
        let app = LiteApp(name: "Proxy test", url: url)
        app.isBlockingEnabled = false
        return app
    }

    private func writeStore(at url: URL) throws -> UUID {
        let store = try ModelContainer(for: LiteApp.self, configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        let context = ModelContext(store)
        let app = makeApp()
        app.isProxyEnabled = true
        app.proxyHost = "proxy.example.com"
        app.proxyPort = 8443
        app.proxyUsername = "account"
        app.proxyCredentialID = UUID()
        context.insert(app)
        try context.save()
        return app.dataStoreIdentifier
    }

    private func waitUntil(_ predicate: () -> Bool) async throws {
        for _ in 0..<500 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Timed out waiting for the controlled proxy fixture")
        throw NSError(domain: "ProxyTest", code: 1)
    }
}

/// Plain HTTP succeeds; TLS is deliberately rejected after recording its handshake.
/// This proves both transport-to-proxy selection and the absence of direct fallback.
@MainActor
private final class ProxyProbeServer {
    private let listener: NWListener
    private var connections: [NWConnection] = []
    private(set) var httpRequests = 0
    private(set) var tlsHandshakes = 0
    var port: UInt16 { listener.port!.rawValue }
    var url: URL { URL(string: "http://127.0.0.1:\(port)/proxy-test")! }
    nonisolated deinit {}
    private init() throws { listener = try NWListener(using: .tcp, on: .any) }

    static func start() async throws -> ProxyProbeServer {
        let server = try ProxyProbeServer()
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
            server.listener.newConnectionHandler = { connection in
                Task { @MainActor in
                    server.connections.append(connection)
                    connection.start(queue: .main)
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, _ in
                        Task { @MainActor in
                            if data?.first == 22 {
                                server.tlsHandshakes += 1
                                connection.cancel()
                            } else if data?.isEmpty == false {
                                server.httpRequests += 1
                                let body = "<html><body>Direct destination</body></html>"
                                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: \(body.utf8.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n\(body)"
                                connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
                            } else { connection.cancel() }
                        }
                    }
                }
            }
            server.listener.start(queue: .main)
        }
        return server
    }

    func stop() {
        listener.cancel()
        connections.forEach { $0.cancel() }
        listener.newConnectionHandler = nil
        listener.stateUpdateHandler = nil
        connections = []
    }
}

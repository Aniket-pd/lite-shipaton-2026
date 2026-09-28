import Foundation
import WebKit

/// Retains each account's profile for the process lifetime, without retaining web views.
/// Releasing the last data store can asynchronously tear down its network session;
/// keeping the identified store stable avoids that race during rapid close/reopen.
@MainActor
enum WebProfileStore {
    private static var stores: [UUID: WKWebsiteDataStore] = [:]
    private static var didInitializeWebKit = false
    private static var sessionRoutes: [UUID: ContainerProxy] = [:]

    static func configuredStore(for app: LiteApp) throws -> WKWebsiteDataStore {
        let route = ContainerProxy(app: app)
        let identifier = app.dataStoreIdentifier
        // Never switch a live network session: existing connections could survive
        // a proxy change. A new process applies the new route before first use.
        if let previous = sessionRoutes[identifier], previous != route {
            throw ProxyError.restartRequired
        }
        let configurations = try route.configuration(profile: identifier)
        let profile = store(for: identifier)
        if sessionRoutes[identifier] == nil {
            profile.proxyConfigurations = configurations
            sessionRoutes[identifier] = route
        }
        return profile
    }

    static func store(for identifier: UUID) -> WKWebsiteDataStore {
        if let store = stores[identifier] { return store }
        let store = WKWebsiteDataStore(forIdentifier: identifier)
        didInitializeWebKit = true
        stores[identifier] = store
        return store
    }

    /// Call only after this account's web views have been released, before deleting its profile.
    static func release(identifier: UUID) {
        stores.removeValue(forKey: identifier)
    }

    static func prepareForRemoval(identifier: UUID) {
        if !didInitializeWebKit {
            // WebKit's removal class method can run before its main run loop exists.
            // The public configuration initializer initializes the framework without
            // creating a profile. Never read its lazy default websiteDataStore property.
            autoreleasepool { _ = WKWebViewConfiguration() }
            didInitializeWebKit = true
        }
        // Do not reconstruct an initialized profile: its asynchronous directory setup
        // could otherwise race deletion and recreate a just-removed directory.
        release(identifier: identifier)
        sessionRoutes.removeValue(forKey: identifier)
    }
}

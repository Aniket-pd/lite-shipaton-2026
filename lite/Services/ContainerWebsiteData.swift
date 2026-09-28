import Foundation
import WebKit

@MainActor
enum ContainerWebsiteData {
    enum Removal {
        case cache, all, record(WKWebsiteDataRecord)
    }
    static let cacheTypes: Set<String> = [
        WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache,
        WKWebsiteDataTypeOfflineWebApplicationCache, WKWebsiteDataTypeFetchCache
    ]
    private static var pending: [UUID: [CheckedContinuation<Void, Never>]] = [:]

    /// A deep link can arrive while cleanup is awaiting WebKit. Do not create a
    /// new web view for that profile until the operation has completed.
    static func waitForCleanup(of identifier: UUID) async {
        while pending[identifier] != nil {
            await withCheckedContinuation { pending[identifier, default: []].append($0) }
        }
    }

    static func records(for identifier: UUID) async -> [WKWebsiteDataRecord] {
        await waitForCleanup(of: identifier)
        let records = await WebProfileStore.store(for: identifier)
            .dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
        return records.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    static func remove(_ removal: Removal, from identifier: UUID) async {
        await waitForCleanup(of: identifier)
        pending[identifier] = []
        defer {
            let waiting = pending.removeValue(forKey: identifier) ?? []
            waiting.forEach { $0.resume() }
        }
        let store = WebProfileStore.store(for: identifier)
        switch removal {
        case .cache:
            await store.removeData(ofTypes: cacheTypes, modifiedSince: .distantPast)
        case .all:
            await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        case .record(let record):
            await store.removeData(ofTypes: record.dataTypes, for: [record])
        }
    }

    static func typeNames(for record: WKWebsiteDataRecord) -> [String] {
        record.dataTypes.map { type in
            switch type {
            case WKWebsiteDataTypeCookies: "Cookies"
            case WKWebsiteDataTypeDiskCache: "Disk cache"
            case WKWebsiteDataTypeMemoryCache: "Memory cache"
            case WKWebsiteDataTypeOfflineWebApplicationCache: "Offline cache"
            case WKWebsiteDataTypeFetchCache: "Fetch cache"
            case WKWebsiteDataTypeLocalStorage: "Local storage"
            case WKWebsiteDataTypeSessionStorage: "Session storage"
            case WKWebsiteDataTypeIndexedDBDatabases: "IndexedDB"
            case WKWebsiteDataTypeWebSQLDatabases: "Web SQL"
            case WKWebsiteDataTypeServiceWorkerRegistrations: "Service workers"
            default: type.replacingOccurrences(of: "WKWebsiteDataType", with: "")
            }
        }.sorted()
    }
}

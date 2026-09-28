import Foundation
import SwiftData

/// Gives apps saved by older releases one bounded opportunity to adopt the
/// website-icon pipeline. The caller owns the one-time migration marker.
@MainActor
enum IconBackfillService {
    typealias Fetcher = @Sendable (URL) async -> Data?

    private struct WorkItem: Sendable {
        let key: String
        let url: URL
        let appIDs: [UUID]
    }

    @discardableResult
    static func backfill(
        apps: [LiteApp],
        in context: ModelContext,
        fetcher: @escaping Fetcher = { url in await FaviconService().fetch(for: url) }
    ) async -> Int {
        let missing = apps.filter { $0.iconData == nil }
        guard !missing.isEmpty else { return 0 }

        var updated = 0
        var remote: [LiteApp] = []
        for app in missing {
            if let bundled = CatalogIcon.data(for: app.url) {
                app.iconData = bundled
                updated += 1
            } else {
                remote.append(app)
            }
        }

        let work = workItems(for: remote)
        await withTaskGroup(of: ([UUID], Data?).self) { group in
            var nextIndex = 0
            for item in work.prefix(3) {
                group.addTask {
                    (item.appIDs, await fetcher(item.url))
                }
                nextIndex += 1
            }

            while let (appIDs, data) = await group.next() {
                if !Task.isCancelled, let data {
                    let ids = Set(appIDs)
                    for app in apps where ids.contains(app.id) && app.iconData == nil {
                        app.iconData = data
                        updated += 1
                    }
                }
                if nextIndex < work.count {
                    let item = work[nextIndex]
                    nextIndex += 1
                    group.addTask {
                        (item.appIDs, await fetcher(item.url))
                    }
                }
            }
        }

        guard !Task.isCancelled, context.hasChanges else { return updated }
        do {
            try context.save()
            return updated
        } catch {
            context.rollback()
            return 0
        }
    }

    private static func workItems(for apps: [LiteApp]) -> [WorkItem] {
        let grouped = Dictionary(grouping: apps) { originKey(for: $0.url) }
        return grouped.keys.sorted().compactMap { key in
            guard let group = grouped[key], let first = group.first else { return nil }
            return WorkItem(key: key, url: first.url, appIDs: group.map(\.id))
        }
    }

    private static func originKey(for url: URL) -> String {
        let scheme = url.scheme?.lowercased() ?? "https"
        let host = url.host?.lowercased() ?? url.absoluteString.lowercased()
        return "\(scheme)://\(host):\(url.port ?? 443)"
    }
}

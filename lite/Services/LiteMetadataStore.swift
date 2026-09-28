import Foundation

struct LiteLaunchMetadata: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let iconData: Data?
    let iconSymbol: String
    let iconColor: String
}

enum LiteMetadataStore {
    static let appGroup = "group.aniket.lite"
    private static let shortcutsKey = "launchMetadata.shortcuts.v2"
    private static let widgetKey = "launchMetadata.widget.v2"
    private static let pendingOpenKey = "pendingOpenAppID.v2"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func update(from apps: [LiteApp]) {
        let ordered = apps.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            return lhs.sortOrder == rhs.sortOrder ? lhs.createdAt < rhs.createdAt : lhs.sortOrder < rhs.sortOrder
        }
        let all = ordered.map { metadata($0) }
        let widget = ordered.filter(\.isVisibleInWidget).map { metadata($0) }
        save(all, key: shortcutsKey)
        save(widget, key: widgetKey)
        NotificationCenter.default.post(name: .liteWidgetMetadataChanged, object: nil)
    }

    static func shortcutEntries() -> [LiteLaunchMetadata] { load(key: shortcutsKey) }
    static func widgetEntries() -> [LiteLaunchMetadata] { load(key: widgetKey) }

    static func setPendingOpen(_ id: UUID, notify: Bool = true) {
        defaults.set(id.uuidString, forKey: pendingOpenKey)
        if notify { NotificationCenter.default.post(name: .liteOpenRequested, object: nil) }
    }

    static func takePendingOpen() -> UUID? {
        guard let raw = defaults.string(forKey: pendingOpenKey), let id = UUID(uuidString: raw) else { return nil }
        defaults.removeObject(forKey: pendingOpenKey)
        return id
    }

    private static func metadata(_ app: LiteApp) -> LiteLaunchMetadata {
        let safeIconData = app.iconData.flatMap {
            FaviconService.isVisuallyUsableIconData($0) ? $0 : nil
        }
        return LiteLaunchMetadata(id: app.id, name: app.name, iconData: safeIconData,
                           iconSymbol: app.iconSymbol, iconColor: app.iconColor)
    }

    private static func save(_ entries: [LiteLaunchMetadata], key: String) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(key: String) -> [LiteLaunchMetadata] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([LiteLaunchMetadata].self, from: data)) ?? []
    }
}

extension Notification.Name {
    static let liteOpenRequested = Notification.Name("LiteOpenRequested")
    static let liteWidgetMetadataChanged = Notification.Name("LiteWidgetMetadataChanged")
}

import Foundation

/// A visual grouping of independently persisted Lite Apps that point at the
/// same normalized website. The underlying LiteApp records and WebKit profile
/// identifiers are never combined.
struct LiteAppGroup: Identifiable {
    let id: String
    let websiteName: String
    let apps: [LiteApp]

    var lastUsedApp: LiteApp {
        apps.max { lhs, rhs in
            switch (lhs.lastOpenedAt, rhs.lastOpenedAt) {
            case let (left?, right?):
                if left != right { return left < right }
            case (nil, _?):
                return true
            case (_?, nil):
                return false
            case (nil, nil):
                break
            }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder > rhs.sortOrder }
            return lhs.createdAt > rhs.createdAt
        }!
    }

    var iconApp: LiteApp {
        if lastUsedApp.iconData != nil { return lastUsedApp }
        return apps.first(where: { $0.iconData != nil }) ?? lastUsedApp
    }

    var isFavorite: Bool { apps.contains(where: \.isFavorite) }
    var hasLockedProfile: Bool { apps.contains(where: \.isBiometricLocked) }
    var sortOrder: Int { apps.map(\.sortOrder).min() ?? 0 }
    var createdAt: Date { apps.map(\.createdAt).min() ?? .distantPast }

    func profileName(for app: LiteApp) -> String {
        LiteAppGrouping.profileName(for: app, websiteName: websiteName)
    }
}

enum LiteAppGrouping {
    static func groups(from apps: [LiteApp]) -> [LiteAppGroup] {
        Dictionary(grouping: apps, by: { groupID(for: $0.url) })
            .map { id, members in
                let ordered = members.sorted {
                    if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                    return $0.createdAt < $1.createdAt
                }
                return LiteAppGroup(
                    id: id,
                    websiteName: websiteName(for: ordered),
                    apps: ordered
                )
            }
            .sorted {
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.createdAt < $1.createdAt
            }
    }

    static func groupID(for url: URL) -> String {
        if let entry = DiscoverCatalog.entries.first(where: { DiscoverCatalog.matches($0, url: url) }) {
            return "catalog:\(entry.id)"
        }
        return "domain:\(normalizedHost(url))"
    }

    static func websiteName(for apps: [LiteApp]) -> String {
        guard let first = apps.first else { return "Website" }
        if let entry = DiscoverCatalog.entries.first(where: { DiscoverCatalog.matches($0, url: first.url) }) {
            return entry.service.name
        }

        if apps.count > 1,
           let prefix = commonNamePrefix(apps.map(\.name)),
           normalizedWord(prefix) == normalizedWord(domainStem(first.url)) {
            return prefix
        }
        return suggestedWebsiteName(for: first.url)
    }

    static func suggestedWebsiteName(for url: URL) -> String {
        if let entry = DiscoverCatalog.entries.first(where: { DiscoverCatalog.matches($0, url: url) }) {
            return entry.service.name
        }
        let stem = domainStem(url)
        let words = stem
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        return words.isEmpty ? "Website" : words.capitalized
    }

    static func profileName(for app: LiteApp, websiteName: String) -> String {
        let value = app.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "Default" }
        if value.compare(websiteName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
            return "Default"
        }
        if value.range(of: websiteName, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil {
            let suffix = value.dropFirst(websiteName.count)
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            if !suffix.isEmpty { return suffix }
        }
        return value
    }

    static func profileName(for app: LiteApp) -> String {
        profileName(for: app, websiteName: suggestedWebsiteName(for: app.url))
    }

    private static func normalizedHost(_ url: URL) -> String {
        var host = url.host?.lowercased() ?? url.absoluteString.lowercased()
        if host.hasSuffix(".") { host.removeLast() }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }

    private static func domainStem(_ url: URL) -> String {
        let components = normalizedHost(url).split(separator: ".")
        guard !components.isEmpty else { return "" }
        if components.count >= 3, ["app", "mail", "m", "mobile"].contains(String(components[0])) {
            return String(components[1])
        }
        return String(components[0])
    }

    private static func commonNamePrefix(_ names: [String]) -> String? {
        guard let first = names.first else { return nil }
        var prefix = first.split(whereSeparator: \.isWhitespace).map(String.init)
        for name in names.dropFirst() {
            let words = name.split(whereSeparator: \.isWhitespace).map(String.init)
            prefix = Array(zip(prefix, words).prefix {
                $0.0.compare($0.1, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }.map(\.0))
            if prefix.isEmpty { return nil }
        }
        return prefix.isEmpty ? nil : prefix.joined(separator: " ")
    }

    private static func normalizedWord(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map(String.init)
            .joined()
    }
}

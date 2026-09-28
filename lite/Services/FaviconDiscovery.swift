import Foundation

/// Bounded metadata discovery only: never executes website scripts or loads a WebView.
nonisolated enum FaviconDiscovery {
    enum Source: Sendable, Equatable {
        case htmlIcon
        case appleTouchIcon
        case manifestAny
        case manifestMaskable
        case rootAppleTouchIcon
        case rootFavicon

        /// Source intent breaks ties between similarly sized images. A declared
        /// app/touch icon is generally a better tile than a generic favicon.
        var qualityBonus: Int {
            switch self {
            case .appleTouchIcon: 60
            case .manifestAny: 55
            case .rootAppleTouchIcon: 50
            case .manifestMaskable: 45
            case .htmlIcon: 30
            case .rootFavicon: 10
            }
        }

        var requestPriority: Int {
            switch self {
            case .appleTouchIcon, .manifestAny: 3
            case .manifestMaskable: 2
            case .htmlIcon: 1
            case .rootAppleTouchIcon, .rootFavicon: 0
            }
        }
    }

    struct Candidate: Sendable {
        let url: URL
        let declaredSize: Int
        let source: Source

        init(url: URL, declaredSize: Int, source: Source = .htmlIcon) {
            self.url = url
            self.declaredSize = declaredSize
            self.source = source
        }
    }

    static func secureURL(_ value: String, relativeTo base: URL) -> URL? {
        guard value.count <= 4096,
              let url = URL(string: decodeEntities(value), relativeTo: base)?.absoluteURL,
              url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    static func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.scheme?.lowercased() == rhs.scheme?.lowercased() &&
        lhs.host?.lowercased() == rhs.host?.lowercased() && (lhs.port ?? 443) == (rhs.port ?? 443)
    }

    /// Allows conventional host variants and subdomains belonging to the same
    /// site, without treating lookalike suffixes as related.
    static func sameSiteHost(_ lhs: String?, _ rhs: String?) -> Bool {
        func canonical(_ host: String?) -> String? {
            guard let host else { return nil }
            let lowercase = host.lowercased()
            return lowercase.hasPrefix("www.") ? String(lowercase.dropFirst(4)) : lowercase
        }
        guard let lhs = canonical(lhs), let rhs = canonical(rhs) else { return false }
        return lhs == rhs || lhs.hasSuffix(".\(rhs)") || rhs.hasSuffix(".\(lhs)")
    }

    static func html(_ data: Data, at pageURL: URL) -> (icons: [Candidate], manifest: URL?) {
        guard data.count <= 1_048_576, let text = String(data: data, encoding: .utf8) else { return ([], nil) }
        // Ignore link-looking text inside comments and raw-text elements.
        let cleaned = text.replacingOccurrences(
            of: #"(?is)<!--.*?(?:-->|$)|<(script|style|textarea)\b[^>]*>.*?(?:</\1\s*>|$)"#,
            with: "", options: .regularExpression)
        let headEnd = cleaned.range(of: "</head", options: .caseInsensitive)?.lowerBound ?? cleaned.endIndex
        let head = String(cleaned[..<headEnd])
        let tags = matches(#"(?is)<(?:link|base)\b(?:[^>\"']|\"[^\"]*\"|'[^']*')*>"#, in: head)
        var base = pageURL
        var hasBase = false
        var icons: [Candidate] = []
        var manifest: URL?
        for tag in tags.prefix(128) {
            let attributes = attributes(in: tag)
            guard let href = attributes["href"] else { continue }
            if tag.lowercased().hasPrefix("<base") {
                if !hasBase, let resolved = secureURL(href, relativeTo: pageURL), sameOrigin(resolved, pageURL) {
                    base = resolved
                    hasBase = true
                }
                continue
            }
            guard let url = secureURL(href, relativeTo: base) else { continue }
            let rel = Set((attributes["rel"] ?? "").lowercased().split(whereSeparator: \.isWhitespace).map(String.init))
            if rel.contains("manifest"), manifest == nil, sameOrigin(url, pageURL) { manifest = url }
            if !rel.isDisjoint(with: ["icon", "apple-touch-icon", "apple-touch-icon-precomposed"]) {
                let source: Source = rel.contains("apple-touch-icon") || rel.contains("apple-touch-icon-precomposed")
                    ? .appleTouchIcon : .htmlIcon
                icons.append(Candidate(url: url, declaredSize: size(attributes["sizes"]), source: source))
            }
        }
        return (icons, manifest)
    }

    static func manifest(_ data: Data, at url: URL) -> [Candidate] {
        guard data.count <= 262_144,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let icons = json["icons"] as? [[String: Any]] else { return [] }
        return icons.prefix(32).compactMap { icon in
            let purposes = (icon["purpose"] as? String ?? "any").split(whereSeparator: \.isWhitespace)
            guard purposes.contains("any") || purposes.contains("maskable"),
                  let src = icon["src"] as? String,
                  let resolved = secureURL(src, relativeTo: url) else { return nil }
            let source: Source = purposes.contains("any") ? .manifestAny : .manifestMaskable
            return Candidate(url: resolved, declaredSize: size(icon["sizes"] as? String), source: source)
        }
    }

    static func ranked(_ candidates: [Candidate]) -> [Candidate] {
        var seen = Set<URL>()
        // Declared sizes only prioritize requests. Decoded dimensions decide acceptance.
        return candidates.enumerated().sorted {
            if $0.element.source.requestPriority != $1.element.source.requestPriority {
                return $0.element.source.requestPriority > $1.element.source.requestPriority
            }
            return $0.element.declaredSize == $1.element.declaredSize ? $0.offset < $1.offset :
                $0.element.declaredSize > $1.element.declaredSize
        }.map(\.element).filter { seen.insert($0.url).inserted }.prefix(8).map { $0 }
    }

    private static func size(_ value: String?) -> Int {
        (value ?? "").lowercased().split(whereSeparator: \.isWhitespace).compactMap { item in
            let sides = item.split(separator: "x").compactMap { Int($0) }
            return sides.count == 2 ? min(max(sides[0], 0), max(sides[1], 0)) : nil
        }.max() ?? 0
    }

    private static func attributes(in tag: String) -> [String: String] {
        let pattern = #"([\w:-]+)\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }
        let text = tag as NSString
        var result: [String: String] = [:]
        for match in regex.matches(in: tag, range: NSRange(location: 0, length: text.length)) {
            let name = text.substring(with: match.range(at: 1)).lowercased()
            guard result[name] == nil else { continue }
            for index in 2...4 where match.range(at: index).location != NSNotFound {
                result[name] = text.substring(with: match.range(at: index))
            }
        }
        return result
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let string = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: string.length)).map {
            string.substring(with: $0.range)
        }
    }

    private static func decodeEntities(_ string: String) -> String {
        var result = string
        for (entity, value) in [("&quot;", "\""), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&")] {
            result = result.replacingOccurrences(of: entity, with: value)
        }
        return result
    }
}

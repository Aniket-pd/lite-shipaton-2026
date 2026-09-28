import Foundation

enum DiscoverCategory: String, CaseIterable, Identifiable {
    case all = "All", social = "Social", productivity = "Productivity", ai = "AI"
    case creativity = "Design", entertainment = "Entertainment", shopping = "Shopping"
    var id: String { rawValue }
}

struct DiscoverEntry: Identifiable, Hashable {
    let service: CatalogService
    let category: DiscoverCategory
    let keywords: String
    var id: String { service.id }
    var url: URL { URL(string: service.address)! }
    var domain: String { DiscoverCatalog.host(url) }

    init(_ id: String, _ name: String, _ address: String, _ symbol: String, _ color: String,
         _ category: DiscoverCategory, _ description: String, _ keywords: String) {
        service = CatalogService(id: id, name: name, address: address, symbol: symbol, color: color, category: description)
        self.category = category
        self.keywords = keywords
    }

    static func website(_ url: URL) -> DiscoverEntry {
        DiscoverCatalog.entries.first { DiscoverCatalog.matches($0, url: url) && $0.url == url }
            ?? DiscoverEntry(url.absoluteString, String(DiscoverCatalog.host(url).prefix(40)), url.absoluteString,
                             "globe", "blue", .all, "A website with a place of its own.", "")
    }
}

enum DiscoverCollection: String, CaseIterable, Identifiable {
    case essentials, creative, focused
    var id: String { rawValue }
    var title: String {
        switch self {
        case .essentials: "Everyday essentials"
        case .creative: "Make something great"
        case .focused: "Find your focus"
        }
    }
    var subtitle: String {
        switch self {
        case .essentials: "Your daily favorites, a little lighter."
        case .creative: "A fresh canvas for your next idea."
        case .focused: "Room for your notes, tasks, and plans."
        }
    }
    var ids: [String] {
        switch self {
        case .essentials: ["gmail", "youtube", "reddit", "instagram"]
        case .creative: ["canva", "photopea", "figma"]
        case .focused: ["notion", "todoist", "trello", "proton"]
        }
    }
    var entries: [DiscoverEntry] { ids.compactMap { id in DiscoverCatalog.entries.first { $0.id == id } } }
}

/// Discover has its own editorial catalog; the existing creation picker is unchanged.
enum DiscoverCatalog {
    static let entries: [DiscoverEntry] = [
        .init("instagram", "Instagram", "https://www.instagram.com", "camera", "pink", .social, "Photos, friends, and everyday moments.", "photos friends reels messages"),
        .init("gmail", "Gmail", "https://mail.google.com", "envelope", "red", .productivity, "A focused home for your inbox.", "email mail google work"),
        .init("youtube", "YouTube", "https://m.youtube.com", "play.rectangle", "red", .entertainment, "Videos for every curiosity.", "video music watch learn"),
        .init("reddit", "Reddit", "https://www.reddit.com", "bubble.left.and.bubble.right", "orange", .social, "Find people who share your interests.", "communities forum discussion"),
        .init("notion", "Notion", "https://www.notion.so", "doc.text", "graphite", .productivity, "Notes, projects, and plans together.", "notes documents wiki workspace writing"),
        .init("chatgpt", "ChatGPT", "https://chatgpt.com", "sparkles", "teal", .ai, "Explore ideas and work through questions.", "assistant writing chat research openai"),
        .init("x", "X", "https://x.com", "text.bubble", "graphite", .social, "Follow conversations as they happen.", "twitter news posts"),
        .init("linkedin", "LinkedIn", "https://www.linkedin.com", "person.2", "blue", .social, "Keep up with your professional world.", "jobs career work network"),
        .init("amazon", "Amazon", "https://www.amazon.com", "bag", "orange", .shopping, "Browse your everyday shopping needs.", "buy store shopping products"),
        .init("canva", "Canva", "https://www.canva.com", "paintpalette", "teal", .creativity, "Bring presentations and designs to life.", "design presentation graphics photo editor"),
        .init("photopea", "Photopea", "https://www.photopea.com", "photo.artframe", "green", .creativity, "An image editor right in your browser.", "photo editor photoshop image pictures"),
        .init("figma", "Figma", "https://www.figma.com", "square.on.circle", "purple", .creativity, "A shared space for design ideas.", "design prototype interface collaboration"),
        .init("todoist", "Todoist", "https://app.todoist.com", "checklist", "red", .productivity, "Give your tasks a little structure.", "tasks checklist reminders focus to do"),
        .init("trello", "Trello", "https://trello.com", "rectangle.split.3x1", "blue", .productivity, "Organize your projects on visual boards.", "tasks kanban project boards planning"),
        .init("proton", "Proton Mail", "https://mail.proton.me", "envelope.badge.shield.half.filled", "purple", .productivity, "A separate space for your Proton inbox.", "email mail inbox"),
        .init("claude", "Claude", "https://claude.ai", "sparkles", "orange", .ai, "Think, write, and explore ideas.", "assistant chat writing anthropic"),
        .init("perplexity", "Perplexity", "https://www.perplexity.ai", "sparkle.magnifyingglass", "teal", .ai, "Follow your questions a little further.", "search research answers assistant"),
        .init("spotify", "Spotify", "https://open.spotify.com", "music.note", "green", .entertainment, "Explore music, podcasts, and playlists.", "music audio podcasts listen"),
        .init("wikipedia", "Wikipedia", "https://www.wikipedia.org", "book", "graphite", .entertainment, "A starting point for your curiosity.", "learn encyclopedia reading knowledge"),
        .init("pinterest", "Pinterest", "https://www.pinterest.com", "pin", "red", .creativity, "Collect inspiration for what comes next.", "ideas inspiration moodboard design"),
        .init("ebay", "eBay", "https://www.ebay.com", "tag", "blue", .shopping, "Find something new or one of a kind.", "buy sell shopping marketplace")
    ]

    static func search(_ query: String, category: DiscoverCategory = .all) -> [DiscoverEntry] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = term.split(whereSeparator: \.isWhitespace).map(String.init)
        return entries.filter { entry in
            (category == .all || entry.category == category) &&
            words.allSatisfy { word in
                "\(entry.service.name) \(entry.domain) \(entry.category.rawValue) \(entry.service.category) \(entry.keywords)"
                    .localizedStandardContains(word)
            }
        }.sorted { lhs, rhs in
            func rank(_ entry: DiscoverEntry) -> Int {
                if entry.service.name.compare(term, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame { return 0 }
                if entry.service.name.lowercased().hasPrefix(term.lowercased()) { return 1 }
                return 2
            }
            let a = rank(lhs), b = rank(rhs)
            return a == b ? entries.firstIndex(of: lhs)! < entries.firstIndex(of: rhs)! : a < b
        }
    }

    static func host(_ url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    static func matches(_ entry: DiscoverEntry, url: URL) -> Bool {
        guard url.scheme == "https", url.user == nil, url.password == nil,
              (url.port ?? 443) == (entry.url.port ?? 443) else { return false }
        if host(entry.url) == host(url) { return true }
        return entry.id == "youtube" && ["youtube.com", "m.youtube.com"].contains(host(url))
    }

    /// Plain app names stay searches, even though URL validation accepts single-label hosts.
    static func looksLikeAddress(_ query: String) -> Bool {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*:", options: .regularExpression) != nil { return true }
        return !value.contains(where: \.isWhitespace) && (value.contains(".") || value.hasPrefix("["))
    }

    static func searchURL(_ query: String) -> URL {
        var components = URLComponents(string: "https://duckduckgo.com/")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url!
    }

    static func isSearchPage(_ url: URL) -> Bool {
        let domain = host(url)
        return domain == "duckduckgo.com" || domain.hasSuffix(".duckduckgo.com")
    }
}

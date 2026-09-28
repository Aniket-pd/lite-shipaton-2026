import Foundation

struct CatalogService: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    let symbol: String
    let color: String
    let category: String

    static let all: [CatalogService] = [
        .init(id: "instagram", name: "Instagram", address: "https://www.instagram.com", symbol: "camera", color: "pink", category: "Photos & friends"),
        .init(id: "reddit", name: "Reddit", address: "https://www.reddit.com", symbol: "bubble.left.and.bubble.right", color: "orange", category: "Communities & conversations"),
        .init(id: "x", name: "X", address: "https://x.com", symbol: "text.bubble", color: "graphite", category: "What’s happening"),
        .init(id: "linkedin", name: "LinkedIn", address: "https://www.linkedin.com", symbol: "person.2", color: "blue", category: "Your professional network"),
        .init(id: "gmail", name: "Gmail", address: "https://mail.google.com", symbol: "envelope", color: "red", category: "Email, made lighter"),
        .init(id: "amazon", name: "Amazon", address: "https://www.amazon.com", symbol: "bag", color: "orange", category: "Everyday shopping"),
        .init(id: "youtube", name: "YouTube", address: "https://m.youtube.com", symbol: "play.rectangle", color: "red", category: "Videos & discoveries")
    ]
}

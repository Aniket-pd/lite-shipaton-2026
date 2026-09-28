import Foundation
import UIKit

/// Reviewed, bundled artwork makes catalog icons available instantly and offline.
@MainActor
enum CatalogIcon {
    private static let hosts: [String: String] = [
        "instagram.com": "instagram", "www.instagram.com": "instagram",
        "reddit.com": "reddit", "www.reddit.com": "reddit",
        "x.com": "x", "www.x.com": "x",
        "linkedin.com": "linkedin", "www.linkedin.com": "linkedin",
        "mail.google.com": "gmail",
        "amazon.com": "amazon", "www.amazon.com": "amazon",
        "youtube.com": "youtube", "www.youtube.com": "youtube", "m.youtube.com": "youtube"
    ]
    private static var cachedData: [String: Data] = [:]

    static func assetName(for url: URL?) -> String? {
        guard let url, url.scheme?.lowercased() == "https", url.user == nil, url.password == nil,
              (url.port ?? 443) == 443,
              let host = url.host?.lowercased(), let name = hosts[host] else { return nil }
        return "Service-\(name)"
    }

    static func data(for url: URL) -> Data? {
        guard let name = assetName(for: url) else { return nil }
        if let data = cachedData[name] { return data }
        guard let image = UIImage(named: name), let data = image.pngData() else { return nil }
        cachedData[name] = data
        return data
    }
}

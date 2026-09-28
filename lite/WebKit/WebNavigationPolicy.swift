import Foundation

enum WebNavigationPolicy {
    enum Disposition: Equatable { case web, external, blocked }

    static func isPolicyCancellation(_ error: NSError) -> Bool {
        // WebKit emits this legacy public error for content-rule and navigation
        // policy cancellations, including blocked HTTP redirect destinations.
        (error.domain == "WebKitErrorDomain" && error.code == 102)
            || (error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled)
    }

    static func origin(of url: URL?) -> String? {
        guard let url, let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme), let host = url.host?.lowercased() else { return nil }
        let port = url.port ?? (scheme == "https" ? 443 : 80)
        return "\(scheme)://\(host):\(port)"
    }

    static func disposition(for url: URL) -> Disposition {
        switch url.scheme?.lowercased() {
        case "https", "http":
            return url.host?.isEmpty == false && url.user == nil && url.password == nil ? .web : .blocked
        case "about":
            return url.absoluteString == "about:blank" ? .web : .blocked
        case "tel", "mailto", "sms", "maps":
            return .external
        default:
            return .blocked
        }
    }
}

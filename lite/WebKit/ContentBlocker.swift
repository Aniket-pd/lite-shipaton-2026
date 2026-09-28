import CryptoKit
import Foundation
import WebKit

/// The same pinned domain list protects WebKit resources and native navigations.
/// Lists are bundled, compiled locally, and never receive browsing information.
@MainActor
enum ContentBlocker {
    private static let source = Bundle.main.url(forResource: "AdBlockDomains", withExtension: "txt")
        .flatMap { try? Data(contentsOf: $0) }
    static let identifier = "lite.ads.v3." + (source.map {
        SHA256.hash(data: $0).prefix(8).map { String(format: "%02x", $0) }.joined()
    } ?? "missing")

    static let domains: Set<String> = {
        guard let source, let text = String(data: source, encoding: .utf8) else { return [] }
        return Set(text.split(whereSeparator: \.isNewline)
            .filter { !$0.hasPrefix("#") }.map(String.init)).union([
                // Retain Lite's original coverage alongside the upstream snapshot.
                "doubleclick.net", "googlesyndication.com", "google-analytics.com",
                "adservice.google.com", "adsrvr.org", "adnxs.com", "criteo.com",
                "scorecardresearch.com", "quantserve.com", "hotjar.com"
            ])
    }()

    static let listVersion: String = {
        guard let source, let text = String(data: source, encoding: .utf8) else { return "Unavailable" }
        return text.split(whereSeparator: \.isNewline)
            .first { $0.hasPrefix("# Last modified: ") }
            .map { String($0.dropFirst("# Last modified: ".count)) } ?? "Bundled list"
    }()

    static func blocks(_ url: URL) -> Bool {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              var host = url.host?.lowercased() else { return false }
        while host.hasSuffix(".") { host.removeLast() }
        while host.contains(".") {
            if domains.contains(host) { return true }
            host = String(host.drop(while: { $0 != "." }).dropFirst())
        }
        return false
    }

    static let encodedRules: String = {
        // Fail closed if the bundle is missing or malformed, rather than claiming protection.
        guard domains.count > 10_000,
              domains.allSatisfy({ $0.range(of: #"^([a-z0-9-]+\.)+[a-z0-9-]+$"#, options: .regularExpression) != nil }) else { return "" }
        let sorted = domains.sorted()
        var rules: [[String: Any]] = []
        // WebKit content rules do not support regex alternation. One rule per
        // domain stays within the engine's limit and keeps matching predictable.
        for domain in sorted {
            let escaped = domain.replacingOccurrences(of: ".", with: "\\.")
            rules.append([
                "trigger": ["url-filter": "^https?://([^/]+\\.)?" + escaped + "\\.?[:/]"],
                "action": ["type": "block"]
            ])
        }
        // Hide recognizable ad containers, not generic dialogs, consent or login overlays.
        rules.append([
            "trigger": ["url-filter": ".*"],
            "action": ["type": "css-display-none", "selector":
                "ins.adsbygoogle, [id^='google_ads_iframe'], [id^='div-gpt-ad'], [data-ad-slot], .ad-banner, .ad-container, #ad-banner, #ad-container"]
        ])
        guard let data = try? JSONSerialization.data(withJSONObject: rules, options: [.sortedKeys]) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }()

    private static var cachedRules: WKContentRuleList?
    private static var compilation: Task<WKContentRuleList, Error>?
    private static var cachedPendingRules: WKContentRuleList?

    /// A pending about:blank window can have document.write content. Prevent that
    /// hidden document from fetching assets before the person chooses Open.
    static func pendingWindowRules() async throws -> WKContentRuleList {
        if let cachedPendingRules { return cachedPendingRules }
        let rules: WKContentRuleList = try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "lite.pending-window.v1",
                encodedContentRuleList: #"[{"trigger":{"url-filter":".*"},"action":{"type":"block"}}]"#
            ) { rules, error in
                if let rules { continuation.resume(returning: rules) }
                else { continuation.resume(throwing: error ?? RuleError.compilationFailed) }
            }
        }
        cachedPendingRules = rules
        return rules
    }

    static func rules() async throws -> WKContentRuleList {
        if let cachedRules { return cachedRules }
        if let compilation { return try await compilation.value }
        let task = Task<WKContentRuleList, Error> { @MainActor in
            if let existing = try? await WKContentRuleListStore.default().contentRuleList(forIdentifier: identifier) {
                return existing
            }
            return try await withCheckedThrowingContinuation { continuation in
                WKContentRuleListStore.default().compileContentRuleList(
                    forIdentifier: identifier, encodedContentRuleList: encodedRules
                ) { rules, error in
                    if let rules { continuation.resume(returning: rules) }
                    else { continuation.resume(throwing: error ?? RuleError.compilationFailed) }
                }
            }
        }
        compilation = task
        defer { compilation = nil }
        let rules = try await task.value
        cachedRules = rules
        return rules
    }

    private enum RuleError: Error { case compilationFailed }
}

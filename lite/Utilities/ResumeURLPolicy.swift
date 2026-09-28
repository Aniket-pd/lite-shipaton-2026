import Foundation

enum ResumeURLPolicy {
    private static let temporaryPathTerms = [
        "oauth", "authorize", "callback", "signin", "sign-in", "login", "logout",
        "sso", "challenge", "checkpoint", "verify", "authentication", "auth", "session", "reset", "password", "magic"
    ]

    static func sanitizedCandidate(_ candidate: URL, for startURL: URL) -> URL? {
        guard isSuitable(candidate, for: startURL),
              var components = URLComponents(url: candidate, resolvingAgainstBaseURL: false) else { return nil }
        components.fragment = nil
        return components.url
    }

    static func isSuitable(_ candidate: URL, for startURL: URL) -> Bool {
        guard let scheme = candidate.scheme?.lowercased(),
              scheme == "https",
              candidate.user == nil,
              candidate.password == nil,
              // Unknown query names can carry credentials; omit the whole page
              // rather than save a changed URL that may no longer work.
              candidate.query == nil,
              let candidateHost = candidate.host?.lowercased(),
              let startHost = startURL.host?.lowercased(),
              sameSite(candidateHost, startHost), candidate.port == startURL.port else { return false }

        let path = candidate.path.lowercased()
        guard !temporaryPathTerms.contains(where: path.contains) else { return false }
        return true
    }

    private static func canonicalHost(_ host: String) -> String {
        host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private static func sameSite(_ lhs: String, _ rhs: String) -> Bool {
        canonicalHost(lhs) == canonicalHost(rhs)
    }
}

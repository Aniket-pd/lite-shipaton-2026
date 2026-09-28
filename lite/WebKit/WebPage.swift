import Foundation
import Observation
import WebKit

@Observable
@MainActor
final class WebPage: Identifiable {
    let id = UUID()
    let webView: WKWebView
    private(set) var url: URL?
    private(set) var progress = 0.0
    private(set) var isLoading = false
    private(set) var canGoBack = false
    private(set) var canGoForward = false
    private(set) var hasSecureConnection = false
    private(set) var pageBackgroundColor: UIColor?
    private(set) var httpStatusCode: Int?
    private(set) var navigationMethod = "GET"
    var failure: WebFailure?
    var retryURL: URL?
    var navigationStartedAt: Date?
    private(set) var committedURL: URL?
    private(set) var committedMethod = "GET"
    private(set) var recoveryURL: URL?
    @ObservationIgnored private var recoveryItem: WKBackForwardListItem?
    @ObservationIgnored private var isRecovering = false
    @ObservationIgnored private var recoveryDestination: URL?
    @ObservationIgnored private var redirectDestinations: Set<String> = []
    @ObservationIgnored private var blockedRepeatDestinations: Set<String> = []

    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    // Cleanup is explicit in tearDown(). Avoid Swift's synthesized isolated-deinit
    // runtime crash on iOS 26.2 and older (swiftlang/swift#88036).
    nonisolated deinit {}

    init(webView: WKWebView) {
        self.webView = webView
        // WebKit exposes these properties as KVO-compliant public API.
        observations = [
            webView.observe(\.url, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.refresh() }
            },
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.refresh() }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.refresh() }
            },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.refresh() }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.refresh() }
            },
            webView.observe(\.hasOnlySecureContent, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.refresh() }
            },
            webView.observe(\.underPageBackgroundColor, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.refreshAppearance() }
            }
        ]
    }

    func refresh() {
        url = webView.url
        progress = webView.estimatedProgress
        isLoading = webView.isLoading
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        hasSecureConnection = webView.url?.scheme == "https" && webView.serverTrust != nil && webView.hasOnlySecureContent
    }

    private func refreshAppearance() {
        // Leave WebKit's automatic under-page color enabled. Assigning that
        // property would pin it and stop following subsequent website changes.
        pageBackgroundColor = webView.underPageBackgroundColor
        webView.scrollView.backgroundColor = pageBackgroundColor
    }

    func record(request: URLRequest) {
        navigationMethod = request.httpMethod?.uppercased() ?? "GET"
        httpStatusCode = nil
    }

    func record(response: URLResponse) {
        httpStatusCode = (response as? HTTPURLResponse)?.statusCode
    }

    func prepareRecovery(for request: URLRequest, type: WKNavigationType) {
        // SPA routes can change with history.replaceState without a new commit.
        let displayedURL = webView.isLoading ? committedURL : (webView.url ?? committedURL)
        guard !isRecovering, type != .backForward, type != .reload,
              let from = displayedURL, let to = request.url, from != to,
              committedMethod == "GET", ["http", "https"].contains(from.scheme ?? "") else { return }
        // Keep the original destination across automatic redirect chains.
        if recoveryURL == nil || type == .linkActivated || type == .formSubmitted {
            recoveryURL = from
            recoveryItem = webView.backForwardList.currentItem
            redirectDestinations = []
        }
        redirectDestinations.insert(Self.redirectKey(to))
    }

    func didCommitPage() {
        committedURL = webView.url
        committedMethod = navigationMethod
        if isRecovering, committedURL == recoveryDestination { isRecovering = false }
    }

    func blocksRepeatedRedirect(to url: URL, type: WKNavigationType) -> Bool {
        guard let recoveryDestination else { return false }
        if isRecovering, url == recoveryDestination { return false }
        if type == .linkActivated || type == .formSubmitted || type == .backForward {
            self.recoveryDestination = nil
            isRecovering = false
            blockedRepeatDestinations = []
            return false
        }
        return type == .other && blockedRepeatDestinations.contains(Self.redirectKey(url))
    }

    func recover() {
        guard let recoveryURL else { return }
        webView.stopLoading()
        failure = nil
        retryURL = recoveryURL
        recoveryDestination = recoveryURL
        blockedRepeatDestinations = redirectDestinations
        isRecovering = true
        if let recoveryItem, webView.backForwardList.backList.contains(where: { $0 === recoveryItem }) {
            webView.go(to: recoveryItem)
        } else {
            // Never replay a POST or persist sensitive history. This is a GET fallback.
            webView.load(URLRequest(url: recoveryURL))
        }
        self.recoveryURL = nil
        recoveryItem = nil
    }

    func clearRecovery() {
        recoveryURL = nil
        recoveryItem = nil
        recoveryDestination = nil
        isRecovering = false
        redirectDestinations = []
        blockedRepeatDestinations = []
    }

    private static func redirectKey(_ url: URL) -> String {
        // Ignore rotating tracking tokens without blocking unrelated routes on the site.
        (WebNavigationPolicy.origin(of: url) ?? "") + url.path
    }

    func tearDown() {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        observations.removeAll()
    }
}

struct WebFailure {
    let title: String
    let message: String
    let symbol: String

    static let protection = WebFailure(
        title: "Privacy protection couldn’t start",
        message: "The page hasn’t been loaded. Try again to prepare Lite’s content blocker.",
        symbol: "hand.raised"
    )
}

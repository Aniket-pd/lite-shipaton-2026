import Observation
import WebKit

/// Discovery never opens a saved account's store or creates a persistent profile.
@MainActor
@Observable
final class DiscoverWebSession: NSObject, WKNavigationDelegate, WKUIDelegate {
    let page: WebPage
    let startURL: URL
    private(set) var selection: CatalogService?
    private(set) var isPreparing = false
    var notice: String?
    private(set) var pendingWindowURL: URL?
    @ObservationIgnored private var pendingWindowRequest: URLRequest?
    @ObservationIgnored private var didStart = false
    @ObservationIgnored private var isClosed = false

    init(url: URL) {
        startURL = url
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        configuration.allowsInlineMediaPlayback = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        page = WebPage(webView: WKWebView(frame: .zero, configuration: configuration))
        super.init()
        page.webView.navigationDelegate = self
        page.webView.uiDelegate = self
        page.webView.allowsBackForwardNavigationGestures = true
        page.webView.allowsLinkPreview = false
    }

    func start() async {
        guard !didStart, !isPreparing, !isClosed else { return }
        isPreparing = true
        defer { isPreparing = false }
        do {
            let rules = try await ContentBlocker.rules()
            try Task.checkCancellation()
            guard !isClosed else { return }
            page.webView.configuration.userContentController.add(rules)
            didStart = true
            load(startURL)
        } catch is CancellationError {
        } catch {
            page.failure = .protection
        }
    }

    func retry() async {
        if !didStart { await start() }
        else { load(page.retryURL ?? startURL) }
    }

    private func load(_ url: URL) {
        guard !isClosed else { return }
        page.failure = nil
        page.retryURL = url
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting"),
           ProcessInfo.processInfo.arguments.contains("--uitesting-discover-fixture") {
            let html = DiscoverCatalog.isSearchPage(url)
                ? "<html><meta name='viewport' content='width=device-width'><title>Web search</title><body><h1>Search results</h1><a href='https://example.com/'>Example website</a></body></html>"
                : BrowserTestFixture.discoverHTML
            page.webView.loadHTMLString(html, baseURL: url)
            return
        }
        #endif
        page.webView.load(URLRequest(url: url))
    }

    func close() {
        isClosed = true
        dismissWindow()
        selection = nil
        page.webView.pauseAllMediaPlayback(completionHandler: nil)
        page.tearDown()
    }

    func openWindow() {
        guard !isClosed, let request = pendingWindowRequest else { return }
        dismissWindow()
        page.webView.load(request)
    }

    func dismissWindow() {
        pendingWindowRequest = nil
        pendingWindowURL = nil
    }

    func goBack() {
        dismissWindow()
        if page.webView.canGoBack { page.webView.goBack() }
        else { page.recover() }
    }

    func recover() { dismissWindow(); page.recover() }
    func goHome() { dismissWindow(); page.clearRecovery(); load(startURL) }

    static func service(for url: URL, title: String?) -> CatalogService? {
        guard let valid = try? WebsiteURL.normalized(url.absoluteString),
              !DiscoverCatalog.isSearchPage(valid) else { return nil }
        if let entry = DiscoverCatalog.entries.first(where: { DiscoverCatalog.matches($0, url: valid) }) {
            return entry.service
        }
        // Save the site's starting point, not a search, account page, or redirect token.
        guard var origin = URLComponents(url: valid, resolvingAgainstBaseURL: false) else { return nil }
        origin.path = "/"
        origin.query = nil
        origin.fragment = nil
        guard let start = origin.url else { return nil }
        let name = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return CatalogService(id: start.absoluteString, name: String((name.isEmpty ? DiscoverCatalog.host(start) : name).prefix(40)),
                              address: start.absoluteString, symbol: "globe", color: "blue", category: "Website")
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard !isClosed, let url = action.request.url else { decisionHandler(.cancel); return }
        let topLevel = action.targetFrame?.isMainFrame ?? true
        if ContentBlocker.blocks(url) {
            if topLevel { notice = "Ad or tracker destination blocked. Your preview is still open." }
            decisionHandler(.cancel)
            return
        }
        guard url.absoluteString == "about:blank" || (try? WebsiteURL.normalized(url.absoluteString)) != nil else {
            if topLevel { notice = "This link needs another app or an insecure connection. Open the service’s HTTPS website to add it to Lite." }
            decisionHandler(.cancel)
            return
        }
        guard !action.shouldPerformDownload else {
            notice = "Add this website to Lite before downloading files."
            decisionHandler(.cancel)
            return
        }
        if action.targetFrame?.isMainFrame == true {
            if page.blocksRepeatedRedirect(to: url, type: action.navigationType) {
                notice = "Repeat redirect blocked. Tap a link to continue browsing."
                decisionHandler(.cancel)
                return
            }
            dismissWindow()
            page.prepareRecovery(for: action.request, type: action.navigationType)
            page.record(request: action.request)
            page.retryURL = url
        }
        #if DEBUG
        if topLevel, ProcessInfo.processInfo.arguments.contains("--uitesting"),
           ProcessInfo.processInfo.arguments.contains("--uitesting-discover-fixture"),
           url.host == "example.com", action.navigationType == .linkActivated {
            decisionHandler(.cancel)
            load(url)
            return
        }
        #endif
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let url = response.response.url, ContentBlocker.blocks(url) {
            decisionHandler(.cancel)
            return
        }
        if response.isForMainFrame { page.record(response: response.response) }
        guard response.canShowMIMEType else {
            notice = "This result is a download. Open a website to add it to Lite."
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        selection = nil
        page.failure = nil
        page.refresh()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !isClosed else { return }
        page.refresh()
        guard let url = webView.url, (200..<400).contains(page.httpStatusCode ?? 200) else { return }
        selection = Self.service(for: url, title: webView.title)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        page.didCommitPage()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        selection = nil
        page.failure = WebFailure(title: "This preview needs to reload", message: "Reload the page to continue exploring.", symbol: "arrow.clockwise")
    }

    private func fail(_ error: Error) {
        let nsError = error as NSError
        guard !WebNavigationPolicy.isPolicyCancellation(nsError) else { page.failure = nil; return }
        selection = nil
        page.refresh()
        page.failure = WebFailure(title: "Couldn’t load this website", message: "Check your connection and try again. You can still explore the catalog in Discover.", symbol: "wifi.exclamationmark")
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard !isClosed, action.targetFrame == nil, let url = action.request.url,
              pendingWindowRequest == nil, !ContentBlocker.blocks(url),
              (try? WebsiteURL.normalized(url.absoluteString)) != nil else { return nil }
        // Discovery does not run account popup flows; explicitly opening a link
        // creates a normal history entry instead of unexpectedly replacing the preview.
        pendingWindowRequest = action.request
        pendingWindowURL = url
        return nil
    }
}

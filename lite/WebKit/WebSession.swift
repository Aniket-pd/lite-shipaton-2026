import Observation
import SwiftData
import UIKit
import WebKit

/// One session belongs to exactly one saved Lite App. Nothing uses the default WebKit store.
@Observable
@MainActor
final class WebSession: NSObject {
    private let app: LiteApp
    let preferences: ContainerPreferences
    let dataStore: WKWebsiteDataStore
    let rootPage: WebPage
    let profileIdentifier: UUID
    let homeURL: URL
    let startURL: URL
    let proxy: ContainerProxy
    private let proxyFailure: WebFailure?
    private(set) var pages: [WebPage]
    private(set) var pendingWindow: PendingWebsiteWindow?
    private(set) var protectionNotice: String?
    private(set) var isPreparing = false
    private(set) var blockingEnabled: Bool
    private(set) var dialog: WebDialog?
    private(set) var currentDownload: WebDownload?
    var savedDownloadNotice = false
    var showsSavedDownloads = false
    var dialogInput = ""

    @ObservationIgnored private let savedStore: SavedContentStore
    @ObservationIgnored private var didStart = false
    @ObservationIgnored private var isClosed = false
    @ObservationIgnored private var compiledRules: WKContentRuleList?
    @ObservationIgnored private var pendingContentRules: WKContentRuleList?
    @ObservationIgnored private var downloads: [ObjectIdentifier: WebDownload] = [:]
    @ObservationIgnored private let onSuccessfulTopLevelURL: (URL) -> Void

    var activePage: WebPage { pages.last ?? rootPage }
    var isShowingPopup: Bool { pages.count > 1 }

    init(app: LiteApp, initialURL: URL? = nil, savedStore: SavedContentStore? = nil,
         onSuccessfulTopLevelURL: @escaping (URL) -> Void = { _ in }) {
        self.app = app
        self.savedStore = savedStore ?? .shared
        preferences = ContainerPreferences(app: app)
        profileIdentifier = app.dataStoreIdentifier
        homeURL = app.url
        startURL = initialURL.flatMap { SavedContentStore.isBookmarkURL($0) ? $0 : nil } ?? app.initialURL
        blockingEnabled = app.isBlockingEnabled
        self.onSuccessfulTopLevelURL = onSuccessfulTopLevelURL
        // Must be set BEFORE WKWebView initialization. Each app persists its own UUID.
        proxy = ContainerProxy(app: app)
        let profile: WKWebsiteDataStore
        do {
            profile = try WebProfileStore.configuredStore(for: app)
            proxyFailure = nil
        } catch {
            // An inert, empty view lets the existing error UI render without
            // creating or loading the saved profile on an invalid route.
            profile = .nonPersistent()
            proxyFailure = WebFailure(title: "Proxy setup required", message: error.localizedDescription, symbol: "network")
        }
        dataStore = profile
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = profile
        configuration.allowsInlineMediaPlayback = true
        preferences.apply(to: configuration)
        let page = WebPage(webView: WKWebView(frame: .zero, configuration: configuration))
        rootPage = page
        pages = [page]
        super.init()
        configure(page.webView)
    }

    /// No request leaves this session until protection has compiled successfully.
    func start() async {
        guard !didStart, !isPreparing, !isClosed else { return }
        if let proxyFailure { rootPage.failure = proxyFailure; return }
        isPreparing = true
        rootPage.failure = nil
        do {
            pendingContentRules = try await ContentBlocker.pendingWindowRules()
            if blockingEnabled {
                compiledRules = try await ContentBlocker.rules()
                try Task.checkCancellation()
                guard !isClosed else { isPreparing = false; return }
                applyProtection()
            }
            try Task.checkCancellation()
            guard !isClosed else { isPreparing = false; return }
            didStart = true
            app.lastOpenedAt = .now
            saveDiagnostics()
            rootPage.retryURL = startURL
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitesting"),
               ProcessInfo.processInfo.arguments.contains("--uitesting-web-fixture") {
                let html: String
                if ProcessInfo.processInfo.arguments.contains("--uitesting-underlap-fixture") {
                    html = BrowserTestFixture.underlapHTML
                } else {
                    html = ProcessInfo.processInfo.arguments.contains("--uitesting-immersive-fixture")
                        ? BrowserTestFixture.immersiveHTML : BrowserTestFixture.html
                }
                rootPage.webView.loadHTMLString(html, baseURL: homeURL)
                isPreparing = false
                return
            }
            #endif
            rootPage.webView.load(URLRequest(url: startURL))
        } catch is CancellationError {
            // The owner went away; do not start a hidden request.
        } catch {
            rootPage.failure = .protection
        }
        isPreparing = false
    }

    func retry() async {
        guard !isClosed else { return }
        if !didStart { await start(); return }
        let page = activePage
        page.failure = nil
        if let url = page.retryURL ?? page.url {
            page.webView.load(URLRequest(url: url))
        } else {
            page.webView.reload()
        }
    }

    func reload() {
        guard didStart, !isClosed else { return }
        activePage.failure = nil
        activePage.webView.reload()
    }

    func reloadAfterProtectionChange() async {
        if didStart { reload() }
        else { await start() }
    }

    func goBack() {
        dismissPendingWindow()
        activePage.failure = nil
        if activePage.webView.canGoBack { activePage.webView.goBack() }
        else if isShowingPopup { closePopup() }
        else { activePage.recover() }
    }

    func goForward() {
        dismissPendingWindow()
        activePage.failure = nil
        activePage.webView.goForward()
    }

    func goHome() {
        guard didStart else { return }
        dismissPendingWindow()
        protectionNotice = nil
        while pages.count > 1 { closePopup() }
        rootPage.clearRecovery()
        rootPage.failure = nil
        rootPage.retryURL = homeURL
        rootPage.webView.load(URLRequest(url: homeURL))
    }

    func openSavedURL(_ url: URL) {
        guard didStart, !isClosed, SavedContentStore.isBookmarkURL(url) else { return }
        dismissPendingWindow()
        cancelDialog()
        protectionNotice = nil
        activePage.clearRecovery()
        activePage.failure = nil
        activePage.retryURL = url
        activePage.webView.load(URLRequest(url: url))
    }

    func returnToPreviousPage() {
        dismissPendingWindow()
        protectionNotice = nil
        activePage.recover()
    }

    func dismissProtectionNotice() { protectionNotice = nil }

    func approvePendingWindow(alwaysAllow: Bool = false) {
        guard !isClosed, let pending = pendingWindow,
              activePage.id == pending.openerID else { dismissPendingWindow(); return }
        if blockingEnabled, ContentBlocker.blocks(pending.destination) {
            dismissPendingWindow()
            protectionNotice = "Ad window blocked. Your page is still open."
            return
        }
        if alwaysAllow, let origin = pending.sourceOrigin,
           !app.automaticWindowOrigins.contains(origin) {
            app.automaticWindowOrigins.append(origin)
            do { try app.modelContext?.save() }
            catch {
                app.automaticWindowOrigins.removeAll { $0 == origin }
                protectionNotice = "Window opened once. The website exception couldn’t be saved."
            }
        }
        cancelDialog()
        pendingWindow = nil
        pages.append(pending.page)
        applyProtection()
        pending.resolve(.allow)
    }

    func dismissPendingWindow() {
        guard let pending = pendingWindow else { return }
        pendingWindow = nil
        pending.resolve(.cancel)
        pending.page.tearDown()
    }

    /// Caller persists this choice only after preparation succeeds.
    func setBlockingEnabled(_ enabled: Bool) async -> Bool {
        guard !isClosed, !isPreparing else { return false }
        isPreparing = true
        defer { isPreparing = false }
        if enabled, compiledRules == nil {
            do { compiledRules = try await ContentBlocker.rules() }
            catch {
                showNotice("Protection couldn’t start", message: "Your privacy setting hasn’t changed. Please try again.")
                return false
            }
        }
        guard !isClosed, !Task.isCancelled else { return false }
        blockingEnabled = enabled
        applyProtection()
        return true
    }

    private func applyProtection() {
        // WebKit may share a content controller between an opener and its popups.
        var seen = Set<ObjectIdentifier>()
        for page in pages + (pendingWindow.map { [$0.page] } ?? []) {
            let controller = page.webView.configuration.userContentController
            guard seen.insert(ObjectIdentifier(controller)).inserted else { continue }
            controller.removeAllContentRuleLists()
            if blockingEnabled, let compiledRules { controller.add(compiledRules) }
            if page === pendingWindow?.page, let pendingContentRules { controller.add(pendingContentRules) }
        }
    }

    func closePopup() {
        guard pages.count > 1 else { return }
        dismissPendingWindow()
        cancelDialog()
        pages.removeLast().tearDown()
    }

    func cancelDialog() {
        let previous = dialog
        dialog = nil
        previous?.complete(with: nil)
    }

    func resolveDialog(_ request: WebDialog, accepted: Bool) {
        guard dialog?.id == request.id else { return }
        let input = dialogInput
        dialog = nil
        request.complete(with: accepted ? input : nil)
    }

    func showNotice(_ title: String, message: String) {
        present(WebDialog(kind: .notice, title: title, message: message))
    }

    /// Called before dismissal. Pending native dialogs never retain WebKit callbacks indefinitely.
    func close() {
        guard !isClosed else { return }
        isClosed = true
        dismissPendingWindow()
        cancelDialog()
        downloads.values.forEach {
            $0.download.delegate = nil
            persistDownloadFailure($0, message: "The download was interrupted. Download it again from the website.")
            $0.cancel()
        }
        downloads.removeAll()
        currentDownload = nil
        savedDownloadNotice = false
        showsSavedDownloads = false
        pages.forEach { $0.webView.pauseAllMediaPlayback(completionHandler: nil); $0.tearDown() }
        pages = [rootPage]
    }

    func pauseMedia() {
        pages.forEach { $0.webView.pauseAllMediaPlayback(completionHandler: nil) }
    }

    func cancelDownload() {
        guard let transfer = currentDownload else { return }
        downloads.removeValue(forKey: ObjectIdentifier(transfer.download))
        transfer.download.delegate = nil
        persistDownloadFailure(transfer, message: "Download cancelled. Download it again from the website.")
        transfer.cancel()
        currentDownload = nil
    }

    private func persistDownloadFailure(_ transfer: WebDownload, message: String) {
        do { try savedStore.failDownload(id: transfer.id, profileID: profileIdentifier, message: message) }
        catch {
            // The durable in-progress checkpoint will become failed on next launch.
            if !isClosed { showNotice("Download status couldn’t be saved", message: error.localizedDescription) }
        }
    }

    private func configure(_ webView: WKWebView) {
        webView.pageZoom = preferences.zoom
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        // Keep link previews from offering implicit external browsing actions.
        webView.allowsLinkPreview = false
        webView.isOpaque = true
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
    }

    private func page(for webView: WKWebView) -> WebPage? {
        pages.first { $0.webView === webView } ?? (pendingWindow?.page.webView === webView ? pendingWindow?.page : nil)
    }

    private func present(_ request: WebDialog) {
        guard !isClosed, dialog == nil else { request.complete(with: nil); return }
        dialogInput = request.defaultText
        dialog = request
    }

    private func offerExternalURL(_ url: URL) {
        present(WebDialog(kind: .external, title: "Open another app?", message: url.absoluteString) { [weak self] accepted in
            guard accepted != nil else { return }
            UIApplication.shared.open(url, options: [:]) { success in
                guard !success else { return }
                Task { @MainActor in
                    self?.showNotice("No app could open this link", message: "Install an app that supports this type of link and try again.")
                }
            }
        })
    }

    private func register(_ download: WKDownload) {
        guard !isClosed, currentDownload == nil else {
            download.cancel(nil)
            showNotice("Download in progress", message: "Finish or cancel the current download before starting another.")
            return
        }
        let transfer = WebDownload(download: download) { [weak self, weak download] progress, byteCount in
            guard let self, let download, let transfer = self.downloads[ObjectIdentifier(download)] else { return }
            self.savedStore.updateDownload(id: transfer.id, profileID: self.profileIdentifier,
                progress: progress, byteCount: byteCount)
        }
        downloads[ObjectIdentifier(download)] = transfer
        currentDownload = transfer
        download.delegate = self
    }
}

extension WebSession {
    private func saveDiagnostics() {
        // Failure to persist diagnostic metadata must not interrupt browsing.
        try? app.modelContext?.save()
    }

    private func recordError(_ error: NSError, in webView: WKWebView) {
        app.lastErrorAt = .now
        app.lastErrorDomain = error.domain
        app.lastErrorCode = error.code
        let failingURL = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL
        app.lastErrorHost = failingURL?.host ?? page(for: webView)?.retryURL?.host ?? webView.url?.host
        saveDiagnostics()
    }
}

extension WebSession: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard !isClosed, proxyFailure == nil, let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let isMainNavigation = navigationAction.targetFrame?.isMainFrame ?? true
        if blockingEnabled, ContentBlocker.blocks(url) {
            decisionHandler(.cancel)
            if isMainNavigation {
                if pendingWindow?.page.webView === webView { dismissPendingWindow() }
                protectionNotice = "Ad or tracker destination blocked. Your page is still open."
            }
            return
        }
        if let pending = pendingWindow, pending.page.webView === webView {
            guard WebNavigationPolicy.disposition(for: url) == .web,
                  isMainNavigation, !navigationAction.shouldPerformDownload else {
                decisionHandler(.cancel)
                return
            }
            pending.page.retryURL = url
            pending.page.record(request: navigationAction.request)
            pending.hold(decisionHandler, destination: url)
            return
        }
        if navigationAction.targetFrame?.isMainFrame == true {
            let backgroundDeparture = webView !== activePage.webView
                && WebNavigationPolicy.origin(of: url) != WebNavigationPolicy.origin(of: webView.url)
            let pendingDeparture = pendingWindow != nil && navigationAction.navigationType == .other
            if backgroundDeparture || pendingDeparture {
                decisionHandler(.cancel)
                protectionNotice = "A background redirect was blocked. Your original page is still open."
                return
            }
            if page(for: webView)?.blocksRepeatedRedirect(to: url, type: navigationAction.navigationType) == true {
                decisionHandler(.cancel)
                protectionNotice = "Repeat redirect blocked. Tap a link to continue browsing."
                return
            }
            if webView === activePage.webView { dismissPendingWindow() }
        }
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }
        switch WebNavigationPolicy.disposition(for: url) {
        case .web:
            // A target=_blank request belongs to its forthcoming child, not the opener.
            if navigationAction.targetFrame?.isMainFrame == true {
                page(for: webView)?.prepareRecovery(for: navigationAction.request, type: navigationAction.navigationType)
                page(for: webView)?.retryURL = url
                page(for: webView)?.record(request: navigationAction.request)
            }
            // Keep the original WebKit navigation intact. Reissuing cross-domain
            // requests breaks referrers, user activation, and some provider buttons.
            decisionHandler(.allow)
        case .external:
            decisionHandler(.cancel)
            if navigationAction.sourceFrame.isMainFrame, isMainNavigation, webView === activePage.webView {
                offerExternalURL(url)
            }
        case .blocked:
            decisionHandler(.cancel)
            if isMainNavigation, webView === activePage.webView {
                showNotice("This link can’t open in Lite", message: "Use the service’s website to continue. Lite supports web links, email, phone, messages, and maps.")
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard !isClosed else { decisionHandler(.cancel); return }
        // Server-side redirects can reach response policy without another action callback.
        if blockingEnabled, let url = navigationResponse.response.url, ContentBlocker.blocks(url) {
            decisionHandler(.cancel)
            if navigationResponse.isForMainFrame { protectionNotice = "Ad or tracker redirect blocked." }
            return
        }
        if navigationResponse.isForMainFrame { page(for: webView)?.record(response: navigationResponse.response) }
        let disposition = (navigationResponse.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition")?.lowercased() ?? ""
        if navigationResponse.isForMainFrame && (!navigationResponse.canShowMIMEType || disposition.hasPrefix("attachment")) {
            decisionHandler(.download)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        register(download)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        register(download)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard !isClosed else { return }
        page(for: webView)?.navigationStartedAt = .now
        page(for: webView)?.failure = nil
        page(for: webView)?.refresh()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard !isClosed else { return }
        page(for: webView)?.failure = nil
        page(for: webView)?.refresh()
        page(for: webView)?.didCommitPage()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !isClosed, let page = page(for: webView) else { return }
        page.refresh()
        // Only hosts and technical measurements are retained, never query strings,
        // authentication paths, page titles, cookie values or error userInfo.
        if let host = page.url?.host, ["http", "https"].contains(page.url?.scheme ?? "") {
            app.lastConnectionAt = .now
            app.lastConnectionHost = host
            app.lastConnectionSecure = page.hasSecureConnection
            app.lastHTTPStatus = page.httpStatusCode
            app.lastLoadDuration = page.navigationStartedAt.map { Date.now.timeIntervalSince($0) }
            saveDiagnostics()
        }
        if webView === rootPage.webView, page.navigationMethod == "GET",
           (page.httpStatusCode == nil || (200..<400).contains(page.httpStatusCode ?? 0)),
           let url = page.url,
           let candidate = ResumeURLPolicy.sanitizedCandidate(url, for: homeURL) {
            onSuccessfulTopLevelURL(candidate)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handle(error, in: webView)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handle(error, in: webView)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard !isClosed else { return }
        recordError(NSError(domain: WKError.errorDomain, code: WKError.webContentProcessTerminated.rawValue), in: webView)
        page(for: webView)?.failure = WebFailure(title: "This page needs to reload", message: "The web process stopped. Reload to continue with your saved session.", symbol: "arrow.clockwise")
    }

    private func handle(_ error: Error, in webView: WKWebView) {
        guard !isClosed else { return }
        let error = error as NSError
        if WebNavigationPolicy.isPolicyCancellation(error) {
            let failingURL = (error.userInfo[NSURLErrorFailingURLErrorKey] as? URL)
                ?? (error.userInfo[NSURLErrorFailingURLStringErrorKey] as? String).flatMap(URL.init(string:))
            if blockingEnabled, let failingURL, ContentBlocker.blocks(failingURL) {
                protectionNotice = "Ad or tracker redirect blocked. Your previous page is still open."
            }
            page(for: webView)?.failure = nil
            return
        }
        recordError(error, in: webView)
        let message: String
        let title: String
        if error.domain == NSURLErrorDomain, error.code == NSURLErrorNotConnectedToInternet {
            title = "You’re offline"
            message = "Check your internet connection and try again. Your Lite App is still saved."
        } else if error.domain == NSURLErrorDomain, error.code == NSURLErrorAppTransportSecurityRequiresSecureConnection {
            title = "A secure connection is required"
            message = "This website tried to use an unencrypted connection. Lite keeps Apple’s connection security enabled."
        } else if error.domain == NSURLErrorDomain, [-1200, -1201, -1202, -1203, -1204, -1205, -1206].contains(error.code) {
            title = "Connection isn’t secure"
            message = proxy.enabled
                ? "The proxy or website’s security certificate couldn’t be verified. Check your proxy settings or try again later."
                : "The website’s security certificate couldn’t be verified. Try again later."
        } else if proxy.enabled {
            title = "Couldn’t load through the proxy"
            message = "Check your proxy server and credentials in App Settings. The server or website may be unavailable. Lite has not switched this request to a direct connection."
        } else {
            title = "Couldn’t load this page"
            message = "The website may be temporarily unavailable. Check your connection and try again."
        }
        page(for: webView)?.failure = WebFailure(title: title, message: message, symbol: "wifi.exclamationmark")
    }
}

extension WebSession: WKUIDelegate {
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        guard !isClosed, webView === activePage.webView, UIApplication.shared.applicationState == .active else {
            decisionHandler(.deny)
            return
        }
        // Prompt leaves origin-specific consent and system authorization to WebKit/iOS.
        decisionHandler(preferences.mediaDecision(for: type))
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard !isClosed, webView === activePage.webView, pendingWindow == nil else { return nil }
        guard preferences.allowsPopups else {
            protectionNotice = "Website window blocked. You can allow windows in this container’s advanced preferences."
            return nil
        }
        guard pages.count < 4 else {
            protectionNotice = "Close this website window before opening another one."
            return nil
        }
        guard let url = navigationAction.request.url, WebNavigationPolicy.disposition(for: url) == .web else { return nil }
        guard !blockingEnabled || !ContentBlocker.blocks(url) else {
            protectionNotice = "Ad window blocked. Your page is still open."
            return nil
        }
        // Preserve WebKit's supplied configuration so window.opener/OAuth continues to work.
        // Explicitly attach this app's profile before initializing the child web view.
        configuration.websiteDataStore = dataStore
        preferences.apply(to: configuration)
        // Keep WebKit's supplied window configuration/opener, but isolate its
        // resource rules so quarantining this child cannot block the parent.
        let childController = WKUserContentController()
        for script in configuration.userContentController.userScripts { childController.addUserScript(script) }
        configuration.userContentController = childController
        let child = WKWebView(frame: .zero, configuration: configuration)
        configure(child)
        let page = WebPage(webView: child)
        page.retryURL = url
        let pending = PendingWebsiteWindow(page: page, opener: activePage,
            sourceURL: navigationAction.sourceFrame.request.url, destination: url)
        if let origin = pending.sourceOrigin, app.automaticWindowOrigins.contains(origin) {
            cancelDialog()
            pages.append(page)
        } else {
            protectionNotice = nil
            pendingWindow = pending
        }
        applyProtection()
        return child // WebKit, not Lite, loads the original request (including POST bodies).
    }

    func webViewDidClose(_ webView: WKWebView) {
        if pendingWindow?.page.webView === webView { dismissPendingWindow(); return }
        guard webView !== rootPage.webView, let index = pages.firstIndex(where: { $0.webView === webView }) else { return }
        dismissPendingWindow()
        cancelDialog()
        // Closing a parent also closes its descendants; never leave an orphaned stack.
        for page in pages[index...] { page.tearDown() }
        pages.removeSubrange(index...)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard webView === activePage.webView else { completionHandler(); return }
        present(WebDialog(kind: .alert, title: frame.request.url?.host ?? "Website", message: message) { _ in completionHandler() })
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard webView === activePage.webView else { completionHandler(false); return }
        present(WebDialog(kind: .confirm, title: frame.request.url?.host ?? "Website", message: message) { completionHandler($0 != nil) })
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        guard webView === activePage.webView else { completionHandler(nil); return }
        present(WebDialog(kind: .text, title: frame.request.url?.host ?? "Website", message: prompt, defaultText: defaultText ?? "", completion: completionHandler))
    }
}

extension WebSession: WKDownloadDelegate {
    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        guard !isClosed, let transfer = downloads[ObjectIdentifier(download)] else {
            completionHandler(nil)
            return
        }
        do {
            let destination = try transfer.prepare(filename: suggestedFilename, profileID: profileIdentifier)
            try savedStore.beginDownload(id: transfer.id, profileID: profileIdentifier,
                filename: transfer.filename, sourceURL: response.url)
            completionHandler(destination)
        } catch {
            transfer.fail(error)
            transfer.cleanup()
            downloads.removeValue(forKey: ObjectIdentifier(download))
            download.delegate = nil
            currentDownload = transfer
            showNotice("Download couldn’t be saved", message: error.localizedDescription)
            completionHandler(nil)
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let transfer = downloads.removeValue(forKey: ObjectIdentifier(download)),
              let url = transfer.destinationURL else { return }
        do {
            try savedStore.finishDownload(id: transfer.id, profileID: profileIdentifier, temporaryURL: url)
            transfer.cleanup()
            currentDownload = nil
            savedDownloadNotice = true
        } catch {
            transfer.fail(error)
            persistDownloadFailure(transfer, message: "The downloaded file couldn’t be saved. Download it again from the website.")
            transfer.cleanup()
            currentDownload = transfer
            showNotice("Download couldn’t be saved", message: error.localizedDescription)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let transfer = downloads.removeValue(forKey: ObjectIdentifier(download)) else { return }
        transfer.fail(error)
        persistDownloadFailure(transfer, message: transfer.errorMessage ?? "Download cancelled. Download it again from the website.")
        transfer.cleanup()
        if transfer.errorMessage == nil {
            currentDownload = nil
        } else {
            currentDownload = transfer
        }
    }
}

import SwiftUI

struct LiteBrowserContent: View {
    let app: LiteApp
    @Bindable var session: WebSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.browserWebsiteColorScheme) private var websiteColorScheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var chrome = BrowserChromeState()
    @State private var webViewFrame = CGRect.zero
    @State private var bottomControlsFrame = CGRect.zero
    @State private var savedSection: SavedSection?

    private var supportsWebContentUnderlap: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }

    private var bottomObscuredInset: CGFloat {
        guard supportsWebContentUnderlap, !webViewFrame.isEmpty, !bottomControlsFrame.isEmpty else { return 0 }
        // Measuring the overlap includes the home-indicator area exactly once and
        // follows the keyboard without treating its height as browser chrome.
        return max(0, webViewFrame.maxY - bottomControlsFrame.minY)
    }

    private var isToolbarCollapsed: Bool {
        chrome.isCollapsed && !needsExpandedControls
    }

    private func toolbarBottomSafeArea(fallback: CGFloat) -> CGFloat {
        guard supportsWebContentUnderlap, !webViewFrame.isEmpty, !bottomControlsFrame.isEmpty else { return fallback }
        // The full WebKit frame reaches the home indicator, but follows the
        // keyboard. Their difference is only the remaining bottom safe area.
        return max(0, webViewFrame.maxY - bottomControlsFrame.maxY)
    }

    private var palette: BrowserPagePalette {
        BrowserPagePalette(pageColor: session.activePage.failure == nil ? session.activePage.pageBackgroundColor : nil,
                           websiteColorScheme: websiteColorScheme)
    }

    private var needsExpandedControls: Bool {
        session.isPreparing || session.activePage.isLoading || session.activePage.failure != nil ||
        session.pendingWindow != nil || session.isShowingPopup || session.protectionNotice != nil ||
        (session.activePage.recoveryURL != nil && !session.activePage.canGoBack) ||
        session.dialog != nil || session.currentDownload != nil ||
        chrome.isKeyboardVisible || typeSize.isAccessibilitySize || voiceOverEnabled
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color(uiColor: palette.background)
                // The session retains every WKWebView, including the opener. Mount
                // only the active one: stacked transparent web views can interfere
                // with WebKit hit testing and expose hidden pages to VoiceOver.
                BrowserObscuredInsets(bottom: bottomObscuredInset) { inset in
                    LiteWebView(
                        webView: session.activePage.webView,
                        websiteColorScheme: websiteColorScheme,
                        bottomObscuredInset: inset,
                        onScrollBegan: chrome.beginGesture,
                        onScroll: { delta, distance in
                            chrome.scroll(delta: delta, distanceFromTop: distance, canCollapse: !needsExpandedControls)
                        }
                    )
                }
                    .id(session.activePage.id)
                    .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 1), value: bottomObscuredInset)
                    .onGeometryChange(for: CGRect.self) {
                        $0.frame(in: .named(BrowserContentCoordinateSpace.content))
                    } action: { webViewFrame = $0 }
                    // WebKit accounts for overlapping controls on iOS 26. Older
                    // systems retain the reserved safe-area layout below.
                    .ignoresSafeArea(.container, edges: supportsWebContentUnderlap ? .bottom : [])
                    .allowsHitTesting(session.activePage.failure == nil && !session.isPreparing)
                    .accessibilityHidden(session.activePage.failure != nil || session.isPreparing)

                if let failure = session.activePage.failure {
                    failureView(failure)
                } else if session.isPreparing {
                    ProgressView("Preparing privacy protection…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(uiColor: .systemBackground))
                }

                if session.activePage.isLoading, session.activePage.failure == nil {
                    ProgressView(value: session.activePage.progress)
                        .progressViewStyle(.linear)
                        .accessibilityLabel("Page loading")
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                BrowserWindowNotice(session: session)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if let download = session.currentDownload {
                        DownloadProgressView(download: download, cancel: session.cancelDownload)
                            .padding()
                    }
                    if session.savedDownloadNotice {
                        HStack {
                            Label("Saved to Downloads", systemImage: "checkmark.circle.fill")
                                .font(.subheadline)
                                .accessibilityIdentifier("browser.downloadSaved")
                            Spacer()
                            Button("View") { session.showsSavedDownloads = true }
                                .accessibilityIdentifier("browser.viewSavedDownload")
                            Button {
                                session.savedDownloadNotice = false
                            } label: {
                                Image(systemName: "xmark")
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("Dismiss download message")
                        }
                        .padding(.leading)
                    }
                    BrowserReturnControls(session: session)
                    BrowserToolbar(app: app, session: session,
                                   isCollapsed: isToolbarCollapsed,
                                   bottomSafeArea: toolbarBottomSafeArea(fallback: chrome.isKeyboardVisible ? 0 : geometry.safeAreaInsets.bottom),
                                   expand: chrome.expand,
                                   openSaved: { savedSection = $0 })
                }
                .onGeometryChange(for: CGRect.self) {
                    $0.frame(in: .named(BrowserContentCoordinateSpace.content))
                } action: { bottomControlsFrame = $0 }
                // The footprint, native controls, and observed WebKit obscuration
                // all follow this same interruptible transition.
                .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 1), value: isToolbarCollapsed)
            }
            .coordinateSpace(.named(BrowserContentCoordinateSpace.content))
            .background(Color(uiColor: palette.background).ignoresSafeArea())
            .onChange(of: geometry.size.width) { _, _ in chrome.expand() }
            .onChange(of: needsExpandedControls) { _, required in
                if required { chrome.expand() }
            }
            .onChange(of: session.activePage.id) { _, _ in chrome.expand() }
            .onChange(of: session.activePage.url) { _, _ in chrome.expand() }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                chrome.isKeyboardVisible = true
                chrome.expand()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                chrome.isKeyboardVisible = false
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { session.cancelDialog() }
                if phase == .background {
                    session.pauseMedia()
                    if app.isBiometricLocked { savedSection = nil }
                }
            }
            .onChange(of: session.showsSavedDownloads) { _, show in
                if show {
                    session.showsSavedDownloads = false
                    session.savedDownloadNotice = false
                    savedSection = .downloads
                }
            }
            .alert(
                session.dialog?.title ?? "Website",
                isPresented: Binding(get: { session.dialog != nil }, set: { _ in }),
                presenting: session.dialog
            ) { request in
                if request.kind == .text {
                    TextField("Response", text: $session.dialogInput)
                }
                if request.kind == .confirm || request.kind == .text || request.kind == .external {
                    Button("Cancel", role: .cancel) { session.resolveDialog(request, accepted: false) }
                }
                Button(request.kind == .external ? "Open" : "OK") {
                    session.resolveDialog(request, accepted: true)
                }
            } message: { request in
                Text(request.message)
            }
            .sheet(item: $savedSection) { section in
                ContainerSavedView(app: app, initialSection: section) { url in
                    session.openSavedURL(url)
                }
            }
        }
        .background(Color(uiColor: palette.background).ignoresSafeArea())
        .preferredColorScheme(palette.colorScheme)
        .interactiveDismissDisabled()
    }

    private func failureView(_ failure: WebFailure) -> some View {
        ContentUnavailableView {
            Label(failure.title, systemImage: failure.symbol)
        } description: {
            Text(failure.message)
        } actions: {
            Button("Try Again") { Task { await session.retry() } }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("browser.retry")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

}

nonisolated private enum BrowserContentCoordinateSpace: Hashable {
    case content
}

/// UIViewRepresentable doesn't interpolate arbitrary UIKit properties itself.
/// This SwiftUI view feeds WebKit the presented inset on every animation frame.
private struct BrowserObscuredInsets<Content: View>: View, Animatable {
    var bottom: CGFloat
    let content: (CGFloat) -> Content

    var animatableData: CGFloat {
        get { bottom }
        set { bottom = newValue }
    }

    var body: some View { content(bottom) }
}

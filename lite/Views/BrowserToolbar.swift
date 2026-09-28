import SwiftData
import SwiftUI
import WebKit

struct BrowserToolbar: View {
    let app: LiteApp
    @Bindable var session: WebSession
    let isCollapsed: Bool
    let bottomSafeArea: CGFloat
    let expand: () -> Void
    let openSaved: (SavedSection) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace
    @State private var domainWidth: CGFloat = 0
    @Environment(AppOpenCoordinator.self) private var openCoordinator
    @Query private var libraryApps: [LiteApp]
    @State private var isChangingProtection = false
    private let savedStore = SavedContentStore.shared

    private var bookmarkURL: URL? {
        guard let url = session.activePage.url,
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil, url.user == nil, url.password == nil else { return nil }
        return url
    }

    private var isPageBookmarked: Bool {
        guard let bookmarkURL else { return false }
        return savedStore.bookmarks(for: app.dataStoreIdentifier).contains { $0.url == bookmarkURL }
    }

    private var orderedLibraryApps: [LiteApp] {
        libraryApps.sorted {
            $0.sortOrder == $1.sortOrder ? $0.createdAt < $1.createdAt : $0.sortOrder < $1.sortOrder
        }
    }

    private var host: String {
        session.activePage.url?.host ?? (session.isShowingPopup ? "Website window" : app.url.host ?? "Website")
    }

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: 8) { toolbarContent }
            } else {
                toolbarContent
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .tint(.primary)
        .padding(.horizontal, typeSize.isAccessibilitySize ? 12 : 32)
        .padding(.vertical, 8)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        // Draw relative to the physical bottom edge. The smaller layout footprint
        // below releases room for the website's own fixed navigation when reading.
        .offset(y: typeSize.isAccessibilitySize ? 0 : bottomSafeArea + 4)
        .frame(height: typeSize.isAccessibilitySize ? nil : (isCollapsed ? 22 : 62), alignment: .bottom)
    }

    @ViewBuilder
    private var toolbarContent: some View {
        if typeSize.isAccessibilitySize {
            // Give large text its own row; accessibility browsing never collapses.
            HStack(alignment: .bottom, spacing: 8) {
                closeButton
                VStack(spacing: 0) {
                    BrowserWebsiteButton(appName: app.name, host: host, action: showWebsiteInformation)
                        .padding(.horizontal, 16)
                    HStack {
                        backButton
                        Spacer(minLength: 0)
                        browserMenu
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.vertical, 4)
                .modifier(BrowserGlassSurface(id: "navigation", namespace: glassNamespace, cornerRadius: 24))
            }
        } else {
            GeometryReader { geometry in
                let expandedWidth = max(148, geometry.size.width - 112)
                let labelWidth = min(max(domainWidth, 44), expandedWidth - 96)
                let compactWidth = min(expandedWidth, max(124, labelWidth * 0.76 + 36))
                let centerY: CGFloat = isCollapsed ? 52 : 24

                ZStack(alignment: .topLeading) {
                    if !isCollapsed {
                        closeButton
                            .transition(satelliteTransition(inward: 30))
                            .position(x: 24, y: 24)
                        browserMenu
                            .frame(width: 48, height: 48)
                            .modifier(BrowserGlassSurface(id: "more", namespace: glassNamespace))
                            .transition(satelliteTransition(inward: -30))
                            .position(x: geometry.size.width - 24, y: 24)
                    }

                    // One continuously resizing capsule keeps the domain centered
                    // while the surrounding actions retreat into the reading pill.
                    ZStack {
                        BrowserWebsiteButton(appName: app.name, host: host, isCollapsed: isCollapsed,
                                             labelWidth: labelWidth, textScale: isCollapsed ? 0.76 : 1,
                                             action: isCollapsed ? expand : showWebsiteInformation)
                            .frame(width: isCollapsed ? compactWidth : expandedWidth - 96)
                        if !isCollapsed {
                            HStack(spacing: 0) {
                                backButton
                                Spacer(minLength: 0)
                                reloadButton
                            }
                            .frame(width: expandedWidth - 4)
                            .transition(.modifier(active: BrowserControlVisibility(expansion: 0),
                                                  identity: BrowserControlVisibility(expansion: 1)))
                        }
                    }
                    .frame(width: isCollapsed ? compactWidth : expandedWidth,
                           height: isCollapsed ? 32 : 48)
                    .clipShape(.capsule)
                    .modifier(BrowserGlassSurface(id: "navigation", namespace: glassNamespace))
                    // Compact artwork is 32pt tall, but its touch target stays 44pt.
                    .frame(minHeight: 44)
                    .position(x: geometry.size.width / 2, y: centerY)
                }
            }
            // This drawing canvas stays stable while the outer 62→22pt footprint
            // animates, coordinating website tabs with the 28pt pill movement.
            .frame(height: 76)
            .background {
                Text(host)
                    .font(.subheadline.weight(.medium))
                    .fixedSize()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { domainWidth = $0 }
                    .hidden()
                    .accessibilityHidden(true)
            }
        }
    }

    private func satelliteTransition(inward: CGFloat) -> AnyTransition {
        if reduceMotion { return .opacity }
        return .opacity
            .combined(with: .scale(scale: 0.72))
            .combined(with: .offset(x: inward, y: 28))
    }

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.body.weight(.medium))
                .frame(width: 48, height: 48)
                .contentShape(.circle)
        }
        .modifier(BrowserGlassSurface(id: "close", namespace: glassNamespace))
        .accessibilityLabel("Done")
        .accessibilityIdentifier("browser.close")
        .accessibilityHidden(isCollapsed)
        .allowsHitTesting(!isCollapsed)
    }

    private var backButton: some View {
        Button(action: session.goBack) {
            Image(systemName: "chevron.backward")
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel("Back")
        .disabled(!session.activePage.canGoBack && !session.isShowingPopup && session.activePage.recoveryURL == nil)
        .accessibilityIdentifier("browser.back")
        .accessibilityHidden(isCollapsed)
        .allowsHitTesting(!isCollapsed)
    }

    private var reloadButton: some View {
        Button(action: reload) {
            Image(systemName: "arrow.clockwise")
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel("Reload")
        .accessibilityIdentifier("browser.reload")
        .accessibilityHidden(isCollapsed)
        .allowsHitTesting(!isCollapsed)
        .disabled(session.isPreparing)
    }

    private func reload() {
        if session.activePage.failure == nil {
            session.reload()
        } else {
            Task { await session.retry() }
        }
    }

    private var browserMenu: some View {
        Menu {
            Text(app.name)

            Button("Forward", systemImage: "chevron.forward") { session.goForward() }
                .disabled(!session.activePage.canGoForward)
            if session.activePage.recoveryURL != nil {
                Button("Return to previous page", systemImage: "arrow.uturn.backward", action: session.returnToPreviousPage)
                    .accessibilityIdentifier("browser.recoverFromMenu")
            }
            Button("Reload", systemImage: "arrow.clockwise", action: reload)
            .disabled(session.isPreparing)
            Button("Go to Start Page", systemImage: "house") { session.goHome() }
                .accessibilityIdentifier("browser.home")
                .disabled(session.isPreparing)
            ShareLink(item: session.activePage.url ?? app.url) {
                Label("Share Page", systemImage: "square.and.arrow.up")
            }
            Section {
                Button(isPageBookmarked ? "Page Bookmarked" : "Bookmark Page",
                       systemImage: isPageBookmarked ? "bookmark.fill" : "bookmark",
                       action: bookmarkPage)
                    .disabled(bookmarkURL == nil || isPageBookmarked)
                    .accessibilityIdentifier("browser.bookmarkPage")
                Button("Bookmarks", systemImage: "book") { openSaved(.bookmarks) }
                    .accessibilityIdentifier("browser.savedBookmarks")
                Button("Downloads", systemImage: "arrow.down.circle") { openSaved(.downloads) }
                    .accessibilityIdentifier("browser.savedDownloads")
            }
            Section {
                Menu("Switch Lite App", systemImage: "arrow.left.arrow.right") {
                    ForEach(orderedLibraryApps) { candidate in
                        Button {
                            guard candidate.id != app.id else { return }
                            session.close()
                            openCoordinator.open(candidate.id)
                        } label: {
                            Label(candidate.name, systemImage: candidate.id == app.id ? "checkmark" : candidate.iconSymbol)
                        }
                        .accessibilityIdentifier("browser.switch.\(candidate.name)")
                        .disabled(candidate.id == app.id)
                    }
                }
                Button("Create Another Account", systemImage: "person.crop.circle.badge.plus", action: createAnotherAccount)
            }
            Section {
                Toggle(isOn: Binding(
                    get: { app.isBlockingEnabled },
                    set: { enabled in Task { await changeProtection(to: enabled) } }
                )) {
                    Label("Ad & Tracker Blocking", systemImage: "hand.raised")
                }
                .accessibilityIdentifier("browser.protection")
                .disabled(isChangingProtection || session.isPreparing)
                Button("About Protection", systemImage: "info.circle") {
                    session.showNotice("Ad & tracker protection", message: "Blocks \(ContentBlocker.domains.count.formatted()) known ad, tracking and other unwanted domains, including popup and redirect destinations, and hides common ad containers.\n\nHaGeZi PRO mini • \(ContentBlocker.listVersion)\n\nLists are bundled with Lite updates. Some ads served by the website itself can remain. Turn blocking off for this container if a website doesn’t work. Window approval stays on.")
                }
            }

        } label: {
            Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("More")
        .accessibilityIdentifier("browser.more")
        .accessibilityHidden(isCollapsed)
        .allowsHitTesting(!isCollapsed)
    }

    private func close() {
        session.close()
        dismiss()
    }

    private func bookmarkPage() {
        guard let bookmarkURL else { return }
        do {
            try savedStore.addBookmark(profileID: app.dataStoreIdentifier,
                                       title: session.activePage.webView.title ?? bookmarkURL.host ?? "Saved Page",
                                       url: bookmarkURL)
        } catch {
            session.showNotice("Couldn’t save bookmark", message: error.localizedDescription)
        }
    }

    private func showWebsiteInformation() {
        let page = session.activePage
        let connection: String
        if page.failure != nil || page.isLoading || page.url == nil {
            connection = "Connection hasn’t been verified"
        } else {
            connection = page.hasSecureConnection ? "Encrypted connection" : "Connection not encrypted"
        }
        session.showNotice("Website", message: "\(app.name)\n\(connection)\n\n\((page.url ?? app.url).absoluteString)")
    }

    private func changeProtection(to enabled: Bool) async {
        guard !isChangingProtection else { return }
        isChangingProtection = true
        defer { isChangingProtection = false }
        let previous = app.isBlockingEnabled
        guard await session.setBlockingEnabled(enabled) else { return }
        app.isBlockingEnabled = enabled
        do {
            try modelContext.save()
            await session.reloadAfterProtectionChange()
        } catch {
            app.isBlockingEnabled = previous
            _ = await session.setBlockingEnabled(previous)
            session.showNotice("Couldn’t save your setting", message: "Your previous privacy setting is still in use. Please try again.")
        }
    }

    private func createAnotherAccount() {
        let copy = app.duplicate(accountName: app.nextAccountName(in: libraryApps))
        copy.sortOrder = (orderedLibraryApps.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(copy)
        do {
            try modelContext.save()
            session.close()
            openCoordinator.open(copy.id)
        } catch {
            modelContext.rollback()
            session.showNotice("Couldn’t create another account", message: "Your current account is unchanged. Please try again.")
        }
    }
}

/// One surface per functional group, with native glass on iOS 26 and a readable
/// material fallback on earlier systems and when transparency is reduced.
private struct BrowserGlassSurface: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    var cornerRadius: CGFloat = 26
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content
                .background(.background, in: shape)
                .overlay { shape.strokeBorder(.primary.opacity(contrast == .increased ? 0.6 : 0.15)) }
        } else if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: shape)
                .glassEffectID(id, in: namespace)
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }
}

/// Derive the fade from the same interruptible spring as the capsule. Controls
/// disappear early on collapse and return only once expansion has made room.
private struct BrowserControlVisibility: AnimatableModifier {
    var expansion: CGFloat

    var animatableData: CGFloat {
        get { expansion }
        set { expansion = newValue }
    }

    func body(content: Content) -> some View {
        let visibility = min(1, max(0, (expansion - 0.65) / 0.35))
        content
            .opacity(visibility)
    }
}

import SwiftUI
import WebKit

struct DiscoverWebView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var session: DiscoverWebSession
    @State private var showsInformation = false
    @State private var pendingAddition: CatalogService?
    let add: (CatalogService) -> Void
    let close: () -> Void

    init(startURL: URL, add: @escaping (CatalogService) -> Void, close: @escaping () -> Void) {
        _session = State(initialValue: DiscoverWebSession(url: startURL))
        self.add = add
        self.close = close
    }

    private var host: String { DiscoverCatalog.host(session.page.url ?? session.startURL) }
    private var isLoading: Bool { session.isPreparing || session.page.isLoading }
    private var canAdd: Bool { session.selection != nil && !isLoading && session.page.failure == nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let destination = session.pendingWindowURL { windowApproval(destination) }
            website
        }
        .background(Color(.systemBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) { toolbar }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsInformation, onDismiss: completeAddition) {
            DiscoverWebsiteInformation(session: session) { selection in
                // Finish dismissing this sheet before the parent opens creation.
                pendingAddition = selection
            }
            .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task { await session.start() }
        .onDisappear { session.close() }
        .alert("Website preview", isPresented: Binding(get: { session.notice != nil }, set: { if !$0 { session.notice = nil } })) {
            Button("OK") { session.notice = nil }
        } message: { Text(session.notice ?? "") }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: close) {
                DiscoverPreviewControlLabel(symbol: "xmark")
                    .modifier(DiscoverPreviewGlass(shape: Circle(), interactive: true))
            }
            .accessibilityLabel("Close preview")
            .accessibilityIdentifier("discover.dismiss")

            Button { showsInformation = true } label: {
                VStack(spacing: 2) {
                    Text(host)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                        .truncationMode(.middle)
                    Text(DiscoverCatalog.isSearchPage(session.page.url ?? session.startURL) ? "Web search" : "Preview")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
            }
            .accessibilityLabel("\(host), website information")
            .accessibilityHint("Shows details about this temporary preview session")
            .accessibilityIdentifier("discover.web.information")

            Button(action: reload) {
                DiscoverPreviewControlLabel(symbol: "arrow.clockwise")
                    .modifier(DiscoverPreviewGlass(shape: Circle(), interactive: true))
            }
            .disabled(session.isPreparing)
            .accessibilityLabel("Reload website")
            .accessibilityIdentifier("discover.web.reload")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background { chromeBackground }
        .overlay(alignment: .bottom) {
            // An overlay keeps the website's position stable as loading changes.
            if isLoading {
                ProgressView(value: session.isPreparing ? nil : session.page.progress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                    .accessibilityLabel(session.isPreparing ? "Preparing preview" : "Loading website")
            }
        }
    }

    private var website: some View {
        ZStack {
            LiteWebView(webView: session.page.webView)
            if let failure = session.page.failure {
                ContentUnavailableView {
                    Label(failure.title, systemImage: failure.symbol)
                } description: {
                    Text(failure.message)
                } actions: {
                    Button("Try again", action: reload)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("discover.web.retry")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
    }

    private var toolbar: some View {
        VStack(spacing: 0) {
            if typeSize.isAccessibilitySize {
                navigationControls.frame(maxWidth: .infinity, alignment: .leading)
                addButton.frame(maxWidth: .infinity).padding(.top, 8)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        navigationControls
                        Spacer(minLength: 0)
                        addButton
                    }
                    VStack(spacing: 8) {
                        navigationControls.frame(maxWidth: .infinity, alignment: .leading)
                        addButton
                    }
                }
            }
            Button { showsInformation = true } label: {
                Label("Temporary session", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Preview sign-ins won’t carry over to your Lite App")
            .accessibilityIdentifier("discover.web.sessionInfo")
        }
        .padding(.horizontal, 16).padding(.top, 10)
        .background { chromeBackground.ignoresSafeArea(edges: .bottom) }
    }

    private var navigationControls: some View {
        HStack(spacing: 4) {
            Button { session.goBack() } label: {
                DiscoverPreviewControlLabel(symbol: "chevron.backward")
            }
            .disabled(!session.page.canGoBack && session.page.recoveryURL == nil)
            .accessibilityLabel("Previous webpage")
            .accessibilityIdentifier("discover.web.back")
            Button { session.page.webView.goForward() } label: {
                DiscoverPreviewControlLabel(symbol: "chevron.forward")
            }
            .disabled(!session.page.canGoForward)
            .accessibilityLabel("Next webpage")
            .accessibilityIdentifier("discover.web.forward")
            Menu {
                if session.page.recoveryURL != nil {
                    Button("Return to previous page", systemImage: "arrow.uturn.backward") { session.recover() }
                        .accessibilityIdentifier("discover.web.recover")
                }
                Button("Start page", systemImage: "house") { session.goHome() }
                    .disabled(session.isPreparing)
                    .accessibilityIdentifier("discover.web.home")
                Button("Reload", systemImage: "arrow.clockwise", action: reload)
                    .disabled(session.isPreparing)
                Button("Website information", systemImage: "info.circle") { showsInformation = true }
            } label: {
                DiscoverPreviewControlLabel(symbol: "ellipsis")
            }
            .accessibilityLabel("More options")
            .accessibilityIdentifier("discover.web.more")
        }
        .font(.body.weight(.medium))
        .buttonStyle(.plain)
        .tint(.primary)
        .foregroundStyle(.primary)
        .padding(3)
        .modifier(DiscoverPreviewGlass(shape: Capsule()))
        .fixedSize(horizontal: true, vertical: false)
    }

    private var addButton: some View {
        Button {
            if canAdd, let selection = session.selection { add(selection) }
        } label: {
            Text("Add to Lite")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, minHeight: 32)
        }
        .modifier(DiscoverPreviewPrimaryAction())
        .tint(.blue)
        .disabled(!canAdd)
        .accessibilityHint(canAdd ? "Choose a name and create a separate sign-in space" : "Open a website and wait for it to load before adding it")
        .accessibilityIdentifier("discover.web.add")
    }

    @ViewBuilder private var chromeBackground: some View {
        if #available(iOS 26.0, *) { Color(.systemBackground) }
        else if reduceTransparency { Color(.systemBackground) }
        else { Rectangle().fill(.regularMaterial) }
    }

    private func windowApproval(_ destination: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open \(destination.host ?? "website")?").font(.subheadline.weight(.semibold))
            ViewThatFits(in: .horizontal) {
                HStack { windowActions }
                VStack(alignment: .leading) { windowActions }
            }
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading).background(.regularMaterial)
    }

    @ViewBuilder private var windowActions: some View {
        Button("Open") { session.openWindow() }.buttonStyle(.borderedProminent)
            .accessibilityIdentifier("discover.web.openWindow")
        Button("Dismiss") { session.dismissWindow() }.buttonStyle(.bordered)
            .accessibilityIdentifier("discover.web.dismissWindow")
    }

    private func reload() {
        if session.page.failure != nil || session.page.url == nil {
            Task { await session.retry() }
        } else {
            session.page.webView.reload()
        }
    }

    private func completeAddition() {
        guard let selection = pendingAddition else { return }
        pendingAddition = nil
        add(selection)
    }
}

private struct DiscoverWebsiteInformation: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    let session: DiscoverWebSession
    let add: (CatalogService) -> Void

    private var canAdd: Bool {
        session.selection != nil && !session.isPreparing && !session.page.isLoading && session.page.failure == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Website information").font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button { dismiss() } label: {
                    DiscoverPreviewControlLabel(symbol: "xmark")
                        .modifier(DiscoverPreviewGlass(shape: Circle(), interactive: true))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close website information")
                .accessibilityIdentifier("discover.web.info.close")
            }
            .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    informationRow("Website", value: DiscoverCatalog.host(session.page.url ?? session.startURL))
                    Divider()
                    informationRow("Session", value: "Temporary")
                    Divider()
                    Text("Preview sign-ins won’t carry over. Add this website to Lite for a separate, saved sign-in space.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 20)
                    if !canAdd {
                        Text("Open a website and wait for it to load before adding it.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            Button {
                guard canAdd, let selection = session.selection else { return }
                add(selection)
                dismiss()
            } label: {
                Text("Add to Lite").font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .padding(.vertical, 6)
            }
            .modifier(DiscoverPreviewPrimaryAction())
            .tint(.blue).disabled(!canAdd)
            .accessibilityIdentifier("discover.web.info.add")
            .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 16)
        }
        .background {
            if #available(iOS 26.0, *) { Color.clear }
            else { Color(.systemBackground) }
        }
    }

    private func informationRow(_ title: String, value: String) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 16))
        return layout {
            Text(title)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text(value).foregroundStyle(.secondary)
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
                .textSelection(.enabled)
        }
        .font(.subheadline)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }
}

/// Keep symbols inside their touch targets without limiting readable text sizes.
private struct DiscoverPreviewControlLabel: View {
    @ScaledMetric(relativeTo: .body) private var symbolSize = 18.0
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: min(symbolSize, 24), weight: .medium))
            .frame(width: 44, height: 44)
            .contentShape(.rect)
    }
}

/// Keep glass on controls; the web page and its surrounding chrome stay readable.
private struct DiscoverPreviewGlass<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S
    var interactive = false

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            content.background(Color(.tertiarySystemFill), in: shape)
        }
    }
}

private struct DiscoverPreviewPrimaryAction: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content.buttonStyle(.glassProminent).buttonBorderShape(.capsule)
        } else {
            content.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
        }
    }
}

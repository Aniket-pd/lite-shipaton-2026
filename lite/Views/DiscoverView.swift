import SwiftUI

struct DiscoverView: View {
    let apps: [LiteApp]
    let addService: (CatalogService) -> Void
    let openApp: (LiteApp) -> Void
    let atmosphereEpoch: TimeInterval
    let isAtmosphereActive: Bool
    var allowsAtmosphere = true
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage("lite.atmosphericBackground") private var atmosphericBackground = true
    @State private var query = ""
    @State private var category: DiscoverCategory = .all
    @State private var sheet: DiscoverSheet?
    @State private var pendingCreation: CatalogService?
    @State private var pendingOpen: LiteApp?
    @FocusState private var searchFocused: Bool

    private var term: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var showsAtmosphere: Bool { allowsAtmosphere && atmosphericBackground && colorScheme == .dark }
    private var isAddress: Bool { DiscoverCatalog.looksLikeAddress(term) }
    private var directURL: URL? { isAddress ? try? WebsiteURL.normalized(term) : nil }
    private var entries: [DiscoverEntry] { DiscoverCatalog.search(term, category: category) }
    private var savedMatches: [LiteApp] {
        guard !term.isEmpty, !isAddress else { return [] }
        return apps.filter { app in
            let matchesText = app.name.localizedStandardContains(term) || DiscoverCatalog.host(app.url).localizedStandardContains(term)
            let matchesCategory = category == .all || DiscoverCatalog.entries.contains {
                $0.category == category && DiscoverCatalog.matches($0, url: app.url)
            }
            return matchesText && matchesCategory
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    searchField.padding(.horizontal, 16)
                    if !isAddress { categories }
                    if isAddress {
                        addressResults.padding(.horizontal, 20)
                    } else if !term.isEmpty {
                        searchResults.padding(.horizontal, 20)
                    } else {
                        browseContent.padding(.horizontal, 20)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { discoveryBackground }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                if searchFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { searchFocused = false }
                            .accessibilityIdentifier("discover.dismissKeyboard")
                    }
                }
            }
            .sheet(item: $sheet, onDismiss: completeSelection) { destination in
                NavigationStack {
                    Group {
                        switch destination {
                        case .details(let entry):
                            DiscoverDetailsView(entry: entry, savedApps: savedApps(for: entry), add: queueCreation, open: queueOpen)
                        case .help:
                            discoveryHelp
                        case .web(let url):
                            DiscoverWebView(startURL: url, add: queueCreation, close: { sheet = nil })
                        }
                    }
                    .navigationDestination(for: URL.self) { url in
                        DiscoverWebView(startURL: url, add: queueCreation, close: { sheet = nil })
                    }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { sheet = nil }.accessibilityIdentifier("discover.dismiss")
                        }
                    }
                }
                .presentationDragIndicator(.visible)
            }
            .accessibilityIdentifier("discover.screen")
        }
    }

    @ViewBuilder
    private var discoveryBackground: some View {
        if showsAtmosphere {
            AtmosphereBackground(isActive: isAtmosphereActive, animationEpoch: atmosphereEpoch)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            Color(.systemGroupedBackground).ignoresSafeArea()
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search web or paste a link", text: $query)
                .textFieldStyle(.plain)
                .padding(.vertical, 15)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(isAddress ? .go : .search)
                .focused($searchFocused)
                .onSubmit(submitSearch)
                .accessibilityLabel("Search web or paste a link")
                .accessibilityIdentifier("discover.search")
            HStack(spacing: 0) {
                if !query.isEmpty {
                    Button("Clear search", systemImage: "xmark.circle.fill") { query = "" }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("discover.clearSearch")
                    if !term.isEmpty && (!isAddress || directURL != nil) {
                        Button(isAddress ? "Open website" : "Search the web", systemImage: "arrow.right", action: submitSearch)
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier(isAddress ? "discover.openWebsite" : "discover.searchWeb")
                    }

                }
            }
            .padding(.trailing, -10)
        }
        .font(.subheadline)
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .fixedSize(horizontal: false, vertical: true)
        .modifier(SavedGlassSurface(shape: Capsule()))
    }

    private var discoverySurface: Color {
        showsAtmosphere && !reduceTransparency ? Color.white.opacity(0.07) : Color(.secondarySystemGroupedBackground)
    }

    private var categories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            if #available(iOS 26.0, *), !reduceTransparency {
                GlassEffectContainer(spacing: 4) { categoryControls }
            } else {
                categoryControls
            }
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .mask {
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 16)
                Rectangle().fill(.black)
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 16)
            }
            .allowsHitTesting(false)
        }
    }

    private var categoryControls: some View {
        HStack(spacing: 8) {
            ForEach(DiscoverCategory.allCases) { item in
                Button { category = item } label: {
                    Text(item.rawValue)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 6)
                        .frame(minHeight: 32)
                }
                .modifier(DiscoverGlassButton(prominent: category == item,
                                              tint: category == item ? .blue : .primary))
                .accessibilityAddTraits(category == item ? .isSelected : [])
                .accessibilityIdentifier("discover.category.\(item.rawValue)")
            }
        }
        .padding(.vertical, 4)
    }

    private var browseContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("All sites")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                serviceList(entries)
            }
            Button { sheet = .help } label: {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle").font(.title3)
                    Text("How Lite Apps work").font(.subheadline)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("discover.help")
        }
    }

    private var discoveryHelp: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label("Find a website", systemImage: "magnifyingglass").font(.headline)
                Text("Search the web or paste an HTTPS website address. Searches go to DuckDuckGo only when you submit them.")
                Label("Preview and add", systemImage: "plus.circle").font(.headline)
                Text("Open a website, then choose Add to Lite. You can review its name, address, and icon before saving it to your Library.")
                Label("Your own sign-in space", systemImage: "person.crop.circle").font(.headline)
                Text("Each Lite App has a separate sign-in space. Preview sign-ins do not carry over; sign in after adding the website.")
                Text("Website features and sign-in may vary.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .navigationTitle("How Lite Apps work")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !savedMatches.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeading("In your library", count: savedMatches.count)
                    VStack(spacing: 0) {
                        ForEach(savedMatches) { app in
                            HStack(spacing: 12) {
                                AppIconView(data: app.iconData, websiteURL: app.url, symbol: app.iconSymbol, size: 44)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(app.name).font(.headline)
                                    Text(DiscoverCatalog.host(app.url)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                Button { searchFocused = false; openApp(app) } label: {
                                    Text("Open")
                                        .frame(minWidth: 44, minHeight: 44)
                                        .contentShape(.rect)
                                }
                                    .buttonStyle(.plain).foregroundStyle(.blue)
                                    .accessibilityLabel("Open \(app.name)")
                                    .accessibilityIdentifier("discover.saved.\(app.name)")
                            }.padding(16)
                        }
                    }
                    .background(discoverySurface, in: .rect(cornerRadius: 20))
                }
            }
            if !entries.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeading("From the catalog", count: entries.count)
                    serviceList(entries)
                }
            }
            webSearchCard
            if entries.isEmpty && category != .all {
                Button("Search all categories") { category = .all }
            }
        }
    }

    private var webSearchCard: some View {
        Button(action: submitSearch) {
            HStack(spacing: 12) {
                Image("DuckDuckGo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search in DuckDuckGo")
                        .font(.headline)
                    Text(term)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(discoverySurface, in: .rect(cornerRadius: 20))
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("discover.duckDuckGo")
    }

    @ViewBuilder private var addressResults: some View {
        if let directURL {
            VStack(alignment: .leading, spacing: 14) {
                Text("Add this website").font(.title2.bold())
                serviceList([.website(directURL)])
                Text("Preview the website, then give it a place in your library.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        } else {
            ContentUnavailableView {
                Label("Check this address", systemImage: "link")
            } description: {
                Text(addressError)
            }
        }
    }

    private var addressError: String {
        do { _ = try WebsiteURL.normalized(term); return "Enter a valid HTTPS website." }
        catch { return error.localizedDescription }
    }

    private func sectionHeading(_ title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title2.bold())
            Spacer()
            Text(count.formatted()).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func serviceList(_ items: [DiscoverEntry]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(items) { entry in
                DiscoverServiceRow(entry: entry, savedApp: savedApps(for: entry).first,
                    details: { searchFocused = false; sheet = .details(entry) },
                    add: { searchFocused = false; addService(entry.service) },
                    open: { app in searchFocused = false; openApp(app) })
                if entry.id != items.last?.id { Divider().padding(.leading, 76) }
            }
        }
        .background(discoverySurface, in: .rect(cornerRadius: 20))
    }

    private func savedApps(for entry: DiscoverEntry) -> [LiteApp] {
        apps.filter { DiscoverCatalog.matches(entry, url: $0.url) }
    }

    private func submitSearch() {
        guard !term.isEmpty else { return }
        searchFocused = false
        if isAddress {
            if let directURL { sheet = .details(.website(directURL)) }
        } else {
            sheet = .web(DiscoverCatalog.searchURL(term))
        }
    }

    private func queueCreation(_ service: CatalogService) {
        pendingCreation = service
        sheet = nil
    }

    private func queueOpen(_ app: LiteApp) {
        pendingOpen = app
        sheet = nil
    }

    private func completeSelection() {
        if let service = pendingCreation {
            pendingCreation = nil
            addService(service)
        } else if let app = pendingOpen {
            pendingOpen = nil
            openApp(app)
        }
    }
}

private struct DiscoverGlassButton: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var prominent = false
    var tint: Color = .blue

    func body(content: Content) -> some View {
        styled(content)
            .tint(tint)
            .buttonBorderShape(.capsule)
            .frame(minHeight: 44)
    }

    @ViewBuilder private func styled(_ content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            if prominent { content.buttonStyle(.glassProminent) }
            else { content.buttonStyle(.glass) }
        } else {
            if prominent { content.buttonStyle(.borderedProminent) }
            else { content.buttonStyle(.bordered) }
        }
    }
}

private enum DiscoverSheet: Identifiable {
    case details(DiscoverEntry), web(URL), help
    var id: String {
        switch self {
        case .details(let entry): "details-\(entry.id)"
        case .web(let url): "web-\(url.absoluteString)"
        case .help: "help"
        }
    }
}

struct DiscoverIcon: View {
    let entry: DiscoverEntry
    var size: CGFloat = 48
    @State private var discoveredData: Data?
    @State private var isLoading = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppIconView(data: CatalogIcon.data(for: entry.url) ?? discoveredData, websiteURL: entry.url,
                        symbol: entry.service.symbol, size: size)
            if isLoading {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    ProgressView().controlSize(.mini).tint(.secondary)
                }
                .frame(width: max(18, size * 0.36), height: max(18, size * 0.36))
                .overlay { Circle().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5) }
                .offset(x: 2, y: 2)
                .transition(.scale(scale: 0.75).combined(with: .opacity))
                .accessibilityHidden(true)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isLoading)
        .task(id: entry.id) {
            guard CatalogIcon.data(for: entry.url) == nil else { return }
            isLoading = true
            defer { isLoading = false }
            let data = await DiscoverIconRepository.shared.data(for: entry.url)
            guard !Task.isCancelled else { return }
            discoveredData = data
        }
    }
}

private actor DiscoverIconRepository {
    static let shared = DiscoverIconRepository()
    private var tasks: [String: Task<Data?, Never>] = [:]

    func data(for url: URL) async -> Data? {
        let key = "\(url.scheme?.lowercased() ?? "https")://\(url.host?.lowercased() ?? url.absoluteString):\(url.port ?? 443)"
        if let task = tasks[key] { return await task.value }
        let task = Task { await FaviconService().fetch(for: url) }
        tasks[key] = task
        return await task.value
    }
}

private struct DiscoverServiceRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let entry: DiscoverEntry
    let savedApp: LiteApp?
    let details: () -> Void
    let add: () -> Void
    let open: (LiteApp) -> Void

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) { information; action }
            } else {
                HStack(spacing: 12) { information; action }
            }
        }
        .padding(16)
    }

    private var information: some View {
        Button(action: details) {
            HStack(spacing: 12) {
                DiscoverIcon(entry: entry, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.service.name).font(.headline).foregroundStyle(.primary)
                    Text(entry.domain).font(.subheadline).foregroundStyle(.secondary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.service.name), \(entry.service.category), \(entry.domain)")
        .accessibilityHint("Shows details and a website preview")
        .accessibilityIdentifier("discover.service.\(entry.id)")
    }

    private var action: some View {
        Button {
            if let savedApp { open(savedApp) } else { add() }
        } label: {
            Text(savedApp == nil ? "+ Add" : "Open")
                .font(.subheadline.weight(.semibold))
                .fixedSize()
                .padding(.horizontal, 4)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain).foregroundStyle(.blue)
        .accessibilityLabel(savedApp == nil ? "Add \(entry.service.name)" : "Open \(savedApp!.name)")
        .accessibilityIdentifier("discover.add.\(entry.id)")
    }
}

private struct DiscoverDetailsView: View {
    let entry: DiscoverEntry
    let savedApps: [LiteApp]
    let add: (CatalogService) -> Void
    let open: (LiteApp) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 14) {
                    DiscoverIcon(entry: entry, size: 80)
                    Text(entry.service.name).font(.title.bold()).multilineTextAlignment(.center)
                    Text(entry.domain).font(.subheadline).foregroundStyle(.secondary)
                    Text(entry.service.category).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                NavigationLink(value: entry.url) {
                    Label("Preview website", systemImage: "safari")
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.bordered).buttonBorderShape(.roundedRectangle(radius: 16))
                .accessibilityIdentifier("discover.preview")
                if !savedApps.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("In your library").font(.headline)
                        ForEach(savedApps) { app in
                            Button { open(app) } label: {
                                HStack {
                                    Text(app.name).foregroundStyle(.primary)
                                    Spacer()
                                    Text("Open").fontWeight(.semibold)
                                }.padding(.vertical, 10)
                            }.accessibilityIdentifier("discover.detail.open.\(app.name)")
                        }
                    }
                }
                Button { add(entry.service) } label: {
                    Label(savedApps.isEmpty ? "Add to Lite" : "Add another account", systemImage: "plus")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 16))
                .accessibilityIdentifier("discover.detail.add")
                VStack(alignment: .leading, spacing: 16) {
                    Label("Your own sign-in space", systemImage: "person.crop.circle")
                        .font(.subheadline.weight(.medium))
                    Text("Each Lite App gets a separate account space. Give it a name and make it yours on the next screen.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Divider()
                    Text("Website features and sign-in may vary. Preview the site before adding it.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(18)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
            }.padding(24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("About this app")
        .navigationBarTitleDisplayMode(.inline)
    }
}

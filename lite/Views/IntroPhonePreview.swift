import SwiftUI

/// The real app components rendered on a fixed phone canvas. Sample models are
/// never inserted into a store; the entire preview is decorative and read-only.
struct IntroPhonePreview: View {
    let page: IntroPage
    let reduceMotion: Bool
    @State private var examples = IntroExamples()

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                pages
                    .frame(width: 390, height: 795)
                    .clipShape(.rect(cornerRadius: 54))
                Capsule().fill(.black).frame(width: 114, height: 33).padding(.top, 15)
                VStack {
                    Spacer()
                    Capsule().fill(.white.opacity(0.85)).frame(width: 128, height: 6).padding(.bottom, 13)
                }
                .frame(height: 795)
            }
            .frame(width: 390, height: 795)
            .overlay {
                RoundedRectangle(cornerRadius: 54, style: .continuous)
                    .strokeBorder(.white.opacity(0.5), lineWidth: 1.5)
                    .padding(-6)
                RoundedRectangle(cornerRadius: 58, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 4.5)
                    .padding(-10)
            }
            .scaleEffect(geometry.size.width / 390, anchor: .topLeading)
        }
        .environment(\.dynamicTypeSize, .medium)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    @ViewBuilder private var pages: some View {
        if reduceMotion {
            IntroPreviewPage(page: page, examples: examples)
        } else {
            HStack(spacing: 18) {
                ForEach(IntroPage.allCases) { item in
                    IntroPreviewPage(page: item, examples: examples)
                        .frame(width: 390, height: 795)
                        .id(item)
                }
            }
            .offset(x: -CGFloat(page.position) * 408)
            .frame(width: 390, alignment: .leading)
            .clipped()
        }
    }
}

private struct IntroExamples {
    let groups: [LiteAppGroup]
    let profiles: [LiteApp]

    init() {
        let apps = StarterLibrary.services.enumerated().map { index, service in
            let url = URL(string: service.address)!
            let app = LiteApp(name: service.name, url: url, iconData: CatalogIcon.data(for: url),
                              iconSymbol: service.symbol, iconColor: service.color)
            app.sortOrder = index
            return app
        }
        groups = LiteAppGrouping.groups(from: apps)
        let gmail = apps.first { $0.name == "Gmail" }!
        profiles = ["Personal", "Work"].map { name in
            LiteApp(name: name, url: gmail.url, iconData: gmail.iconData,
                    iconSymbol: gmail.iconSymbol, iconColor: name == "Work" ? "orange" : "blue")
        }

    }
}

private struct IntroPreviewPage: View {
    let page: IntroPage
    let examples: IntroExamples
    private var appBackground: some View { Color(.systemBackground) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("9:41").font(.caption.weight(.semibold))
                Spacer()
                Image(systemName: "wifi")
                Image(systemName: "battery.100percent")
            }
            .font(.caption)
            .padding(.horizontal, 30)
            .frame(height: 54)
            Group {
                switch page {
                case .library: library
                case .webpage: discover
                case .accounts: accounts
                case .privacy: privacy
                case .protection: protection
                }
            }
        }
        .frame(width: 390, height: 795)
        .background { appBackground }
        .foregroundStyle(.primary)
        .tint(.blue)
    }

    private var library: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3), spacing: 24) {
                        ForEach(examples.groups) { group in
                            LibraryWebsiteTile(group: group, showsName: true)
                        }
                    }
                    .padding(24)
                }
                .background { appBackground }
                .toolbarBackground(.hidden, for: .navigationBar)
                .navigationTitle("My Lite Apps")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Library", systemImage: "square.grid.2x2") }
            Color.clear.tabItem { Label("Groups", systemImage: "rectangle.3.group") }
            Color.clear.tabItem { Label("Saved", systemImage: "bookmark") }
            Color.clear.tabItem { Label("Discover", systemImage: "safari") }
        }
    }

    private var discover: some View {
        TabView(selection: .constant("discover")) {
            Color.clear
                .tabItem { Label("Library", systemImage: "square.grid.2x2") }
                .tag("library")
            Color.clear
                .tabItem { Label("Groups", systemImage: "rectangle.3.group") }
                .tag("groups")
            Color.clear
                .tabItem { Label("Saved", systemImage: "bookmark") }
                .tag("saved")
            DiscoverView(
                apps: [], addService: { _ in }, openApp: { _ in },
                atmosphereEpoch: 0, isAtmosphereActive: false, allowsAtmosphere: false
            )
            .tabItem { Label("Discover", systemImage: "safari") }
            .tag("discover")
        }
    }

    private var accounts: some View {
        NavigationStack {
            List {
                Section("Profiles") {
                    ForEach(examples.profiles) { app in
                        ProfilePickerRow(
                            name: app.name, iconData: app.iconData, websiteURL: app.url,
                            iconSymbol: app.iconSymbol, iconColor: app.iconColor,
                            badgeColor: app.iconColor, isFavorite: false, isLocked: false,
                            biometricLabel: "Face ID", open: {}, edit: {}, details: {},
                            toggleFavorite: {}, toggleLock: {}, delete: {}
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { appBackground }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("Gmail")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var privacy: some View {
        VStack {
            AppLockContent(app: examples.profiles[0], biometricLabel: "Face ID", unlock: {})
                .padding(.horizontal, 24)
                .padding(.top, 115)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var protection: some View {
        NavigationStack {
            ContainerPreferencesView(app: examples.profiles[0], privacyOnly: true)
        }
    }
}

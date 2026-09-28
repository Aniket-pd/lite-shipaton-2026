import SwiftData
import SwiftUI
import WidgetKit
import OSLog

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(AppOpenCoordinator.self) private var openCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("lite.atmosphericBackground") private var atmosphericBackground = true
    @AppStorage("lite.showsLibraryAppNames") private var showsLibraryAppNames = true
    @AppStorage("lite.iconBackfill.v2.completed") private var didBackfillLegacyIcons = false
    @Query private var apps: [LiteApp]
    @State private var sheet: HomeSheet?
    @State private var appToDelete: LiteApp?
    @State private var errorMessage: String?
    @State private var isDeleting = false
    @State private var biometrics = BiometricService()
    @State private var lockChangeAppID: UUID?
    @State private var selectedTab: AppTab = .library
    @State private var isSavedContainerPresented = false
    @State private var atmosphereEpoch = Date.timeIntervalSinceReferenceDate
    @State private var wantsOnboarding = OnboardingPolicy.initialPresentation()

    private var showsOnboarding: Bool {
        wantsOnboarding && apps.isEmpty && openCoordinator.request == nil
            && openCoordinator.invalidRequestMessage == nil
    }

    private var orderedApps: [LiteApp] {
        apps.sorted {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.createdAt < $1.createdAt
        }
    }

    private var groupedApps: [LiteAppGroup] {
        LiteAppGrouping.groups(from: orderedApps)
    }

    private var showsAtmosphere: Bool { atmosphericBackground && colorScheme == .dark }

    private var metadataRevision: String {
        orderedApps.map {
            "\($0.id)|\($0.name)|\($0.iconSymbol)|\($0.iconColor)|\($0.isVisibleInWidget)|\($0.isFavorite)|\($0.sortOrder)|\($0.iconData?.hashValue ?? 0)"
        }.joined(separator: ";")
    }

    var body: some View {
        Group {
            if showsOnboarding {
                LiteOnboardingView {
                    finishOnboarding()
                } onSkip: {
                    finishOnboarding()
                }
            } else {
                mainTabs
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .create(let service):
                CreateAppView(initialService: service) { selectedTab = .library }
            case .edit(let app): EditAppView(app: app)
            case .details(let app): ContainerDetailsSheet(app: app)
            case .profiles(let groupID, let startsAdding):
                ProfilePickerSheet(
                    groupID: groupID,
                    startsAdding: startsAdding
                )
            case .settings: SettingsView(apps: orderedApps)
            }
        }
        .fullScreenCover(item: openRequestBinding) { request in
            if let app = apps.first(where: { $0.id == request.appID }) {
                LockedLiteAppView(app: app)
                    .environment(\.browserWebsiteColorScheme, colorScheme)
                    .id(request.id)
            } else {
                MissingLiteAppView { openCoordinator.close() }
            }
        }
        .confirmationDialog("Delete Lite App?", isPresented: Binding(
            get: { appToDelete != nil }, set: { if !$0 { appToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: deleteApp)
        } message: {
            Text("Delete \(appToDelete?.name ?? "this app"), its bookmarks, downloads, sign-in and website data? Copies exported to Files and other Lite Apps won’t be affected.")
        }
        .alert("Something needs attention", isPresented: Binding(
            get: { errorMessage != nil || openCoordinator.invalidRequestMessage != nil },
            set: { if !$0 { errorMessage = nil; openCoordinator.clearMessage() } }
        )) {
            Button("OK") { errorMessage = nil; openCoordinator.clearMessage() }
        } message: {
            Text(errorMessage ?? openCoordinator.invalidRequestMessage ?? "")
        }
        .task {
            if showsOnboarding { OnboardingPolicy.markStarted() }
            // Consume an explicit launch destination before considering the intro.
            openCoordinator.consumePendingIntent()
            if !apps.isEmpty || openCoordinator.request != nil {
                if !apps.isEmpty, wantsOnboarding { OnboardingPolicy.complete() }
                wantsOnboarding = false
            }
            normalizeOrdering()
            do { try await ProfileDeletionService.finishPendingDeletions(in: context) }
            catch { errorMessage = "Some deleted website data couldn’t be cleared. Lite will retry the next time it opens." }
            openCoordinator.consumePendingIntent()
            if !didBackfillLegacyIcons {
                let count = await IconBackfillService.backfill(apps: apps, in: context)
                Logger(subsystem: "aniket.lite", category: "Icons")
                    .info("Legacy icon backfill updated \(count, privacy: .public) saved apps")
                if !Task.isCancelled { didBackfillLegacyIcons = true }
            }
        }
        .task(id: metadataRevision) {
            LiteMetadataStore.update(from: apps)
            WidgetCenter.shared.reloadTimelines(ofKind: "LiteFavoritesWidget")
        }
        .onReceive(NotificationCenter.default.publisher(for: .liteOpenRequested)) { _ in
            openCoordinator.consumePendingIntent()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                openCoordinator.consumePendingIntent()
            } else if phase == .background {
                biometrics.cancel()
            }
        }
        .onChange(of: openCoordinator.request) { _, request in
            if request != nil {
                wantsOnboarding = false
                sheet = nil
            }
        }
        .sensoryFeedback(.selection, trigger: openCoordinator.request?.id)
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            libraryTab
                .tabItem { Label("Library", systemImage: "square.grid.2x2") }
                .tag(AppTab.library)

            AppGroupsView(
                openApp: rememberAndOpen,
                addApp: {
                    selectedTab = .library
                    sheet = .create(nil)
                },
                atmosphereEpoch: atmosphereEpoch,
                isAtmosphereActive: selectedTab == .groups && scenePhase == .active
            )
            .tabItem { Label("Groups", systemImage: "rectangle.3.group") }
            .tag(AppTab.groups)

            SavedTabView(
                apps: orderedApps,
                isActive: selectedTab == .saved && openCoordinator.request == nil,
                isPresentingContainer: $isSavedContainerPresented,
                atmosphereEpoch: atmosphereEpoch,
                isAtmosphereActive: selectedTab == .saved && scenePhase == .active
            )
            .tabItem { Label("Saved", systemImage: "bookmark") }
            .tag(AppTab.saved)

            DiscoverView(
                apps: orderedApps,
                addService: { sheet = .create($0) },
                openApp: { openCoordinator.open($0.id) },
                atmosphereEpoch: atmosphereEpoch,
                isAtmosphereActive: selectedTab == .discover && scenePhase == .active
            )
            .tabItem { Label("Discover", systemImage: "safari") }
            .tag(AppTab.discover)
        }
    }

    private func finishOnboarding() -> Bool {
        guard showsOnboarding else { return false }
        do {
            try StarterLibrary.installIfEmpty(in: context)
            OnboardingPolicy.complete()
            wantsOnboarding = false
            selectedTab = .library
            return true
        } catch {
            errorMessage = "Your starter apps couldn’t be saved. Please try again."
            return false
        }
    }

    private var libraryTab: some View {
        NavigationStack {
            ZStack {
                if apps.isEmpty { EmptyLibraryView { sheet = .create(nil) } }
                else { appGrid }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { mainBackground }
            .navigationTitle("Apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { homeToolbar }
            .toolbarBackground(showsAtmosphere ? .hidden : .automatic, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var mainBackground: some View {
        if showsAtmosphere {
            AtmosphereBackground(
                isActive: selectedTab == .library && scenePhase == .active,
                animationEpoch: atmosphereEpoch
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            Color(.systemGroupedBackground).ignoresSafeArea()
        }
    }

    private var openRequestBinding: Binding<OpenAppRequest?> {
        // Wait for Saved's container presentation to finish dismissing before
        // switching to a new container or handling an incoming shortcut.
        Binding(get: { isSavedContainerPresented ? nil : openCoordinator.request },
                set: { if $0 == nil && !isSavedContainerPresented { openCoordinator.close() } })
    }

    @ToolbarContentBuilder
    private var homeToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Apps").font(.headline).accessibilityAddTraits(.isHeader)
        }
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) { addButton }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarLeading) { profileButton }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { addButton }
            ToolbarItem(placement: .topBarLeading) { profileButton }
        }
    }

    private var addButton: some View {
        Button { sheet = .create(nil) } label: {
            Label("New Lite App", systemImage: "plus")
                .labelStyle(.iconOnly)
                .frame(width: 48, height: 48)
                .contentShape(.rect)
        }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.add")
    }

    private var profileButton: some View {
        Button { sheet = .settings } label: {
            Label("Profile", systemImage: "person.crop.circle")
                .labelStyle(.iconOnly)
                .frame(width: 48, height: 48)
                .contentShape(.rect)
        }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.settings")
    }

    private var appGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 140 : 92), spacing: 16)],
                alignment: .leading, spacing: 28
            ) {
                ForEach(groupedApps) { group in
                    let app = group.lastUsedApp
                    LiteAppGridButton(
                        group: group,
                        showsName: showsLibraryAppNames,
                        disabled: isDeleting,
                        biometricLabel: biometrics.label,
                        open: {
                            if group.apps.count == 1 {
                                rememberAndOpen(app)
                            } else {
                                sheet = .profiles(group.id, startsAdding: false)
                            }
                        },
                        showProfiles: { sheet = .profiles(group.id, startsAdding: false) },
                        addProfile: { sheet = .profiles(group.id, startsAdding: true) },
                        edit: { sheet = .edit(app) },
                        details: { sheet = .details(app) },
                        toggleLock: { Task { await toggleLock(app) } },
                        toggleFavorite: { toggleFavorite(app) },
                        delete: { appToDelete = app }
                    )
                }
            }
            .padding(24)
        }
        .overlay(alignment: .bottom) {
            Text("\(groupedApps.count) \(groupedApps.count == 1 ? "Website" : "Websites")")
                .font(.footnote).foregroundStyle(.secondary).padding(.vertical, 8)
                .accessibilityHidden(true)
        }
    }

    private func normalizeOrdering() {
        var changed = false
        for (index, app) in orderedApps.enumerated() where app.sortOrder != index {
            app.sortOrder = index
            changed = true
        }
        if changed { try? context.save() }
    }

    private func toggleFavorite(_ app: LiteApp) {
        app.isFavorite.toggle()
        do { try context.save() }
        catch { context.rollback(); errorMessage = "Your favorite setting couldn’t be saved." }
    }

    private func rememberAndOpen(_ app: LiteApp) {
        app.lastOpenedAt = .now
        do {
            try context.save()
            openCoordinator.open(app.id)
        } catch {
            context.rollback()
            errorMessage = "The Lite App couldn’t be opened. Please try again."
        }
    }

    private func toggleLock(_ app: LiteApp) async {
        guard lockChangeAppID == nil else { return }
        let appID = app.id
        let wasLocked = app.isBiometricLocked
        lockChangeAppID = appID
        defer {
            if lockChangeAppID == appID { lockChangeAppID = nil }
        }

        do {
            let reason = wasLocked
                ? "Remove the lock from \(app.name)."
                : "Require \(biometrics.label) to open \(app.name)."
            try await biometrics.authenticate(reason: reason)
        } catch {
            errorMessage = BiometricService.message(for: error)
            return
        }

        guard scenePhase == .active,
              lockChangeAppID == appID,
              apps.contains(where: { $0.id == appID }),
              app.isBiometricLocked == wasLocked else { return }
        app.isBiometricLocked = !wasLocked
        do {
            try context.save()
        } catch {
            context.rollback()
            errorMessage = "The lock setting couldn’t be saved. Please try again."
        }
    }

    private func deleteApp() {
        guard let app = appToDelete else { return }
        appToDelete = nil
        do {
            try ProfileDeletionService.delete(app, in: context)
            isDeleting = true
            Task {
                defer { isDeleting = false }
                do { try await ProfileDeletionService.finishPendingDeletions(in: context) }
                catch { errorMessage = "The app was removed. Its website data will be cleared the next time Lite opens." }
            }
        } catch { errorMessage = "The app couldn’t be deleted. Please try again." }
    }
}

private struct EmptyLibraryView: View {
    let create: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 58, weight: .light)).foregroundStyle(.blue)
                    .padding(28).background(Color.blue.opacity(0.07), in: .rect(cornerRadius: 32))
                    .accessibilityHidden(true)
                Text("Your apps.\nA little lighter.")
                    .font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text("Your favorite websites, with a place of their own. Less to install. More room for you.")
                    .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                Button(action: create) {
                    Label("Create your first Lite App", systemImage: "plus")
                        .font(.headline).padding(.vertical, 7).padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .accessibilityIdentifier("home.empty.add")
            }
            .frame(maxWidth: .infinity).padding(.horizontal, 28).padding(.top, 56).padding(.bottom, 32)
        }
    }
}

private struct LiteAppGridButton: View {
    let group: LiteAppGroup
    let showsName: Bool
    let disabled: Bool
    let biometricLabel: String
    let open: () -> Void
    let showProfiles: () -> Void
    let addProfile: () -> Void
    let edit: () -> Void
    let details: () -> Void
    let toggleLock: () -> Void
    let toggleFavorite: () -> Void
    let delete: () -> Void

    private var app: LiteApp { group.lastUsedApp }

    var body: some View {
        Button(action: open) {
            LibraryWebsiteTile(group: group, showsName: showsName)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(group.websiteName)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(group.apps.count == 1 ? "Opens this Lite App. More actions are available." : "Shows profiles for this website.")
        .accessibilityIdentifier("home.app.\(group.apps.count == 1 ? app.name : group.websiteName)")
        .contextMenu {
            if group.apps.count > 1 {
                Button("Choose Profile", systemImage: "person.2", action: showProfiles)
                Button("Add Profile", systemImage: "person.crop.circle.badge.plus", action: addProfile)
            } else {
                Button("App Settings", systemImage: "slider.horizontal.3", action: details)
                Button("Edit", systemImage: "pencil", action: edit)
                Button(
                    app.isBiometricLocked ? "Unlock App" : "Require \(biometricLabel)",
                    systemImage: app.isBiometricLocked ? "lock.open" : "faceid",
                    action: toggleLock
                )
                Button(app.isFavorite ? "Remove Favorite" : "Favorite", systemImage: app.isFavorite ? "star.slash" : "star", action: toggleFavorite)
                Button("Add Profile", systemImage: "person.crop.circle.badge.plus", action: addProfile)
                Button("Delete", systemImage: "trash", role: .destructive, action: delete)
            }
        }
        .accessibilityAction(named: group.apps.count > 1 ? "Choose Profile" : "Open", open)
        .accessibilityAction(named: "Add Profile", addProfile)
        .disabled(disabled)
    }

    private var accessibilityValue: String {
        let profileCount = group.apps.count > 1 ? "\(group.apps.count) profiles" : nil
        let favorite = group.isFavorite ? "Favorite" : nil
        let locked = group.hasLockedProfile ? "Contains a locked profile" : nil
        return [profileCount, favorite, locked].compactMap { $0 }.joined(separator: ", ")
    }
}

/// Shared visual tile used by the library and read-only onboarding examples.
struct LibraryWebsiteTile: View {
    let group: LiteAppGroup
    let showsName: Bool

    var body: some View {
        VStack(spacing: 10) {
            AppIconView(
                data: group.iconApp.iconData,
                websiteURL: group.iconApp.url,
                symbol: group.iconApp.iconSymbol,
                size: 68
            )
                .overlay(alignment: .topTrailing) {
                    if group.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.yellow)
                            .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                            .offset(x: 4, y: -4)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if group.hasLockedProfile {
                        Image(systemName: "lock.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.primary)
                            .shadow(color: Color(.systemBackground).opacity(0.9), radius: 1)
                            .offset(x: -4, y: 4)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if group.apps.count > 1 {
                        ProfileAvatarStack(group: group)
                            .offset(x: 9, y: 8)
                    }
                }
            if showsName {
                Text(group.websiteName).font(.subheadline).foregroundStyle(.primary)
                    .multilineTextAlignment(.center).lineLimit(2, reservesSpace: true)
            }
        }
        .frame(maxWidth: .infinity).contentShape(.rect)
    }
}

private struct ProfileAvatarStack: View {
    let group: LiteAppGroup

    private var visibleProfiles: [LiteApp] {
        group.apps.count > 3 ? Array(group.apps.prefix(2)) : Array(group.apps.prefix(3))
    }

    var body: some View {
        badges
    }

    private var badges: some View {
        HStack(spacing: -7) {
            ForEach(visibleProfiles) { app in
                ProfileBadgeView(
                    label: group.profileName(for: app),
                    color: app.iconColor
                )
            }
            if group.apps.count > 3 {
                ProfileBadgeView(
                    label: "+\(group.apps.count - 2)",
                    showsFullLabel: true
                )
            }
        }
        .accessibilityHidden(true)
    }
}

struct LibraryManagementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\LiteApp.sortOrder), SortDescriptor(\LiteApp.createdAt)]) private var apps: [LiteApp]
    @State private var errorMessage: String?

    var body: some View {
        List {
            if apps.isEmpty {
                ContentUnavailableView("No Lite Apps Yet", systemImage: "square.grid.2x2", description: Text("Add apps from Library or Discover, then organize them here."))
            } else {
                appSection("Favorites", favorites: true)
                appSection("Other Apps", favorites: false)
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Organize Library")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn’t Save", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
    }

    private func appSection(_ title: String, favorites: Bool) -> some View {
        let sectionApps = apps.filter { $0.isFavorite == favorites }
        return Section {
            if sectionApps.isEmpty {
                Text(favorites ? "Mark an app as a favorite to keep it at the top." : "All your apps are favorites.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(sectionApps) { app in
                HStack(spacing: 12) {
                    AppIconView(data: app.iconData, websiteURL: app.url, symbol: app.iconSymbol, size: 38)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                        Text(app.url.host ?? "Website").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        app.isFavorite.toggle()
                        save()
                    } label: {
                        Image(systemName: app.isFavorite ? "star.fill" : "star")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(app.isFavorite ? "Remove \(app.name) from favorites" : "Favorite \(app.name)")
                    .accessibilityIdentifier("organize.favorite.\(app.name)")
                    .buttonStyle(.borderless)
                }
            }
            .onMove { source, destination in
                var reordered = sectionApps
                reordered.move(fromOffsets: source, toOffset: destination)
                let otherApps = apps.filter { $0.isFavorite != favorites }
                let combined = favorites ? reordered + otherApps : otherApps + reordered
                for (index, app) in combined.enumerated() { app.sortOrder = index }
                save()
            }
        } header: { Text(title) } footer: {
            if favorites { Text("Favorites appear first. Tap a star to change favorites; drag the handles to reorder apps within each group.") }
        }
    }

    private func save() {
        do { try context.save() }
        catch { context.rollback(); errorMessage = "Your library changes couldn’t be saved." }
    }
}

private struct MissingLiteAppView: View {
    let close: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label("Lite App Not Found", systemImage: "questionmark.app")
        } description: {
            Text("It may have been deleted or is no longer available.")
        } actions: {
            Button("Done", action: close).buttonStyle(.borderedProminent)
        }
    }
}

private enum HomeSheet: Identifiable {
    case create(CatalogService?), edit(LiteApp), details(LiteApp)
    case profiles(String, startsAdding: Bool)
    case settings
    var id: String {
        switch self {
        case .create(let service): "create-\(service?.id ?? "website")"
        case .edit(let app): "edit-\(app.id)"
        case .details(let app): "details-\(app.id)"
        case .profiles(let groupID, let startsAdding): "profiles-\(groupID)-\(startsAdding)"
        case .settings: "settings"
        }
    }
}

private enum AppTab: Hashable {
    case library
    case groups
    case saved
    case discover
}

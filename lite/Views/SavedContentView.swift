import QuickLook
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum SavedSection: String, CaseIterable, Identifiable {
    case bookmarks, downloads

    var id: String { rawValue }
    var title: String { self == .bookmarks ? "Bookmarks" : "Downloads" }
    var symbol: String { self == .bookmarks ? "bookmark" : "arrow.down.circle" }
    var searchPrompt: String { self == .bookmarks ? "Search bookmarks" : "Search downloads" }
}

/// The global list only renders item details for containers without a biometric lock.
/// Locked containers expose presence only, then create an authenticated presentation when selected.
struct SavedTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("lite.atmosphericBackground") private var atmosphericBackground = true
    let apps: [LiteApp]
    let isActive: Bool
    @Binding var isPresentingContainer: Bool
    let atmosphereEpoch: TimeInterval
    let isAtmosphereActive: Bool
    @State private var section: SavedSection = .bookmarks
    @State private var searchText = ""
    @State private var sortOrder: SavedSortOrder = .newest
    @State private var selectedProfileID: UUID?
    @State private var destination: SavedDestination?
    @State private var store = SavedContentStore.shared
    @FocusState private var searchFocused: Bool

    private var showsAtmosphere: Bool { atmosphericBackground && colorScheme == .dark }

    private var visibleApps: [LiteApp] {
        apps.filter { !$0.isBiometricLocked && (selectedProfileID == nil || $0.dataStoreIdentifier == selectedProfileID) }
    }

    private var lockedApps: [LiteApp] {
        apps.filter {
            $0.isBiometricLocked && store.hasSavedContent(for: $0.dataStoreIdentifier)
        }
    }

    private var selectedApp: LiteApp? {
        apps.first { $0.dataStoreIdentifier == selectedProfileID }
    }

    var body: some View {
        VStack(spacing: 0) {
            SavedGlassContainer {
                VStack(spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        SavedSectionPicker(selection: $section)
                        filterMenu
                    }
                    SavedSearchField(
                        text: $searchText, prompt: section.searchPrompt,
                        isActive: isActive && destination == nil,
                        focus: $searchFocused
                    )
                    if selectedProfileID != nil || sortOrder != .newest {
                        activeFilterSummary
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            SavedItemsList(
                apps: visibleApps,
                allApps: apps,
                hasLockedContainers: !lockedApps.isEmpty,
                showsContainerLabels: selectedProfileID == nil,
                section: section,
                sortOrder: sortOrder,
                searchText: searchText,
                isActive: isActive,
                dismissSearch: { searchFocused = false },
                openBookmark: { app, url in
                    guard isActive, scenePhase == .active else { return }
                    isPresentingContainer = true
                    destination = SavedDestination(app: app, section: section, bookmarkURL: url)
                }
            )
        }
        .background { savedBackground }
        .fullScreenCover(item: $destination, onDismiss: { isPresentingContainer = false }) { selected in
            ContainerAccessView(app: selected.app) {
                if let url = selected.bookmarkURL {
                    LiteBrowserView(app: selected.app, initialURL: url)
                } else {
                    ContainerSavedView(app: selected.app, initialSection: selected.section)
                }
            }
        }
        .onChange(of: isActive) {
            if !isActive { destination = nil }
        }
        .onChange(of: apps.map(\.id)) {
            if selectedApp == nil { selectedProfileID = nil }
            if let destination, !apps.contains(where: { $0.id == destination.app.id }) {
                self.destination = nil
            }
        }
        .onChange(of: selectedApp?.isBiometricLocked) {
            // Enabling a lock elsewhere must immediately remove the global results.
            if selectedApp?.isBiometricLocked == true { selectedProfileID = nil }
        }
    }

    @ViewBuilder
    private var savedBackground: some View {
        if showsAtmosphere {
            AtmosphereBackground(isActive: isAtmosphereActive, animationEpoch: atmosphereEpoch)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            Color(.systemGroupedBackground).ignoresSafeArea()
        }
    }

    private var filterMenu: some View {
        Menu {
            Button {
                selectedProfileID = nil
            } label: {
                SavedAllContainersFilterLabel(isSelected: selectedProfileID == nil)
            }
            .accessibilityIdentifier("saved.filter.all")
            Section {
                ForEach(apps.filter { !$0.isBiometricLocked }) { app in
                    Button {
                        selectedProfileID = app.dataStoreIdentifier
                    } label: {
                        SavedContainerFilterLabel(
                            app: app,
                            allApps: apps,
                            isSelected: selectedProfileID == app.dataStoreIdentifier,
                            isLocked: false
                        )
                    }
                    .accessibilityIdentifier("saved.filter.\(app.name)")
                }
            }
            if !lockedApps.isEmpty {
                Section {
                    ForEach(lockedApps) { app in
                        Button { openContainer(app) } label: {
                            SavedContainerFilterLabel(
                                app: app,
                                allApps: apps,
                                isSelected: false,
                                isLocked: true
                            )
                        }
                        .accessibilityIdentifier("saved.filter.\(app.name)")
                        .accessibilityHint("Unlock to view saved bookmarks and downloads")
                    }
                } header: {
                    Text("Locked Containers")
                } footer: {
                    Text("Locked containers require unlocking.")
                }
            }
            Section("Sort") {
                SavedSortOptions(selection: $sortOrder)
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.body.weight(.medium))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(selectedProfileID != nil || sortOrder != .newest ? Color.accentColor : .primary)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter and sort")
        .accessibilityValue("\(selectedApp.map { savedContainerLabel($0, among: apps) } ?? "All Containers"), \(sortOrder.title)")
        .accessibilityIdentifier("saved.containerFilter")
    }

    private var activeFilterSummary: some View {
        HStack(spacing: 4) {
            Text([
                selectedApp.map { savedContainerLabel($0, among: apps) },
                sortOrder == .newest ? nil : sortOrder.title
            ].compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                selectedProfileID = nil
                sortOrder = .newest
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset filters and sorting")
            .accessibilityIdentifier("saved.filter.reset")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openContainer(_ app: LiteApp) {
        guard isActive, scenePhase == .active else { return }
        isPresentingContainer = true
        destination = SavedDestination(app: app, section: section, bookmarkURL: nil)
    }
}

private struct SavedAllContainersFilterLabel: View {
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 26, height: 26)
                .background(Color.blue.opacity(0.14), in: .circle)
            Text("All Containers")
            Spacer(minLength: 8)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
    }
}

private struct SavedContainerFilterLabel: View {
    let app: LiteApp
    let allApps: [LiteApp]
    let isSelected: Bool
    let isLocked: Bool

    private var hasProfileBadge: Bool {
        allApps.filter {
            LiteAppGrouping.groupID(for: $0.url) == LiteAppGrouping.groupID(for: app.url)
        }.count > 1
    }

    var body: some View {
        HStack(spacing: 10) {
            filterIcon
            Text(savedContainerLabel(app, among: allApps))
            Spacer(minLength: 8)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
    }

    private var filterIcon: some View {
        AppIconView(
            data: app.iconData,
            websiteURL: app.url,
            symbol: app.iconSymbol,
            size: 26
        )
        .clipShape(.circle)
        .overlay(alignment: .bottomTrailing) {
            if hasProfileBadge {
                ProfileBadgeView(
                    label: savedProfileLabel(app, among: allApps),
                    color: app.iconColor,
                    size: 14
                )
                .offset(x: 2, y: 2)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 13, height: 13)
                    .background(Color.gray, in: .circle)
                    .overlay { Circle().strokeBorder(Color(.systemBackground), lineWidth: 1) }
                    .offset(x: -2, y: 2)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }
}

/// Present this inside the container's existing ContainerAccessView boundary.
/// Browser callers can reuse their existing web session through openBookmark.
struct ContainerSavedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let app: LiteApp
    let initialSection: SavedSection
    let openBookmark: ((URL) -> Void)?
    @State private var section: SavedSection = .bookmarks
    @State private var searchText = ""
    @State private var sortOrder: SavedSortOrder = .newest
    @State private var browserDestination: SavedBrowserDestination?
    @State private var pendingBookmarkURL: URL?
    @State private var didSetInitialSection = false
    @FocusState private var searchFocused: Bool

    init(app: LiteApp, initialSection: SavedSection = .bookmarks, openBookmark: ((URL) -> Void)? = nil) {
        self.app = app
        self.initialSection = initialSection
        self.openBookmark = openBookmark
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    SavedSectionPicker(selection: $section)
                    SavedSearchField(
                        text: $searchText,
                        prompt: section.searchPrompt,
                        isActive: browserDestination == nil,
                        focus: $searchFocused
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                SavedItemsList(
                    apps: [app],
                    allApps: [app],
                    hasLockedContainers: false,
                    showsContainerLabels: false,
                    section: section,
                    sortOrder: sortOrder,
                    searchText: searchText,
                    isActive: true,
                    dismissSearch: { searchFocused = false },
                    openBookmark: { _, url in showBookmark(url) }
                )
            }
            .navigationTitle(app.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SavedSortMenu(selection: $sortOrder)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("saved.done")
                }
            }
        }
        .onAppear {
            if !didSetInitialSection {
                section = initialSection
                didSetInitialSection = true
            }
        }
        .fullScreenCover(item: $browserDestination) { destination in
            // This browser shares its parent's authenticated container subtree.
            LiteBrowserView(app: app, initialURL: destination.url)
        }
        .onDisappear {
            if let url = pendingBookmarkURL {
                pendingBookmarkURL = nil
                if scenePhase == .active { openBookmark?(url) }
            }
        }
    }

    private func showBookmark(_ url: URL) {
        guard scenePhase == .active else { return }
        if openBookmark != nil {
            pendingBookmarkURL = url
            dismiss()
        } else {
            browserDestination = SavedBrowserDestination(url: url)
        }
    }
}

private struct SavedDestination: Identifiable {
    let id = UUID()
    let app: LiteApp
    let section: SavedSection
    let bookmarkURL: URL?
}

private struct SavedBrowserDestination: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SavedBookmarkEntry: Identifiable {
    let app: LiteApp
    let bookmark: SavedBookmark
    var id: String { "\(app.dataStoreIdentifier)-\(bookmark.id)" }
    var title: String { bookmark.title.isEmpty ? bookmark.url.host ?? "Bookmark" : bookmark.title }
}

private struct SavedDownloadEntry: Identifiable {
    let app: LiteApp
    let file: SavedFile
    var id: String { "\(app.dataStoreIdentifier)-\(file.id)" }
}

private struct SavedItemsList: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.calendar) private var calendar
    let apps: [LiteApp]
    let allApps: [LiteApp]
    let hasLockedContainers: Bool
    let showsContainerLabels: Bool
    let section: SavedSection
    let sortOrder: SavedSortOrder
    let searchText: String
    let isActive: Bool
    let dismissSearch: () -> Void
    let openBookmark: (LiteApp, URL) -> Void
    @State private var store = SavedContentStore.shared
    @State private var previewURL: URL?
    @State private var presentation: SavedFilePresentation?
    @State private var fileToDelete: SavedFile?
    @State private var errorMessage: String?

    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var bookmarks: [SavedBookmarkEntry] {
        apps.flatMap { app in
            store.bookmarks(for: app.dataStoreIdentifier).filter { bookmark in
                query.isEmpty || bookmark.title.localizedStandardContains(query) ||
                    (bookmark.url.host?.localizedStandardContains(query) ?? false)
            }.map { SavedBookmarkEntry(app: app, bookmark: $0) }
        }
    }

    private var downloads: [SavedDownloadEntry] {
        apps.flatMap { app in
            store.downloads(for: app.dataStoreIdentifier).filter { file in
                query.isEmpty || file.filename.localizedStandardContains(query) ||
                    (file.sourceURL?.host?.localizedStandardContains(query) ?? false)
            }.map { SavedDownloadEntry(app: app, file: $0) }
        }
    }

    var body: some View {
        List {
            if section == .bookmarks {
                bookmarkSections
            } else {
                downloadSections
            }
            ForEach(apps) { app in
                if let message = store.loadError(for: app.dataStoreIdentifier) {
                    Section {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Couldn’t Load Saved Items").font(.headline)
                                Text(message).font(.footnote).foregroundStyle(.secondary)
                                Button("Try Again") { store.retryLoad(for: app.dataStoreIdentifier) }
                            }
                        } icon: { Image(systemName: "exclamationmark.triangle") }
                    } header: { sectionHeader(savedContainerLabel(app, among: allApps)) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(
            TapGesture().onEnded { dismissSearch() }
        )
        .buttonStyle(.plain)
        .quickLookPreview($previewURL)
        .sheet(item: $presentation) { selected in
            switch selected {
            case .export(let url):
                DownloadExportView(fileURL: url) { presentation = nil }
            case .share(let url):
                SavedShareView(url: url)
            }
        }
        .confirmationDialog("Delete Download?", isPresented: Binding(
            get: { fileToDelete != nil }, set: { if !$0 { fileToDelete = nil } }
        ), titleVisibility: .visible, presenting: fileToDelete) { file in
            Button("Delete Download", role: .destructive) {
                deleteDownload(file)
                fileToDelete = nil
            }
            Button("Cancel", role: .cancel) { fileToDelete = nil }
        } message: { file in
            Text("Delete \(file.filename) from Lite? Copies already saved to Files will remain.")
        }
        .alert("Couldn’t Update Saved Items", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                dismissPresentations()
            } else {
                apps.forEach { store.retryLoad(for: $0.dataStoreIdentifier) }
            }
        }
        .onChange(of: isActive) {
            if !isActive { dismissPresentations() }
        }
        .onChange(of: apps.map(\.dataStoreIdentifier)) { dismissPresentations() }
    }

    @ViewBuilder
    private var bookmarkSections: some View {
        let groups = SavedContentGroup.make(bookmarks, sortOrder: sortOrder,
                                           date: { $0.bookmark.createdAt }, title: { $0.title }, calendar: calendar)
        if groups.isEmpty, !hasLoadErrors {
            emptyState
        }
        ForEach(groups) { group in
            Section {
                ForEach(group.items) { entry in
                    bookmarkRow(entry)
                }
            } header: {
                sectionHeader(group.title)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 8, trailing: 0))
    }

    private func bookmarkRow(_ entry: SavedBookmarkEntry) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Button { openBookmark(entry.app, entry.bookmark.url) } label: {
                SavedBookmarkRow(entry: entry, sourceLabel: bookmarkSourceLabel(entry))
            }
            .accessibilityIdentifier("saved.bookmark.\(entry.bookmark.id)")
            Menu {
                bookmarkActions(entry)
            } label: {
                SavedItemActionsLabel()
            }
            .accessibilityLabel("Actions for \(entry.title)")
            .accessibilityIdentifier("saved.bookmark.actions.\(entry.bookmark.id)")
        }
        .modifier(SavedListRow())
        .contextMenu { bookmarkActions(entry) }
        .swipeActions {
            Button("Delete", role: .destructive) { deleteBookmark(entry.bookmark) }
        }
    }

    @ViewBuilder
    private func bookmarkActions(_ entry: SavedBookmarkEntry) -> some View {
        Button("Open Bookmark", systemImage: "safari") { openBookmark(entry.app, entry.bookmark.url) }
        Button("Share Link", systemImage: "square.and.arrow.up") { presentation = .share(entry.bookmark.url) }
        Button("Delete Bookmark", systemImage: "trash", role: .destructive) { deleteBookmark(entry.bookmark) }
    }

    private func bookmarkSourceLabel(_ entry: SavedBookmarkEntry) -> String? {
        guard showsContainerLabels else { return nil }
        // The host already identifies the website for same-site saves; retain the
        // full container identity for links that navigate to another website.
        return entry.bookmark.url.host == entry.app.url.host
            ? savedProfileLabel(entry.app, among: allApps)
            : savedContainerLabel(entry.app, among: allApps)
    }

    @ViewBuilder
    private var downloadSections: some View {
        let entries = downloads
        let active = entries.filter { $0.file.status == .downloading }
            .sorted { $0.file.createdAt > $1.file.createdAt }
        let groups = SavedContentGroup.make(entries.filter { $0.file.status != .downloading }, sortOrder: sortOrder,
                                           date: { $0.file.createdAt }, title: { $0.file.filename }, calendar: calendar)
        if entries.isEmpty, !hasLoadErrors {
            emptyState
        }
        if !active.isEmpty {
            Section {
                ForEach(active) { entry in downloadRow(entry) }
            } header: {
                sectionHeader("Downloading")
            }
        }
        ForEach(groups) { group in
            Section {
                ForEach(group.items) { entry in downloadRow(entry) }
            } header: {
                sectionHeader(group.title)
            }
        }
    }

    private func downloadRow(_ entry: SavedDownloadEntry) -> some View {
        HStack(alignment: .top, spacing: 4) {
            if entry.file.status == .completed {
                Button { preview(entry.file) } label: {
                    SavedDownloadRow(entry: entry, sourceLabel:
                                        showsContainerLabels ? savedContainerLabel(entry.app, among: allApps) : nil)
                }
                .accessibilityIdentifier("saved.download.\(entry.file.id)")
            } else {
                SavedDownloadRow(entry: entry, sourceLabel:
                                    showsContainerLabels ? savedContainerLabel(entry.app, among: allApps) : nil)
                    .accessibilityIdentifier("saved.download.\(entry.file.id)")
            }
            if entry.file.status != .downloading {
                Menu {
                    if entry.file.status == .completed {
                        Button("Preview", systemImage: "eye") { preview(entry.file) }
                            .accessibilityIdentifier("saved.download.preview.\(entry.file.id)")
                        Button("Save a Copy to Files", systemImage: "folder") { export(entry.file) }
                            .accessibilityIdentifier("saved.download.export.\(entry.file.id)")
                        Button("Share", systemImage: "square.and.arrow.up") { share(entry.file) }
                            .accessibilityIdentifier("saved.download.share.\(entry.file.id)")
                    }
                    Button("Delete Download", systemImage: "trash", role: .destructive) { fileToDelete = entry.file }
                        .accessibilityIdentifier("saved.download.delete.\(entry.file.id)")
                } label: {
                    SavedItemActionsLabel()
                }
                .accessibilityLabel("Actions for \(entry.file.filename)")
                .accessibilityIdentifier("saved.download.actions.\(entry.file.id)")
            }
        }
        .modifier(SavedListRow())
        .swipeActions {
            Button("Delete", role: .destructive) { fileToDelete = entry.file }
                .disabled(entry.file.status == .downloading)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !query.isEmpty {
            ContentUnavailableView.search(text: query)
                .listRowBackground(Color.clear)
        } else {
            ContentUnavailableView {
                Label(hasLockedContainers ? "No \(section.title) to Show" : "No \(section.title) Yet", systemImage: section.symbol)
            } description: {
                if hasLockedContainers {
                    Text(section == .bookmarks
                         ? "Bookmark a page while browsing, or choose a locked container from the filter above to unlock it."
                         : "Download a file while browsing, or choose a locked container from the filter above to unlock it.")
                } else {
                    Text(section == .bookmarks
                         ? "Bookmark a page from the browser’s menu to find it here."
                         : "Files you download in Lite will appear here, ready to open or save to Files.")
                }
            }
            .listRowBackground(Color.clear)
            .accessibilityIdentifier("saved.empty.\(section.rawValue)")
        }
    }

    private var hasLoadErrors: Bool {
        apps.contains { store.loadError(for: $0.dataStoreIdentifier) != nil }
    }

    private func preview(_ file: SavedFile) {
        guard isActive, scenePhase == .active else { return }
        do { previewURL = try store.fileURL(for: file) }
        catch { errorMessage = error.localizedDescription }
    }

    private func export(_ file: SavedFile) {
        guard isActive, scenePhase == .active else { return }
        do { presentation = .export(try store.fileURL(for: file)) }
        catch { errorMessage = error.localizedDescription }
    }

    private func share(_ file: SavedFile) {
        guard isActive, scenePhase == .active else { return }
        do { presentation = .share(try store.fileURL(for: file)) }
        catch { errorMessage = error.localizedDescription }
    }

    private func deleteBookmark(_ bookmark: SavedBookmark) {
        guard isActive, scenePhase == .active else { return }
        do { try store.deleteBookmark(bookmark) }
        catch { errorMessage = error.localizedDescription }
    }

    private func deleteDownload(_ file: SavedFile) {
        guard isActive, scenePhase == .active else { return }
        do { try store.deleteDownload(file) }
        catch { errorMessage = error.localizedDescription }
    }

    private func dismissPresentations() {
        previewURL = nil
        presentation = nil
        fileToDelete = nil
        errorMessage = nil
    }
}

private struct SavedListRow: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 6))
            .listRowBackground(surface)
            .listRowSeparatorTint(.primary.opacity(contrast == .increased ? 0.45 : 0.12))
    }

    @ViewBuilder private var surface: some View {
        if contrast == .increased {
            Color(.secondarySystemGroupedBackground)
        } else {
            GroupCardMaterial(shape: Rectangle())
        }
    }
}

private struct SavedItemActionsLabel: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .font(.body.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
    }
}

private struct SavedBookmarkRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let entry: SavedBookmarkEntry
    let sourceLabel: String?

    private var metadata: String {
        let host = entry.bookmark.url.host ?? entry.bookmark.url.absoluteString
        return sourceLabel.map { "\(host) · \($0)" } ?? host
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SavedSourceIcon(app: entry.app)
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.title)
                    .font(.body.weight(.medium)).foregroundStyle(.primary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                Text(metadata)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

private struct SavedDownloadRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let entry: SavedDownloadEntry
    let sourceLabel: String?

    private var fileTypeLabel: String {
        let suffix = (entry.file.filename as NSString).pathExtension
        return suffix.isEmpty ? "File" : suffix.uppercased()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SavedFileIcon(filename: entry.file.filename)
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.file.filename).font(.body.weight(.medium)).foregroundStyle(.primary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                switch entry.file.status {
                case .downloading:
                    ProgressView(value: min(1, max(0, entry.file.progress)))
                        .accessibilityLabel("Download progress")
                    Text("Downloading · \(Int(min(1, max(0, entry.file.progress)) * 100))%")
                        .font(.caption).foregroundStyle(.secondary)
                case .completed:
                    Text("\(fileTypeLabel) · \(ByteCountFormatter.string(fromByteCount: entry.file.byteCount, countStyle: .file))")
                        .font(.caption).foregroundStyle(.secondary)
                case .failed:
                    Label("Download failed", systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(.secondary)
                    if let message = entry.file.errorMessage {
                        Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                    }
                }
                if let sourceLabel {
                    Text(sourceLabel).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

private struct SavedFileIcon: View {
    let filename: String

    private var type: UTType? { UTType(filenameExtension: (filename as NSString).pathExtension) }

    private var symbol: String {
        guard let type else { return "doc" }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .audio) { return "waveform" }
        if type.conforms(to: .movie) { return "film" }
        if type.conforms(to: .archive) { return "doc.zipper" }
        if type.conforms(to: .text) { return "doc.text" }
        return "doc"
    }

    private var color: Color { type?.conforms(to: .pdf) == true ? .red : .blue }

    var body: some View {
        Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(color)
            .frame(width: 36, height: 40)
            .background(color.opacity(0.12), in: .rect(cornerRadius: 8))
            .accessibilityHidden(true)
    }
}

private struct SavedSourceIcon: View {
    let app: LiteApp

    var body: some View {
        AppIconView(data: app.iconData, websiteURL: app.url, symbol: app.iconSymbol, size: 36)
            .accessibilityHidden(true)
    }
}

private enum SavedFilePresentation: Identifiable {
    case export(URL), share(URL)

    var id: String {
        switch self {
        case .export(let url): "export-\(url.absoluteString)"
        case .share(let url): "share-\(url.absoluteString)"
        }
    }
}

private struct SavedShareView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private func savedContainerLabel(_ app: LiteApp, among apps: [LiteApp]) -> String {
    let members = apps.filter { LiteAppGrouping.groupID(for: $0.url) == LiteAppGrouping.groupID(for: app.url) }
    let website = LiteAppGrouping.websiteName(for: members.isEmpty ? [app] : members)
    return "\(website) · \(savedProfileLabel(app, among: apps))"
}

private func savedProfileLabel(_ app: LiteApp, among apps: [LiteApp]) -> String {
    let members = apps.filter { LiteAppGrouping.groupID(for: $0.url) == LiteAppGrouping.groupID(for: app.url) }
    let website = LiteAppGrouping.websiteName(for: members.isEmpty ? [app] : members)
    let account = LiteAppGrouping.profileName(for: app, websiteName: website)
    let duplicates = members.filter { LiteAppGrouping.profileName(for: $0, websiteName: website) == account }
    return duplicates.count > 1 ? "\(account) · \(app.dataStoreIdentifier.uuidString.prefix(4))" : account
}

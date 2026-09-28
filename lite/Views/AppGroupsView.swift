import SwiftData
import SwiftUI

struct AppGroupsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\LiteAppCollection.sortOrder), SortDescriptor(\LiteAppCollection.createdAt)])
    private var collections: [LiteAppCollection]
    @Query private var apps: [LiteApp]
    @State private var sheet: AppGroupSheet?
    @State private var collectionToDelete: LiteAppCollection?
    @State private var errorMessage: String?
    @State private var focusedAppIDs: [UUID: UUID] = [:]

    let openApp: (LiteApp) -> Void
    let addApp: () -> Void
    let atmosphereEpoch: TimeInterval
    let isAtmosphereActive: Bool

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("lite.atmosphericBackground") private var atmosphericBackground = true

    private var showsAtmosphere: Bool { atmosphericBackground && colorScheme == .dark }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(collections) { collection in
                        AppGroupCard(
                            collection: collection,
                            focusedAppID: Binding(
                                get: { focusedAppIDs[collection.id] },
                                set: { focusedAppIDs[collection.id] = $0 }
                            ),
                            openApp: openApp,
                            showAll: { sheet = .details(collection) },
                            edit: { sheet = .edit(collection) },
                            delete: { collectionToDelete = collection }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .background { groupsBackground }
            .overlay {
                if collections.isEmpty {
                    EmptyGroupsView(
                        appCount: apps.count,
                        createGroup: { sheet = .create },
                        addApp: addApp
                    )
                }
            }
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(showsAtmosphere ? .hidden : .automatic, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Groups").font(.headline).accessibilityAddTraits(.isHeader)
                }
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .primaryAction) { addGroupButton }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .primaryAction) { addGroupButton }
                }
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .create:
                AppGroupEditorView()
            case .edit(let collection):
                AppGroupEditorView(collection: collection)
            case .details(let collection):
                AppGroupDetailSheet(
                    collection: collection,
                    openApp: openApp
                )
            }
        }
        .confirmationDialog(
            "Delete Group?",
            isPresented: Binding(
                get: { collectionToDelete != nil },
                set: { if !$0 { collectionToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Group", role: .destructive, action: deleteCollection)
        } message: {
            Text("The apps inside \(collectionToDelete?.name ?? "this group") will stay in your library.")
        }
        .alert(
            "Couldn’t Delete Group",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: collections.map(\.id)) { _, ids in
            focusedAppIDs = focusedAppIDs.filter { ids.contains($0.key) }
        }
    }

    private var addGroupButton: some View {
        Button { sheet = .create } label: {
            Label("New Group", systemImage: "plus")
        }
        .buttonStyle(.plain)
        .disabled(apps.count < 2)
        .accessibilityIdentifier("groups.add")
    }

    @ViewBuilder
    private var groupsBackground: some View {
        if showsAtmosphere {
            AtmosphereBackground(isActive: isAtmosphereActive, animationEpoch: atmosphereEpoch)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            Color(.systemGroupedBackground).ignoresSafeArea()
        }
    }

    private func deleteCollection() {
        guard let collection = collectionToDelete else { return }
        collectionToDelete = nil
        context.delete(collection)
        do {
            try context.save()
        } catch {
            context.rollback()
            errorMessage = "Your group couldn’t be deleted. Please try again."
        }
    }
}

private struct AppGroupDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let collection: LiteAppCollection
    let openApp: (LiteApp) -> Void
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            AppGroupDetailView(
                collection: collection,
                openApp: { app in
                    dismiss()
                    openApp(app)
                },
                edit: { isEditing = true }
            )
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $isEditing) {
            AppGroupEditorView(collection: collection)
        }
    }
}

private struct EmptyGroupsView: View {
    let appCount: Int
    let createGroup: () -> Void
    let addApp: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Group Your Lite Apps", systemImage: "rectangle.3.group")
        } description: {
            if appCount >= 2 {
                Text("Create a group for apps you use together, such as Work, Social, or Shopping.")
            } else {
                Text("Add at least two Lite Apps, then collect them in a group.")
            }
        } actions: {
            if appCount >= 2 {
                Button("Create Group", action: createGroup)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("groups.empty.create")
            } else {
                Button("Add Lite App", action: addApp)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("groups.empty.addApp")
            }
        }
        .padding()
    }
}

private struct AppGroupDetailView: View {
    let collection: LiteAppCollection
    let openApp: (LiteApp) -> Void
    let edit: () -> Void

    var body: some View {
        Group {
            if collection.orderedApps.isEmpty {
                ContentUnavailableView(
                    "This Group Is Empty",
                    systemImage: "rectangle.3.group",
                    description: Text("Use Edit to add Lite Apps to this group.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        LazyVStack(spacing: 0) {
                            ForEach(collection.orderedApps) { app in
                                Button { openApp(app) } label: {
                                    AppGroupMemberRow(app: app)
                                        .padding(.horizontal, 14)
                                }
                                .accessibilityIdentifier("groups.open.\(app.name)")

                                if app.id != collection.orderedApps.last?.id {
                                    Divider()
                                        .padding(.leading, 64)
                                        .padding(.trailing, 14)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .groupCardSurface()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .buttonStyle(.plain)
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .primaryAction) {
                    glassEditButton
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .primaryAction) {
                    fallbackEditButton
                }
            }
        }
    }

    @available(iOS 26.0, *)
    private var glassEditButton: some View {
        GlassEffectContainer(spacing: 0) {
            Button(action: edit) {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Edit Group")
            .accessibilityIdentifier("groups.detail.edit")
        }
    }

    private var fallbackEditButton: some View {
        Button(action: edit) {
            Image(systemName: "pencil")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.accentColor, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit Group")
        .accessibilityIdentifier("groups.detail.edit")
    }
}

private struct AppGroupMemberRow: View {
    let app: LiteApp

    var body: some View {
        HStack(spacing: 12) {
            ProfileBadgedAppIconView(
                data: app.iconData,
                websiteURL: app.url,
                symbol: app.iconSymbol,
                color: app.iconColor,
                size: 38,
                profileName: LiteAppGrouping.profileName(for: app)
            )
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name).foregroundStyle(.primary)
                Text(app.url.host ?? "Website")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if app.isBiometricLocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Locked")
            }
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
    }
}

private struct AppGroupEditorView: View {
    @Environment(ProStore.self) private var pro
    @State private var proFeature: ProFeature?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\LiteApp.sortOrder), SortDescriptor(\LiteApp.createdAt)])
    private var apps: [LiteApp]
    @Query private var collections: [LiteAppCollection]
    @State private var name: String
    @State private var selectedAppIDs: Set<UUID>
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool

    let collection: LiteAppCollection?

    init(collection: LiteAppCollection? = nil) {
        self.collection = collection
        _name = State(initialValue: collection?.name ?? "")
        _selectedAppIDs = State(initialValue: Set(collection?.apps.map(\.id) ?? []))
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 40 && selectedAppIDs.count >= 2
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Group Name", text: $name)
                        .focused($isNameFocused)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit { if canSave { save() } }
                        .accessibilityIdentifier("groups.editor.name")
                } footer: {
                    Text("Choose a short name such as Work, Social, or Shopping.")
                }

                Section {
                    ForEach(apps) { app in
                        AppGroupSelectionRow(
                            app: app,
                            isSelected: selectedAppIDs.contains(app.id),
                            toggle: { toggle(app.id) }
                        )
                    }
                } header: {
                    Text("Apps")
                } footer: {
                    Text("Select at least two apps. Grouping never combines their accounts or website data.")
                }
            }
            .navigationTitle(collection == nil ? "New Group" : "Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("groups.editor.save")
                }
            }
            .alert(
                "Couldn’t Save Group",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .task { isNameFocused = collection == nil }
            .sheet(item: $proFeature) { ProPaywallView(feature: $0) }
        }
    }

    private func toggle(_ id: UUID) {
        if selectedAppIDs.contains(id) {
            selectedAppIDs.remove(id)
        } else {
            selectedAppIDs.insert(id)
        }
    }

    private func save() {
        guard canSave else { return }
        if collection == nil {
            do { try pro.requireGroupSlot(in: context) }
            catch let feature as ProFeature { isNameFocused = false; proFeature = feature; return }
            catch { errorMessage = "Your groups couldn’t be checked."; return }
        }
        let selectedApps = apps.filter { selectedAppIDs.contains($0.id) }
        if let collection {
            collection.name = trimmedName
            collection.apps = selectedApps
        } else {
            let nextOrder = (collections.map(\.sortOrder).max() ?? -1) + 1
            context.insert(LiteAppCollection(name: trimmedName, apps: selectedApps, sortOrder: nextOrder))
        }
        do {
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            errorMessage = "Your group couldn’t be saved. Please try again."
        }
    }
}

private struct AppGroupSelectionRow: View {
    let app: LiteApp
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                ProfileBadgedAppIconView(
                    data: app.iconData,
                    websiteURL: app.url,
                    symbol: app.iconSymbol,
                    color: app.iconColor,
                    size: 40,
                    profileName: LiteAppGrouping.profileName(for: app)
                )
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name).foregroundStyle(.primary)
                    Text(app.url.host ?? "Website")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(app.name)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("groups.editor.app.\(app.name)")
    }
}

private enum AppGroupSheet: Identifiable {
    case create
    case edit(LiteAppCollection)
    case details(LiteAppCollection)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let collection): "edit-\(collection.id)"
        case .details(let collection): "details-\(collection.id)"
        }
    }
}

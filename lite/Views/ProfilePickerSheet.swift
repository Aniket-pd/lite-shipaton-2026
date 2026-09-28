import SwiftData
import SwiftUI

struct ProfilePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppOpenCoordinator.self) private var openCoordinator
    @Query private var apps: [LiteApp]

    let groupID: String
    @State private var path: [ProfilePickerRoute]
    @State private var secondarySheet: ProfileSecondarySheet?
    @State private var appToDelete: LiteApp?
    @State private var errorMessage: String?
    @State private var biometrics = BiometricService()
    @State private var lockChangeAppID: UUID?
    @State private var isDeleting = false

    init(groupID: String, startsAdding: Bool = false) {
        self.groupID = groupID
        _path = State(initialValue: startsAdding ? [.add] : [])
    }

    private var group: LiteAppGroup? {
        LiteAppGrouping.groups(from: apps).first(where: { $0.id == groupID })
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let group {
                    profileList(group)
                } else {
                    ContentUnavailableView(
                        "Website Not Found",
                        systemImage: "questionmark.app",
                        description: Text("Its profiles may have been removed.")
                    )
                }
            }
            .navigationTitle(group?.websiteName ?? "Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ProfilePickerRoute.self) { route in
                switch route {
                case .add:
                    AddProfileView(groupID: groupID)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $secondarySheet) { sheet in
            switch sheet {
            case .edit(let app):
                EditAppView(app: app)
            case .details(let app):
                ContainerDetailsSheet(app: app)
            }
        }
        .confirmationDialog("Delete Profile?", isPresented: Binding(
            get: { appToDelete != nil },
            set: { if !$0 { appToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: deleteProfile)
        } message: {
            let profile = appToDelete.map {
                LiteAppGrouping.profileName(for: $0, websiteName: group?.websiteName ?? "")
            } ?? "this profile"
            Text("Delete \(profile), its bookmarks, downloads, sign-in and website data? Copies exported to Files and other profiles won’t be affected.")
        }
        .alert("Something needs attention", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onDisappear { biometrics.cancel() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { biometrics.cancel() }
        }
    }

    private func profileList(_ group: LiteAppGroup) -> some View {
        List {
            Section("Profiles") {
                ForEach(group.apps) { app in
                    ProfilePickerRow(
                        name: group.profileName(for: app),
                        iconData: app.iconData,
                        websiteURL: app.url,
                        iconSymbol: app.iconSymbol,
                        iconColor: app.iconColor,
                        badgeColor: app.iconColor,
                        isFavorite: app.isFavorite,
                        isLocked: app.isBiometricLocked,
                        biometricLabel: biometrics.label,
                        open: { open(app) },
                        edit: { secondarySheet = .edit(app) },
                        details: { secondarySheet = .details(app) },
                        toggleFavorite: { toggleFavorite(app) },
                        toggleLock: { Task { await toggleLock(app) } },
                        delete: { appToDelete = app }
                    )
                    .disabled(isDeleting)
                }
            }
        }
    }

    private func open(_ app: LiteApp) {
        app.lastOpenedAt = .now
        do {
            try context.save()
        } catch {
            context.rollback()
            errorMessage = "The selected profile couldn’t be remembered. Please try again."
            return
        }
        dismiss()
        openCoordinator.open(app.id)
    }

    private func toggleFavorite(_ app: LiteApp) {
        app.isFavorite.toggle()
        do { try context.save() }
        catch {
            context.rollback()
            errorMessage = "Your favorite setting couldn’t be saved."
        }
    }

    private func toggleLock(_ app: LiteApp) async {
        guard lockChangeAppID == nil else { return }
        let appID = app.id
        let wasLocked = app.isBiometricLocked
        lockChangeAppID = appID
        defer { if lockChangeAppID == appID { lockChangeAppID = nil } }

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
        app.isBiometricLocked.toggle()
        do { try context.save() }
        catch {
            context.rollback()
            errorMessage = "The lock setting couldn’t be saved. Please try again."
        }
    }

    private func deleteProfile() {
        guard let app = appToDelete else { return }
        let deletesLastProfile = group?.apps.count == 1
        appToDelete = nil
        do {
            try ProfileDeletionService.delete(app, in: context)
            if deletesLastProfile { dismiss() }
            isDeleting = true
            Task {
                defer { isDeleting = false }
                do { try await ProfileDeletionService.finishPendingDeletions(in: context) }
                catch { errorMessage = "The profile was removed. Its website data will be cleared the next time Lite opens." }
            }
        } catch {
            errorMessage = "The profile couldn’t be deleted. Please try again."
        }
    }
}

struct ProfilePickerRow: View {
    let name: String
    let iconData: Data?
    let websiteURL: URL
    let iconSymbol: String
    let iconColor: String
    let badgeColor: String
    let isFavorite: Bool
    let isLocked: Bool
    let biometricLabel: String
    let open: () -> Void
    let edit: () -> Void
    let details: () -> Void
    let toggleFavorite: () -> Void
    let toggleLock: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: open) {
                HStack(spacing: 12) {
                    ProfileBadgedAppIconView(
                        data: iconData,
                        websiteURL: websiteURL,
                        symbol: iconSymbol,
                        color: iconColor,
                        badgeColor: badgeColor,
                        size: 44,
                        profileName: name
                    )
                    .accessibilityHidden(true)
                    Text(name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .accessibilityHidden(true)
                    }
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name)
            .accessibilityValue(accessibilityValue)
            .accessibilityHint("Opens this profile")
            .accessibilityIdentifier("profiles.profile.\(name)")

            Menu {
                Button("App Settings", systemImage: "slider.horizontal.3", action: details)
                Button("Edit Profile", systemImage: "pencil", action: edit)
                Button(
                    isLocked ? "Unlock Profile" : "Require \(biometricLabel)",
                    systemImage: isLocked ? "lock.open" : "faceid",
                    action: toggleLock
                )
                Button(
                    isFavorite ? "Remove Favorite" : "Favorite",
                    systemImage: isFavorite ? "star.slash" : "star",
                    action: toggleFavorite
                )
                Divider()
                Button("Delete Profile", systemImage: "trash", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(minWidth: 36, minHeight: 36)
                    .contentShape(.rect)
            }
            .accessibilityLabel("More actions for \(name)")
        }
        .padding(.vertical, 3)
    }

    private var accessibilityValue: String {
        [isFavorite ? "Favorite" : nil, isLocked ? "Locked" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

private struct AddProfileView: View {
    @Environment(ProStore.self) private var pro
    @State private var proFeature: ProFeature?
    @Environment(\.modelContext) private var context
    @Environment(AppOpenCoordinator.self) private var openCoordinator
    @Query private var apps: [LiteApp]
    let groupID: String
    @State private var profileName = ""
    @State private var errorMessage: String?
    @State private var isSaving = false
    @FocusState private var isNameFocused: Bool

    private var group: LiteAppGroup? {
        LiteAppGrouping.groups(from: apps).first(where: { $0.id == groupID })
    }

    private var trimmedName: String {
        profileName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicateName: Bool {
        guard let group else { return false }
        return group.apps.contains {
            group.profileName(for: $0).compare(
                trimmedName,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
        }
    }

    var body: some View {
        Form {
            if let group {
                Section {
                    VStack(spacing: 10) {
                        AppIconView(
                            data: group.iconApp.iconData,
                            websiteURL: group.iconApp.url,
                            symbol: group.iconApp.iconSymbol,
                            size: 64
                        )
                        Text(group.websiteName)
                            .font(.title3.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Personal, Work, Aniket…", text: $profileName)
                        .textInputAutocapitalization(.words)
                        .textContentType(.nickname)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit(addProfile)
                        .accessibilityLabel("Profile name")
                        .accessibilityIdentifier("profiles.name")
                } header: {
                    Text("Profile Name")
                } footer: {
                    if isDuplicateName {
                        Text("Choose a different profile name.").foregroundStyle(.red)
                    } else {
                        Text("The website is already set. Only name the separate profile you’re adding.")
                    }
                }
                Section {
                    Label("Separate sign-in and cookies", systemImage: "person.crop.circle.badge.checkmark")
                    Label("Separate permissions and settings", systemImage: "slider.horizontal.3")
                } header: {
                    Text("Private by Profile")
                }
            } else {
                ContentUnavailableView("Website Not Found", systemImage: "questionmark.app")
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .disabled(isSaving)
        .navigationTitle("Add Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add", action: addProfile)
                    .fontWeight(.semibold)
                    .disabled(!canAdd)
                    .accessibilityIdentifier("profiles.create")
            }
        }
        .interactiveDismissDisabled(isSaving)
        .onAppear { isNameFocused = true }
        .sheet(item: $proFeature) { ProPaywallView(feature: $0) }
    }

    private var canAdd: Bool {
        group != nil && !trimmedName.isEmpty && trimmedName.count <= 40 && !isDuplicateName && !isSaving
    }

    private func addProfile() {
        guard canAdd, let group else { return }
        do { try pro.requireAppSlot(in: context) }
        catch let feature as ProFeature { isNameFocused = false; proFeature = feature; return }
        catch { errorMessage = "Your library couldn’t be checked."; return }
        isSaving = true
        let copy = group.lastUsedApp.duplicate(accountName: trimmedName)
        copy.sortOrder = (apps.map(\.sortOrder).max() ?? -1) + 1
        copy.lastOpenedAt = .now
        context.insert(copy)
        do {
            try context.save()
            openCoordinator.open(copy.id)
        } catch {
            context.rollback()
            isSaving = false
            errorMessage = "The profile couldn’t be added. Please try again."
        }
    }
}

private enum ProfilePickerRoute: Hashable {
    case add
}

private enum ProfileSecondarySheet: Identifiable {
    case edit(LiteApp)
    case details(LiteApp)

    var id: String {
        switch self {
        case .edit(let app): "edit-\(app.id)"
        case .details(let app): "details-\(app.id)"
        }
    }
}

import SwiftData
import SwiftUI

struct EditAppView: View {
    @Environment(ProStore.self) private var pro
    @State private var proFeature: ProFeature?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    let app: LiteApp
    @State private var name = ""
    @State private var iconData: Data?
    @State private var iconURL: URL?
    @State private var iconMessage: String?
    @State private var isRefreshingIcon = false
    @State private var iconTask: Task<Void, Never>?
    @State private var address = ""
    @State private var symbol = "globe"
    @State private var color = "blue"
    @State private var useWebsiteIcon = true
    @State private var locked = false
    @State private var favorite = false
    @State private var visibleInWidget = false
    @State private var launchPage: LaunchPagePreference = .start
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var biometrics = BiometricService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        ProfileBadgedAppIconView(
                            data: useWebsiteIcon ? matchingIconData : nil,
                            websiteURL: editedURL,
                            symbol: symbol,
                            color: color,
                            size: 52,
                            profileName: trimmedName.isEmpty ? "Profile" : trimmedName
                        )
                        TextField("App name", text: $name)
                            .textInputAutocapitalization(.words)
                            .accessibilityIdentifier("edit.name")
                    }
                } header: { Text("Name") }

                Section {
                    TextField("https://example.com", text: $address)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("edit.url")
                    Picker("When Opening", selection: $launchPage) {
                        ForEach(LaunchPagePreference.allCases) { preference in
                            Text(preference.title).tag(preference)
                        }
                    }
                } header: { Text("Starting Website") } footer: {
                    Text("Continue Last Page skips sign-in pages, form submissions, and addresses containing query parameters. If no suitable page is saved, Lite opens the start page.")
                }

                Section("App icon") {
                    ProfileIconPicker(
                        useWebsiteIcon: $useWebsiteIcon,
                        symbol: $symbol,
                        iconData: matchingIconData,
                        websiteURL: editedURL,
                        websiteName: editedURL.map { LiteAppGrouping.suggestedWebsiteName(for: $0) } ?? "Website",
                        isFetchingIcon: isRefreshingIcon,
                        identifierPrefix: "edit"
                    )
                    Button {
                        iconTask = Task { await refreshIcon() }
                    } label: {
                        HStack {
                            Text("Refresh icon")
                            if isRefreshingIcon { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isRefreshingIcon || isSaving || editedURL == nil)
                    .accessibilityIdentifier("edit.refreshIcon")
                    if let iconMessage {
                        Text(iconMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("Badge color") {
                    BadgeColorPicker(color: $color, identifierPrefix: "edit")
                }

                Section("Library") {
                    Toggle("Favorite", isOn: $favorite)
                    Toggle("Show in Favorites Widget", isOn: $visibleInWidget)
                }

                Section {
                    Toggle("Require \(biometrics.label)", isOn: $locked)
                } footer: {
                    Text("Unlock before opening this app. It locks again when Lite goes into the background.")
                }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .navigationTitle("Edit Lite App").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(trimmedName.isEmpty || trimmedName.count > 40 || trimmedAddress.isEmpty || isSaving || isRefreshingIcon)
                        .accessibilityIdentifier("edit.save")
                }
            }
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .interactiveDismissDisabled(isSaving)
        .onAppear(perform: load)
        .onChange(of: editedURL) {
            if matchingIconData == nil { useWebsiteIcon = false }
        }
        .onDisappear { biometrics.cancel(); iconTask?.cancel() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { biometrics.cancel() } }
        .sheet(item: $proFeature) { ProPaywallView(feature: $0) }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedAddress: String { address.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var editedURL: URL? { try? WebsiteURL.normalized(trimmedAddress) }
    private var matchingIconData: Data? {
        guard let iconURL, let editedURL, FaviconDiscovery.sameOrigin(iconURL, editedURL) else { return nil }
        return iconData
    }

    private func load() {
        iconData = app.iconData
        iconURL = app.url
        name = app.name
        address = app.url.absoluteString
        symbol = app.iconSymbol
        color = app.iconColor
        useWebsiteIcon = app.iconData != nil
        locked = app.isBiometricLocked
        favorite = app.isFavorite
        visibleInWidget = app.isVisibleInWidget
        launchPage = app.launchPagePreference
    }

    private func refreshIcon() async {
        guard !isRefreshingIcon, let requestedURL = editedURL else { return }
        isRefreshingIcon = true
        iconMessage = nil
        defer { isRefreshingIcon = false }
        let refreshed: Data?
        if let bundled = CatalogIcon.data(for: requestedURL) {
            refreshed = bundled
        } else {
            do {
                let configurations = try ContainerProxy(app: app).configuration(profile: app.dataStoreIdentifier)
                refreshed = await FaviconService(proxyConfigurations: configurations).fetch(for: requestedURL)
            } catch {
                iconMessage = error.localizedDescription
                return
            }
        }
        guard !Task.isCancelled, editedURL == requestedURL else { return }
        if let refreshed {
            if CatalogIcon.assetName(for: requestedURL) == nil, let current = matchingIconData,
               FaviconService.pixelSize(of: current) > FaviconService.pixelSize(of: refreshed) {
                iconMessage = "Your current icon is sharper. It has been kept."
                return
            }
            iconURL = requestedURL
            iconData = refreshed
            useWebsiteIcon = true
            iconMessage = "Icon refreshed. Save to keep it."
        } else if let current = matchingIconData, FaviconService.pixelSize(of: current) >= FaviconService.minimumPixelSize {
            iconMessage = "No better icon was available. Your current icon is unchanged."
        } else {
            iconData = nil
            useWebsiteIcon = false
            iconMessage = "No sharp website icon found. A symbol will be used."
        }
    }

    private func save() async {
        guard !isSaving, !isRefreshingIcon else { return }
        let normalizedURL: URL
        do { normalizedURL = try WebsiteURL.normalized(trimmedAddress) }
        catch { errorMessage = error.localizedDescription; return }

        isSaving = true
        defer { isSaving = false }
        if locked || app.isBiometricLocked {
            do { try await biometrics.authenticate(reason: "Save changes to \(app.name).") }
            catch { errorMessage = BiometricService.message(for: error); return }
        }
        guard scenePhase != .background else { return }
        do { try pro.requireAppearance(symbol: symbol, color: color, existing: app) }
        catch let feature as ProFeature { proFeature = feature; return }
        catch { errorMessage = "Your changes couldn’t be checked."; return }
        let previousURL = app.url
        app.name = trimmedName
        app.url = normalizedURL
        app.iconSymbol = symbol
        app.iconColor = color
        app.iconData = useWebsiteIcon ? (matchingIconData ?? CatalogIcon.data(for: normalizedURL)) : nil
        app.isBiometricLocked = locked
        app.isFavorite = favorite
        app.isVisibleInWidget = visibleInWidget
        app.launchPagePreference = launchPage
        if previousURL != normalizedURL { app.lastPageURL = nil }
        do { try context.save(); dismiss() }
        catch { context.rollback(); errorMessage = "Your changes couldn’t be saved. Please try again." }
    }
}

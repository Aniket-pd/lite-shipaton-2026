import SwiftData
import SwiftUI

struct ContainerDetailsSheet: View {
    let app: LiteApp
    var opensPrivacy = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ContainerAccessView(app: app) {
            NavigationStack {
                if opensPrivacy {
                    ContainerPreferencesView(app: app, privacyOnly: true)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { dismiss() }.accessibilityIdentifier("container.done")
                            }
                        }
                } else {
                    ContainerDetailsView(app: app)
                }
            }
        }
    }
}

private enum ContainerRoute: Hashable {
    case preferences, privacy, proxy, data, diagnostics
}

private struct ContainerDetailsView: View {
    @Environment(ProStore.self) private var pro
    @State private var proFeature: ProFeature?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var apps: [LiteApp]
    let app: LiteApp
    @State private var editing = false
    @State private var biometrics = BiometricService()
    @State private var errorMessage: String?
    @State private var domainCount: Int?
    @State private var notice: String?

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    AppIconView(data: app.iconData, websiteURL: app.url, symbol: app.iconSymbol, size: 60)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(app.name).font(.title3.bold())
                        Text(app.url.host ?? app.url.absoluteString).foregroundStyle(.secondary)
                        Label("Isolated website data", systemImage: "checkmark.shield.fill")
                            .font(.caption).foregroundStyle(.green)
                    }
                }.padding(.vertical, 8)
            }
            Section {
                LabeledContent("Last connection", value: connectionSummary)
                LabeledContent("Last opened", value: app.lastOpenedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Not recorded yet")
                LabeledContent("Created", value: app.createdAt.formatted(date: .abbreviated, time: .omitted))
            } header: { Text("Overview") } footer: {
                Text("Connection information comes from the last completed page load.")
            }
            Section("Settings") {
                route(.preferences, title: "Browsing", symbol: "gearshape", detail: "\(app.websiteLayout.title) · \(Int((app.effectivePageZoom * 100).rounded()))% zoom")
                    .accessibilityIdentifier("container.preferences")
                route(.privacy, title: "Privacy & permissions", symbol: "hand.raised", detail: app.isBlockingEnabled ? "Protection enabled" : "Protection disabled")
                    .accessibilityIdentifier("container.privacy")
                route(.proxy, title: "Encrypted proxy", symbol: "network", detail: app.isProxyEnabled ? "Configured · HTTPS CONNECT" : "Off")
                    .accessibilityIdentifier("container.proxy")
                route(.data, title: "Website data", symbol: "externaldrive", detail: domainCount.map { "\($0) website records" } ?? "Inspect stored data")
                    .accessibilityIdentifier("container.data")
                route(.diagnostics, title: "Diagnostics", symbol: "waveform.path.ecg", detail: "Connection and load details")
                    .accessibilityIdentifier("container.diagnostics")
            }
            Section {
                Toggle("Require \(biometrics.label)", isOn: Binding(
                    get: { app.isBiometricLocked },
                    set: { value in Task { await changeLock(to: value) } }
                ))
                .disabled(biometrics.isAuthenticating)
            } footer: { Text("Locks when Lite goes into the background. Changing the lock requires biometric authentication.") }
            Section {
                Button("Create Another Account", systemImage: "person.crop.circle.badge.plus", action: duplicate)
                if let notice { Text(notice).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("App Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("container.done") }
            ToolbarItem(placement: .primaryAction) { Button("Edit") { editing = true } }
        }
        .navigationDestination(for: ContainerRoute.self) { route in
            switch route {
            case .preferences: ContainerPreferencesView(app: app)
            case .privacy: ContainerPreferencesView(app: app, privacyOnly: true)
            case .proxy: ContainerProxyView(app: app)
            case .data: ContainerWebsiteDataView(app: app)
            case .diagnostics: ContainerDiagnosticsView(app: app)
            }
        }
        .sheet(item: $proFeature) { ProPaywallView(feature: $0) }
        .sheet(isPresented: $editing) { EditAppView(app: app) }
        .task {
            let records = await ContainerWebsiteData.records(for: app.dataStoreIdentifier)
            guard !Task.isCancelled else { return }
            domainCount = records.count
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { biometrics.cancel(); editing = false }
        }
        .onDisappear { biometrics.cancel() }
        .alert("Couldn’t Save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var connectionSummary: String {
        guard let secure = app.lastConnectionSecure else { return "Not recorded yet" }
        return secure ? "Encrypted" : "Not fully encrypted"
    }

    private func route(_ route: ContainerRoute, title: String, symbol: String, detail: String) -> some View {
        NavigationLink(value: route) {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            } icon: { Image(systemName: symbol).foregroundStyle(.blue) }
            .padding(.vertical, 3)
        }
    }

    private func changeLock(to enabled: Bool) async {
        do {
            try await biometrics.authenticate(reason: "Change the lock for \(app.name).")
            guard scenePhase != .background else { return }
            app.isBiometricLocked = enabled
            do { try context.save() }
            catch { app.isBiometricLocked = !enabled; throw error }
        } catch { errorMessage = BiometricService.message(for: error) }
    }

    private func duplicate() {
        do { try pro.requireAppSlot(in: context) }
        catch let feature as ProFeature { proFeature = feature; return }
        catch { errorMessage = "Your library couldn’t be checked."; return }
        let copy = app.duplicate(accountName: app.nextAccountName(in: apps))
        copy.sortOrder = (apps.map(\.sortOrder).max() ?? -1) + 1
        context.insert(copy)
        do {
            try context.save()
            notice = "\(copy.name) was added to your library with a fresh website session."
            if copy.isProxyEnabled, !copy.proxyUsername.isEmpty {
                notice = (notice ?? "") + " Enter its proxy password in App Settings before browsing."
            }
        }
        catch { context.rollback(); errorMessage = "The additional account couldn’t be created." }
    }
}

struct ContainerPreferencesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    let app: LiteApp
    var privacyOnly = false
    @State private var preparingProtection = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Text(app.name).font(.headline)
                Text("Changes apply the next time you open this Lite App.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if !privacyOnly {
                Section {
                    Picker("Open to", selection: saved(\.launchPagePreference)) {
                        ForEach(LaunchPagePreference.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Website layout", selection: saved(\.websiteLayout)) {
                        ForEach(WebsiteLayout.allCases) { Text($0.title).tag($0) }
                    }.accessibilityIdentifier("preferences.layout")
                    Stepper(value: saved(\.pageZoom), in: 0.75...2.0, step: 0.05) {
                        LabeledContent("Page zoom", value: "\(Int((app.effectivePageZoom * 100).rounded()))%")
                    }.accessibilityIdentifier("preferences.zoom")
                    if app.effectivePageZoom != 1 { Button("Reset Zoom") { saved(\.pageZoom).wrappedValue = 1 } }
                } header: { Text("Browsing") } footer: {
                    Text("Continue Last Page skips sign-in pages and addresses with query parameters.")
                }
            }
            if privacyOnly {
                Section {
                    Toggle("Ad & tracker blocking", isOn: Binding(get: { app.isBlockingEnabled }, set: { value in
                        Task { await changeProtection(value) }
                    }))
                    .disabled(preparingProtection)
                    .accessibilityIdentifier("preferences.protection")
                    if preparingProtection { ProgressView("Preparing protection…") }
                } header: { Text("Privacy") } footer: {
                    Text("Blocks known ads and trackers. Some ads may remain. Try turning this off if a website breaks.")
                }
                Section {
                    Picker("Camera", selection: saved(\.cameraPermission)) {
                        ForEach(WebsitePermission.allCases) { Text($0.title).tag($0) }
                    }.accessibilityIdentifier("preferences.camera")
                    Picker("Microphone", selection: saved(\.microphonePermission)) {
                        ForEach(WebsitePermission.allCases) { Text($0.title).tag($0) }
                    }.accessibilityIdentifier("preferences.microphone")
                } header: { Text("Website permissions") } footer: {
                    Text("Ask lets websites request consent. Block denies requests for this Lite App. Your iPhone’s permissions also apply.")
                }
            }
            if !privacyOnly {
                Section {
                    Picker("Autoplay", selection: saved(\.requiresMediaGesture)) {
                        Text("Require a Tap").tag(true)
                        Text("Allow").tag(false)
                    }.accessibilityIdentifier("preferences.autoplay")
                } header: { Text("Media") } footer: { Text("Allow permits autoplay where the website and iOS support it.") }
                Section {
                    NavigationLink("Advanced") {
                        Form {
                            Section {
                                Toggle("JavaScript", isOn: saved(\.allowsJavaScript))
                                    .accessibilityIdentifier("preferences.javascript")
                            } footer: { Text("Most web apps need JavaScript to work. Disabling it can prevent sign-in and other features.") }
                            Section {
                                Toggle("Allow Website Windows", isOn: saved(\.allowsPopups))
                                    .accessibilityIdentifier("preferences.popups")
                            } footer: { Text("Windows wait for you to choose Open or Dismiss. Blocking them can prevent sign-in. Automatic popups remain blocked.") }
                            if !app.automaticWindowOrigins.isEmpty {
                                Section {
                                    ForEach(app.automaticWindowOrigins, id: \.self) { origin in
                                        VStack(alignment: .leading) {
                                            Text(origin).font(.footnote)
                                            Button("Ask before opening windows") {
                                                saved(\.automaticWindowOrigins).wrappedValue = app.automaticWindowOrigins.filter { $0 != origin }
                                            }
                                        }
                                    }
                                } header: { Text("Allowed website windows") } footer: {
                                    Text("These websites can open windows without asking in this Lite App. Ad blocking still applies.")
                                }
                            }
                        }
                        .navigationTitle("Advanced")
                        .navigationBarTitleDisplayMode(.inline)
                    }.accessibilityIdentifier("preferences.advanced")
                }
            }
        }
        .navigationTitle(privacyOnly ? "Privacy & Permissions" : "Browsing")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn’t Save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func saved<Value>(_ path: ReferenceWritableKeyPath<LiteApp, Value>) -> Binding<Value> {
        Binding(get: { app[keyPath: path] }, set: { value in
            guard scenePhase == .active else { return }
            let previous = app[keyPath: path]
            app[keyPath: path] = value
            do { try context.save() }
            catch { app[keyPath: path] = previous; errorMessage = "Your setting couldn’t be saved. Please try again." }
        })
    }

    private func changeProtection(_ enabled: Bool) async {
        guard !preparingProtection else { return }
        preparingProtection = true
        defer { preparingProtection = false }
        if enabled {
            do { _ = try await ContentBlocker.rules() }
            catch { errorMessage = "Protection couldn’t be prepared. Your setting hasn’t changed."; return }
        }
        saved(\.isBlockingEnabled).wrappedValue = enabled
    }
}

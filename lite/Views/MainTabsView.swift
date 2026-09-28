import SwiftData
import SwiftUI

// A device preference; it never changes a saved website profile.
enum LiteAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

private enum SettingsRoute: Hashable {
    case appearance, manage, apps, privacy, widgets, help, about
}

struct SettingsView: View {
    @Environment(ProStore.self) private var pro
    @State private var showPro = false
    @Environment(\.dismiss) private var dismiss
    let apps: [LiteApp]
    @AppStorage("lite.appearance") private var appearance: LiteAppearance = .system

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showPro = true } label: {
                        SettingsProCard(isPro: pro.isPro)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("settings.pro")
                }
                Section("Personalize") {
                    NavigationLink(value: SettingsRoute.appearance) {
                        SettingsRow(title: "Appearance", systemImage: "circle.lefthalf.filled", tint: .purple, value: appearance.title)
                    }
                    .accessibilityIdentifier("settings.appearance")
                    NavigationLink(value: SettingsRoute.manage) {
                        SettingsRow(title: "Organize Library", systemImage: "line.3.horizontal", tint: .orange)
                    }
                    .accessibilityIdentifier("settings.manageLibrary")
                    NavigationLink(value: SettingsRoute.widgets) {
                        SettingsRow(title: "Widgets & Shortcuts", systemImage: "rectangle.3.group", tint: .blue)
                    }
                    .accessibilityIdentifier("settings.widgets")
                }
                Section {
                    NavigationLink(value: SettingsRoute.apps) {
                        SettingsRow(title: "App Settings", subtitle: "Browsing, permissions, and website data", systemImage: "slider.horizontal.3", tint: .indigo, value: apps.count.formatted())
                    }
                    .accessibilityIdentifier("settings.apps")
                    NavigationLink(value: SettingsRoute.privacy) {
                        SettingsRow(title: "Privacy & Permissions", subtitle: privacySummary, systemImage: "hand.raised", tint: .green)
                    }
                    .accessibilityIdentifier("settings.privacy")
                } header: { Text("Your Lite Apps") } footer: {
                    Text("Each Lite App has its own sign-ins and website data.")
                }
                Section("Help & About") {
                    NavigationLink(value: SettingsRoute.help) {
                        SettingsRow(title: "Help & Troubleshooting", systemImage: "questionmark.circle", tint: .teal)
                    }
                    .accessibilityIdentifier("settings.help")
                    NavigationLink(value: SettingsRoute.about) {
                        SettingsRow(title: "About Lite", systemImage: "info.circle", tint: .gray)
                    }
                    .accessibilityIdentifier("settings.about")
                }
            }
            .buttonStyle(.plain)
            .navigationTitle("Settings")
            .accessibilityIdentifier("settings.screen")
            .toolbar { dismissToolbar }
            .sheet(isPresented: $showPro) { ProPaywallView() }
            .navigationDestination(for: SettingsRoute.self) { route in
                Group {
                    switch route {
                    case .appearance: AppearanceSettingsView()
                    case .manage: LibraryManagementView()
                    case .apps: SettingsAppListView()
                    case .privacy: PrivacySettingsView()
                    case .widgets: WidgetSettingsView()
                    case .help: SettingsHelpView()
                    case .about: AboutLiteView()
                    }
                }
                .toolbar { dismissToolbar }
            }
        }
    }

    @ToolbarContentBuilder
    private var dismissToolbar: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
                .accessibilityIdentifier("settings.done")
        }
    }

    private var privacySummary: String {
        guard !apps.isEmpty else { return "Blocking, app locks, camera, and microphone" }
        return "Blocking on for \(apps.filter(\.isBlockingEnabled).count) of \(apps.count) apps"
    }
}

private struct SettingsRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    var tint: Color = .blue
    var value: String? = nil
    var showsChevron = false

    var body: some View {
        HStack(spacing: 12) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14), in: .circle)
                    .overlay {
                        Circle()
                            .strokeBorder(tint.opacity(0.18), lineWidth: 0.5)
                    }
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let value { Text(value).foregroundStyle(.secondary) }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
    }
}

private struct SettingsProCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var typeSize
    let isPro: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "bolt.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(.blue.gradient, in: .rect(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("Lite Pro").font(.headline).foregroundStyle(.primary)
                Text(isPro ? "Your plan and purchases" : "More room for every account.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if typeSize.isAccessibilitySize { badge }
            }
            Spacer(minLength: 0)
            if !typeSize.isAccessibilitySize { badge }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(LinearGradient(colors: [.blue.opacity(colorScheme == .dark ? 0.2 : 0.1), .cyan.opacity(0.04)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(.blue.opacity(contrast == .increased ? 0.65 : 0.22), lineWidth: 1)
                }
        }
        .contentShape(.rect(cornerRadius: 22))
    }

    private var badge: some View {
        Text(isPro ? "Active" : "Upgrade")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.blue, in: .capsule)
    }
}

private struct AppearanceSettingsView: View {
    @AppStorage("lite.appearance") private var appearance: LiteAppearance = .system
    @AppStorage("lite.atmosphericBackground") private var atmosphericBackground = true
    @AppStorage("lite.showsLibraryAppNames") private var showsLibraryAppNames = true

    var body: some View {
        List {
            Section {
                ForEach(LiteAppearance.allCases) { option in
                    Button {
                        appearance = option
                    } label: {
                        HStack {
                            Text(option.title).foregroundStyle(.primary)
                            Spacer()
                            if appearance == option {
                                Image(systemName: "checkmark").foregroundStyle(.blue)
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .accessibilityIdentifier("appearance.\(option.rawValue)")
                    .accessibilityAddTraits(appearance == option ? .isSelected : [])
                }
            } footer: {
                Text("System follows your iPhone’s appearance. This changes Lite’s interface; websites may use their own theme.")
            }
            Section {
                Toggle("Show App Names", isOn: $showsLibraryAppNames)
                    .accessibilityIdentifier("appearance.appNames")
                Toggle("Atmospheric Background", isOn: $atmosphericBackground)
                    .accessibilityIdentifier("appearance.atmosphere")
            } header: {
                Text("App Background")
            } footer: {
                Text("App names can be hidden for a cleaner Library. The atmospheric background flows continuously behind the main views in dark mode; motion pauses with Reduce Motion or Low Power Mode.")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum SettingsAppFocus: String, Hashable {
    case all, blocking, locks, permissions
    var title: String {
        switch self {
        case .all: "App Settings"
        case .blocking: "Ad & Tracker Blocking"
        case .locks: "App Locks"
        case .permissions: "Website Permissions"
        }
    }
}

struct SettingsAppListView: View {
    @Query(sort: [SortDescriptor(\LiteApp.sortOrder), SortDescriptor(\LiteApp.createdAt)]) private var apps: [LiteApp]
    var focus: SettingsAppFocus = .all
    @State private var searchText = ""
    @State private var selectedApp: LiteApp?

    private var visibleApps: [LiteApp] {
        apps.filter {
            searchText.isEmpty || $0.name.localizedStandardContains(searchText) ||
            ($0.url.host?.localizedStandardContains(searchText) ?? false)
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(visibleApps) { app in
                    Button { selectedApp = app } label: {
                        HStack(spacing: 12) {
                            AppIconView(data: app.iconData, websiteURL: app.url, symbol: app.iconSymbol, size: 40)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(app.name).foregroundStyle(.primary)
                                Text(summary(for: app)).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: app.isBiometricLocked ? "lock.fill" : "chevron.right")
                                .font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
                        }
                        .padding(.vertical, 3)
                        .contentShape(.rect)
                    }
                    .accessibilityIdentifier("settings.app.\(app.name)")
                    .accessibilityHint(app.isBiometricLocked ? "Requires biometric authentication" : "Opens settings for this Lite App")
                }
            } footer: {
                if !apps.isEmpty { Text("Choose a Lite App to change its settings. Locked apps require Face ID or Touch ID.") }
            }
        }
        .buttonStyle(.plain)
        .overlay {
            if apps.isEmpty {
                ContentUnavailableView("No Lite Apps Yet", systemImage: "square.grid.2x2", description: Text("Add a website from Library or Discover to customize it here."))
            } else if visibleApps.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Lite Apps")
        .navigationTitle(focus.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedApp) { app in
            ContainerDetailsSheet(app: app, opensPrivacy: focus == .blocking || focus == .permissions)
        }
    }

    private func summary(for app: LiteApp) -> String {
        switch focus {
        case .all: app.url.host ?? "Website"
        case .blocking: app.isBlockingEnabled ? "Blocking on" : "Blocking off"
        case .locks: app.isBiometricLocked ? "Locked with biometrics" : "App lock off"
        case .permissions: "Camera: \(app.cameraPermission.title) · Microphone: \(app.microphonePermission.title)"
        }
    }
}

private struct PrivacySettingsView: View {
    @Query private var apps: [LiteApp]

    var body: some View {
        List {
            Section {
                NavigationLink(value: SettingsAppFocus.blocking) {
                    SettingsRow(title: "Ad & Tracker Blocking", subtitle: "On for \(apps.filter(\.isBlockingEnabled).count) of \(apps.count) apps", systemImage: "hand.raised", tint: .green)
                }
                .accessibilityIdentifier("privacy.blocking")
                NavigationLink(value: SettingsAppFocus.locks) {
                    SettingsRow(title: "App Locks", subtitle: "\(apps.filter(\.isBiometricLocked).count) of \(apps.count) apps locked", systemImage: "lock", tint: .orange)
                }
                .accessibilityIdentifier("privacy.locks")
                NavigationLink(value: SettingsAppFocus.permissions) {
                    SettingsRow(title: "Camera & Microphone", subtitle: "Review permissions for each app", systemImage: "camera", tint: .blue)
                }
                .accessibilityIdentifier("privacy.permissions")
            } footer: {
                Text("These summaries reflect your saved settings. Website permissions also depend on your iPhone’s permissions.")
            }
            Section {
                Label("Separate sign-ins for every Lite App", systemImage: "person.2")
                Text("Your library is saved on this device. Lite has no advertising SDKs. RevenueCat processes purchase information to manage Lite Pro; your browsing data stays outside the purchase service.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } header: { Text("Private by Design") }
        }
        .navigationTitle("Privacy & Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SettingsAppFocus.self) { SettingsAppListView(focus: $0) }
    }
}

struct SettingsHelpView: View {
    var body: some View {
        List {
            Section("Use Multiple Accounts") {
                Text("Open Settings → App Settings, choose a Lite App, then tap Create Another Account. Sign in to the new copy with a different account. Its sign-ins and website data stay separate.")
            }
            Section("Add a Widget or Shortcut") {
                Text("Choose apps in Settings → Widgets & Shortcuts. Touch and hold your iPhone’s Home Screen, choose Edit → Add Widget, then search for Lite.")
                Text("In Apple’s Shortcuts app, add the Open Lite App action and choose a saved app. Locked apps still require Face ID or Touch ID.")
            }
            Section("Trouble Signing In or Loading?") {
                Text("Open the app’s Privacy & Permissions and try turning off ad and tracker blocking, then reopen the app. You can turn blocking back on at any time.")
                Text("In Browsing → Advanced, keep JavaScript and website windows enabled for sign-in flows. Some providers restrict sign-in inside embedded browsers; Lite can’t override their rules.")
                Text("If a page still won’t load correctly, try Website Data → Clear Cache. This keeps cookies and sign-ins.")
            }
            Section("Browsing Preferences") {
                Text("Changes apply the next time you open the Lite App. Continue Last Page remembers suitable pages from the same website, skipping sign-in pages and addresses with query parameters. If no suitable page is available, the start page opens.")
                Text("Autoplay is still subject to the website and iOS. Camera and microphone set to Ask let websites request consent; Block denies requests for that Lite App.")
            }
            Section("Understand Website Data") {
                Text("Clear Cache removes downloaded resources. Clear All Website Data removes the app’s local website session and usually signs you out. Neither action deletes your account with the website.")
                Text("Removing a Lite App deletes its local website data. Other Lite Apps are unaffected. Website data is shown as records and data types because storage sizes aren’t available.")
            }
        }
        .navigationTitle("Help & Troubleshooting")
        .navigationBarTitleDisplayMode(.inline)
    }
}

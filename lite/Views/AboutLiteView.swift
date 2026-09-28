import SwiftUI

struct AboutLiteView: View {
    var body: some View {
        List {
            Section {
                Label("A home for the lighter version.", systemImage: "square.grid.2x2")
                    .font(.headline).padding(.vertical, 8)
                Text("Lite opens websites in their own spaces. Add the same website twice to use separate accounts.")
                LabeledContent("Version", value: Self.versionDescription)
                    .accessibilityIdentifier("about.version")
            }
            Section("Yours, on this device") {
                Label("Separate sign-ins for every Lite App", systemImage: "person.2")
                Label("Ad & tracker blocking by default", systemImage: "hand.raised")
                Label("Optional Face ID or Touch ID lock", systemImage: "lock")
                Label("Your library is saved locally", systemImage: "iphone")
            }
            Section {
                Text("Lite blocks known ad and tracker domains and common ad containers using a bundled HaGeZi PRO mini list. It doesn’t block every ad or all tracking. Turn blocking off for a specific container if a website doesn’t work correctly.")
                Text("Websites control their features and sign-in policies. Some services, including some Google sign-ins, may restrict embedded browsers. Lite can’t override those restrictions.")
                Text("Removing a Lite App also removes its website data. It doesn’t delete your account with the service.")
            } header: { Text("Good to know") }
            Section {
                Text("Catalog icons are included with Lite. Other icons are requested from the website and the image hosts it specifies, without your sign-in cookies. Lite has no advertising SDKs. RevenueCat processes purchase information to manage Lite Pro; your browsing data stays outside the purchase service.")
                NavigationLink("Privacy Details") { LitePrivacyView() }
            } header: { Text("Privacy") }
            Section("Ad blocker credits") {
                Text("HaGeZi Multi PRO mini • \(ContentBlocker.domains.count.formatted()) domains")
                Text(ContentBlocker.listVersion).font(.footnote).foregroundStyle(.secondary)
                Link("Blocklist source", destination: URL(string: "https://github.com/hagezi/dns-blocklists")!)
                NavigationLink("Blocklist license (GPL-3.0)") {
                    ScrollView {
                        Text(Self.blocklistLicense).font(.footnote).textSelection(.enabled).padding()
                    }
                    .navigationTitle("Blocklist license")
                }
            }
        }
        .navigationTitle("About Lite").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private static let blocklistLicense = Bundle.main.url(forResource: "AdBlockLicense", withExtension: "txt")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "License unavailable"

    private static var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}

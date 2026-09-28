import SwiftData
import SwiftUI

struct ContainerProxyView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    let app: LiteApp
    @State private var enabled = false
    @State private var host = ""
    @State private var port = "443"
    @State private var username = ""
    @State private var password = ""
    @State private var loaded = false
    @State private var message: String?
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case host, port, username, password }

    var body: some View {
        Form {
            Section {
                Toggle("Use encrypted proxy", isOn: $enabled)
                    .accessibilityIdentifier("proxy.enabled")
            } footer: {
                Text("Route this container’s website requests through your own HTTPS CONNECT proxy. A server or subscription is required; Lite does not provide one.")
            }
            if enabled {
                Section("Server") {
                    TextField("Server hostname", text: $host)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .host)
                        .accessibilityIdentifier("proxy.host")
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .port)
                        .accessibilityIdentifier("proxy.port")
                }
                Section {
                    TextField("Username (optional)", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .username)
                        .accessibilityIdentifier("proxy.username")
                    SecureField(app.proxyCredentialID == nil ? "Password" : "Leave blank to keep saved password", text: $password)
                        .focused($focusedField, equals: .password)
                        .accessibilityIdentifier("proxy.password")
                } header: { Text("Authentication") } footer: {
                    Text("Passwords are stored in this device’s Keychain. For an authenticated copy of a container, enter the password again.")
                }
            }
            Section {
                if let message { Text(message).foregroundStyle(.secondary).accessibilityIdentifier("proxy.saved") }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("proxy.error") }
                Text("If this container has already opened, quit Lite from the app switcher and reopen it after saving. Your website data and sign-ins are kept.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("What it covers") {
                Text("Uses TLS to connect to the proxy. Website requests, popup pages, downloads and icon refreshes use the configured route. Failed proxy requests do not automatically fall back to a direct connection.")
                Text("This is a web proxy, not a device VPN. Localhost traffic can bypass the proxy. WebRTC voice/video traffic and DNS are not guaranteed to use this route. Discover and links opened in other apps are outside this setting.")
                Text("A saved configuration does not confirm that the server is reachable. The server must support HTTPS CONNECT with a trusted certificate.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .navigationTitle("Encrypted Proxy")
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).accessibilityIdentifier("proxy.save")
            }
        }
        .task {
            guard !loaded else { return }
            enabled = app.isProxyEnabled
            host = app.proxyHost
            port = String(app.proxyPort)
            username = app.proxyUsername
            loaded = true
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { password = "" }
        }
    }

    private func save() {
        guard scenePhase == .active else { return }
        focusedField = nil
        message = nil
        errorMessage = nil
        let previous = ContainerProxy(app: app)
        var newCredential: UUID?
        do {
            let normalizedHost = enabled ? try ContainerProxy.validatedHost(host) : app.proxyHost
            let normalizedPort: Int
            if enabled {
                guard let value = Int(port), (1...65535).contains(value) else { throw ProxyError.invalidPort }
                normalizedPort = value
            } else { normalizedPort = app.proxyPort }
            let normalizedUsername = enabled ? username.trimmingCharacters(in: .whitespacesAndNewlines) : app.proxyUsername
            var credential = app.proxyCredentialID
            if enabled {
                if normalizedUsername.isEmpty {
                    guard password.isEmpty else { throw ProxyError.missingCredentials }
                    credential = nil
                } else if !password.isEmpty {
                    let id = UUID()
                    try ProxyCredentialStore.save(password, profile: app.dataStoreIdentifier, credential: id)
                    newCredential = id
                    credential = id
                } else {
                    // A password is reusable only for the same server and account.
                    guard normalizedHost == app.proxyHost, normalizedPort == app.proxyPort,
                          normalizedUsername == app.proxyUsername, let id = credential,
                          let saved = try ProxyCredentialStore.password(profile: app.dataStoreIdentifier, credential: id),
                          !saved.isEmpty else { throw ProxyError.missingCredentials }
                }
            }
            app.isProxyEnabled = enabled
            app.proxyHost = normalizedHost
            app.proxyPort = normalizedPort
            app.proxyUsername = normalizedUsername
            app.proxyCredentialID = credential
            try context.save()
            if let old = previous.credentialID, old != credential {
                try? ProxyCredentialStore.remove(profile: app.dataStoreIdentifier, credential: old)
            }
            host = normalizedHost
            port = String(normalizedPort)
            username = normalizedUsername
            password = ""
            message = "Settings saved. If this container was already open, quit and reopen Lite before browsing."
        } catch {
            app.isProxyEnabled = previous.enabled
            app.proxyHost = previous.host
            app.proxyPort = previous.port
            app.proxyUsername = previous.username
            app.proxyCredentialID = previous.credentialID
            if let newCredential {
                try? ProxyCredentialStore.remove(profile: app.dataStoreIdentifier, credential: newCredential)
            }
            errorMessage = (error as? ProxyError)?.localizedDescription ?? "Your proxy settings couldn’t be saved. Please try again."
        }
    }
}

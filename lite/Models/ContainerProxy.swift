import Foundation
import Network

/// Immutable routing settings for one browser session. Secrets never enter SwiftData.
struct ContainerProxy: Equatable, Sendable {
    var enabled: Bool
    var host: String
    var port: Int
    var username: String
    var credentialID: UUID?

    @MainActor init(app: LiteApp) {
        enabled = app.isProxyEnabled
        host = app.proxyHost
        port = app.proxyPort
        username = app.proxyUsername
        credentialID = app.proxyCredentialID
    }

    static func validatedHost(_ input: String) throws -> String {
        var host = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if host.hasPrefix("["), host.hasSuffix("]") { host = String(host.dropFirst().dropLast()) }
        if IPv4Address(host) != nil || IPv6Address(host) != nil { return host }
        guard !host.isEmpty, host.utf8.count <= 253,
              host.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 46 }),
              host.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({
                  !$0.isEmpty && $0.utf8.count <= 63 && !$0.hasPrefix("-") && !$0.hasSuffix("-")
              }) else { throw ProxyError.invalidHost }
        return host
    }

    func configuration(profile: UUID) throws -> [ProxyConfiguration] {
        guard enabled else { return [] }
        let host = try Self.validatedHost(host)
        guard (1...65535).contains(port), let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw ProxyError.invalidPort
        }
        // TLS to the proxy is mandatory. Omitting these options would expose the
        // CONNECT request and proxy credentials on the local network.
        var configuration = ProxyConfiguration(
            httpCONNECTProxy: .hostPort(host: NWEndpoint.Host(host), port: endpointPort),
            tlsOptions: NWProtocolTLS.Options()
        )
        configuration.allowFailover = false
        if !username.isEmpty {
            guard let credentialID,
                  let password = try ProxyCredentialStore.password(profile: profile, credential: credentialID),
                  !password.isEmpty else { throw ProxyError.missingCredentials }
            configuration.applyCredential(username: username, password: password)
        }
        return [configuration]
    }
}

enum ProxyError: LocalizedError {
    case invalidHost, invalidPort, missingCredentials, restartRequired
    case keychain(Int32)

    var errorDescription: String? {
        switch self {
        case .invalidHost: "Enter a server hostname or IP address, without a scheme, port or path."
        case .invalidPort: "Enter a port from 1 to 65535."
        case .missingCredentials: "Enter the proxy username and password in App Settings → Encrypted Proxy. This container has not connected directly."
        case .keychain: "The proxy password couldn’t be accessed securely. Unlock your device and try again."
        case .restartRequired: "Proxy settings changed after this container opened. Quit Lite from the app switcher and reopen it to use the new settings."
        }
    }
}

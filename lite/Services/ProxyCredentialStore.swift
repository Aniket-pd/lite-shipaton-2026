import Foundation
import Security

/// Immutable, device-only password entries allow SwiftData saves to fail without
/// replacing the credential used by the previously saved configuration.
nonisolated enum ProxyCredentialStore {
    private static func query(profile: UUID, credential: UUID? = nil) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "aniket.lite.proxy.\(profile.uuidString)"
        ]
        if let credential { query[kSecAttrAccount as String] = credential.uuidString }
        return query
    }

    static func password(profile: UUID, credential: UUID) throws -> String? {
        var query = query(profile: profile, credential: credential)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else { throw ProxyError.keychain(status) }
        return password
    }

    static func save(_ password: String, profile: UUID, credential: UUID) throws {
        var query = query(profile: profile, credential: credential)
        query[kSecValueData as String] = Data(password.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        query[kSecAttrSynchronizable as String] = false
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw ProxyError.keychain(status) }
    }

    static func remove(profile: UUID, credential: UUID? = nil) throws {
        let status = SecItemDelete(query(profile: profile, credential: credential) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw ProxyError.keychain(status) }
    }
}

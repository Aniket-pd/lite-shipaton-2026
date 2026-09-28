import Foundation
import SwiftData

enum LaunchPagePreference: String, CaseIterable, Identifiable {
    case start
    case continueLast

    var id: String { rawValue }
    var title: String { self == .start ? "Start Page" : "Continue Last Page" }
}

@Model
final class LiteApp {
    @Attribute(.unique) var id: UUID
    var name: String
    var url: URL
    @Attribute(.externalStorage) var iconData: Data?
    var iconSymbol: String
    var iconColor: String
    // Created once. Editing an app must never replace this identity.
    @Attribute(.unique) var dataStoreIdentifier: UUID
    var isBiometricLocked: Bool
    var isBlockingEnabled: Bool
    var createdAt: Date
    // V2 fields are additive and have on-disk defaults so populated V1 stores
    // migrate without replacing account or WebKit profile identities.
    var launchPageRawValue: String = "start"
    var lastPageURL: URL?
    var isFavorite: Bool = false
    var sortOrder: Int = 0
    var isVisibleInWidget: Bool = false
    // Only the six bundled onboarding profiles are exempt from creation limits.
    // Duplicates deliberately keep the default false value.
    var isStarterApp: Bool = false

    // Additive defaults preserve existing SwiftData stores and WebKit identities.
    var websiteLayoutRawValue: String = "mobile"
    var pageZoom: Double = 1.0
    var cameraPermissionRawValue: String = "ask"
    var microphonePermissionRawValue: String = "ask"
    var requiresMediaGesture: Bool = true
    var allowsJavaScript: Bool = true
    var allowsPopups: Bool = true
    var automaticWindowOrigins: [String] = []
    var isProxyEnabled: Bool = false
    var proxyHost: String = ""
    var proxyPort: Int = 443
    var proxyUsername: String = ""
    var proxyCredentialID: UUID?
    var lastOpenedAt: Date?
    var lastConnectionAt: Date?
    var lastConnectionHost: String?
    var lastConnectionSecure: Bool?
    var lastHTTPStatus: Int?
    var lastLoadDuration: Double?
    var lastErrorAt: Date?
    var lastErrorDomain: String?
    var lastErrorCode: Int?
    var lastErrorHost: String?

    var websiteLayout: WebsiteLayout {
        get { WebsiteLayout(rawValue: websiteLayoutRawValue) ?? .mobile }
        set { websiteLayoutRawValue = newValue.rawValue }
    }
    var cameraPermission: WebsitePermission {
        get { WebsitePermission(rawValue: cameraPermissionRawValue) ?? .ask }
        set { cameraPermissionRawValue = newValue.rawValue }
    }
    var microphonePermission: WebsitePermission {
        get { WebsitePermission(rawValue: microphonePermissionRawValue) ?? .ask }
        set { microphonePermissionRawValue = newValue.rawValue }
    }
    var effectivePageZoom: Double { pageZoom.isFinite ? min(2, max(0.75, pageZoom)) : 1 }

    func resetContainerPreferences() {
        launchPagePreference = .start
        websiteLayout = .mobile
        pageZoom = 1
        cameraPermission = .ask
        microphonePermission = .ask
        requiresMediaGesture = true
        allowsJavaScript = true
        allowsPopups = true
        automaticWindowOrigins = []
        isBlockingEnabled = true
    }

    func clearDiagnostics() {
        lastConnectionAt = nil
        lastConnectionHost = nil
        lastConnectionSecure = nil
        lastHTTPStatus = nil
        lastLoadDuration = nil
        lastErrorAt = nil
        lastErrorDomain = nil
        lastErrorCode = nil
        lastErrorHost = nil
    }

    var launchPagePreference: LaunchPagePreference {
        get { LaunchPagePreference(rawValue: launchPageRawValue) ?? .start }
        set { launchPageRawValue = newValue.rawValue }
    }

    init(name: String, url: URL, iconData: Data? = nil, iconSymbol: String = "globe",
         iconColor: String = "blue", isBiometricLocked: Bool = false) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.iconData = iconData
        self.iconSymbol = iconSymbol
        self.iconColor = iconColor
        self.dataStoreIdentifier = UUID()
        self.isBiometricLocked = isBiometricLocked
        self.isBlockingEnabled = true
        self.createdAt = .now
    }

    var initialURL: URL {
        guard launchPagePreference == .continueLast,
              let lastPageURL,
              let candidate = ResumeURLPolicy.sanitizedCandidate(lastPageURL, for: url) else { return url }
        return candidate
    }

    func nextAccountName(in apps: [LiteApp]) -> String {
        let base = String(name.prefix(28)) + " Account"
        let names = Set(apps.map(\.name))
        if !names.contains(base) { return base }
        var suffix = 2
        while names.contains("\(base) \(suffix)") { suffix += 1 }
        return "\(base) \(suffix)"
    }

    func duplicate(accountName: String? = nil) -> LiteApp {
        let copy = LiteApp(
            name: accountName ?? "\(name) Account",
            url: url,
            iconData: iconData,
            iconSymbol: iconSymbol,
            iconColor: iconColor,
            isBiometricLocked: isBiometricLocked
        )
        copy.isBlockingEnabled = isBlockingEnabled
        copy.launchPagePreference = launchPagePreference
        copy.isFavorite = isFavorite
        copy.websiteLayout = websiteLayout
        copy.pageZoom = effectivePageZoom
        copy.cameraPermission = cameraPermission
        copy.microphonePermission = microphonePermission
        copy.requiresMediaGesture = requiresMediaGesture
        copy.allowsJavaScript = allowsJavaScript
        copy.allowsPopups = allowsPopups
        copy.automaticWindowOrigins = automaticWindowOrigins
        copy.isProxyEnabled = isProxyEnabled
        copy.proxyHost = proxyHost
        copy.proxyPort = proxyPort
        copy.proxyUsername = proxyUsername
        // Credentials belong to this profile's Keychain namespace. An authenticated
        // copy stays blocked until its own password is supplied.
        return copy
    }
}

// A durable cleanup receipt prevents abandoned cookies if deletion is interrupted.
@Model
final class PendingProfileDeletion {
    @Attribute(.unique) var identifier: UUID
    init(identifier: UUID) { self.identifier = identifier }
}

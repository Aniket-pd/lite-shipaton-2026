import Foundation
import WebKit

enum WebsiteLayout: String, CaseIterable, Identifiable {
    case mobile, desktop, automatic
    var id: String { rawValue }
    var title: String {
        switch self { case .mobile: "Mobile"; case .desktop: "Desktop"; case .automatic: "Automatic" }
    }
    var contentMode: WKWebpagePreferences.ContentMode {
        switch self { case .mobile: .mobile; case .desktop: .desktop; case .automatic: .recommended }
    }
}

enum WebsitePermission: String, CaseIterable, Identifiable {
    case ask, block
    var id: String { rawValue }
    var title: String { self == .ask ? "Ask" : "Block" }
}

/// A session uses one immutable set of preferences, including its popup windows.
struct ContainerPreferences {
    let layout: WebsiteLayout
    let zoom: Double
    let camera: WebsitePermission
    let microphone: WebsitePermission
    let requiresMediaGesture: Bool
    let allowsJavaScript: Bool
    let allowsPopups: Bool

    init(app: LiteApp) {
        layout = app.websiteLayout
        zoom = app.effectivePageZoom
        camera = app.cameraPermission
        microphone = app.microphonePermission
        requiresMediaGesture = app.requiresMediaGesture
        allowsJavaScript = app.allowsJavaScript
        allowsPopups = app.allowsPopups
    }

    func apply(to configuration: WKWebViewConfiguration) {
        configuration.defaultWebpagePreferences.preferredContentMode = layout.contentMode
        configuration.defaultWebpagePreferences.allowsContentJavaScript = allowsJavaScript
        configuration.mediaTypesRequiringUserActionForPlayback = requiresMediaGesture ? .all : []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
    }

    func mediaDecision(for type: WKMediaCaptureType) -> WKPermissionDecision {
        switch type {
        case .camera: camera == .block ? .deny : .prompt
        case .microphone: microphone == .block ? .deny : .prompt
        case .cameraAndMicrophone: camera == .block || microphone == .block ? .deny : .prompt
        @unknown default: .deny
        }
    }
}

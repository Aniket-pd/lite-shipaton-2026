import SwiftUI

struct ContainerDiagnosticsView: View {
    let app: LiteApp
    @State private var copied = false

    var body: some View {
        List {
            Section {
                LabeledContent("Host", value: app.lastConnectionHost ?? "Not recorded yet")
                    .accessibilityIdentifier("diagnostics.host")
                LabeledContent("Connection", value: connection)
                    .accessibilityIdentifier("diagnostics.connection")
                LabeledContent("Observed", value: date(app.lastConnectionAt))
                LabeledContent("HTTP status", value: app.lastHTTPStatus.map(String.init) ?? "Not recorded")
                LabeledContent("Navigation duration", value: duration)
            } header: { Text("Last completed navigation") } footer: {
                Text("Recorded from an actual page load. This is a past observation, not a live security check. Duration measures navigation start to completion, not all network activity.")
            }
            Section {
                if let domain = app.lastErrorDomain, let code = app.lastErrorCode {
                    LabeledContent("Error", value: "\(domain) (\(code))")
                    LabeledContent("Host", value: app.lastErrorHost ?? "Unavailable")
                    LabeledContent("Occurred", value: date(app.lastErrorAt))
                } else { Text("No navigation error recorded").foregroundStyle(.secondary) }
            } header: { Text("Most recent navigation error") }
            Section("Configuration") {
                LabeledContent("Encrypted proxy", value: app.isProxyEnabled ? "Configured (not verified)" : "Off")
                LabeledContent("Tracker blocking", value: app.isBlockingEnabled ? "Enabled" : "Disabled")
                LabeledContent("Rule list", value: ContentBlocker.identifier)
                LabeledContent("Website layout", value: app.websiteLayout.title)
                LabeledContent("Page zoom", value: "\(Int((app.effectivePageZoom * 100).rounded()))%")
            }
            Section("Identifiers") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Container ID").font(.subheadline)
                    Text(app.id.uuidString).font(.caption.monospaced()).textSelection(.enabled).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Website Profile ID").font(.subheadline)
                    Text(app.dataStoreIdentifier.uuidString).font(.caption.monospaced()).textSelection(.enabled).foregroundStyle(.secondary)
                }
                LabeledContent("Lite", value: version)
                LabeledContent("iOS", value: UIDevice.current.systemVersion)
            }
            Section {
                Button(copied ? "Diagnostic Summary Copied" : "Copy Diagnostic Summary", systemImage: "doc.on.doc") {
                    UIPasteboard.general.setItems([["public.utf8-plain-text": summary]], options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(300)])
                    copied = true
                }.accessibilityIdentifier("diagnostics.copy")
            } footer: { Text("Includes identifiers, website hosts, settings and error codes. No cookie values, page paths, query parameters or account names are copied.") }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var connection: String {
        guard let secure = app.lastConnectionSecure else { return "Not recorded yet" }
        return secure ? "Encrypted (HTTPS)" : "Not fully encrypted"
    }
    private var duration: String {
        app.lastLoadDuration.map { "\($0.formatted(.number.precision(.fractionLength(2)))) s" } ?? "Not recorded"
    }
    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "Unknown") (\(info["CFBundleVersion"] as? String ?? "Unknown"))"
    }
    private func date(_ value: Date?) -> String { value?.formatted(date: .abbreviated, time: .shortened) ?? "Not recorded yet" }
    private var summary: String {
        """
        Lite \(version); iOS \(UIDevice.current.systemVersion)
        Container: \(app.id)
        Profile: \(app.dataStoreIdentifier)
        Last connection: \(connection)
        Host: \(app.lastConnectionHost ?? "Not recorded")
        Observed: \(date(app.lastConnectionAt))
        HTTP status: \(app.lastHTTPStatus.map(String.init) ?? "Not recorded")
        Navigation duration: \(duration)
        Last error: \(app.lastErrorDomain ?? "None") \(app.lastErrorCode.map(String.init) ?? "")
        Error host: \(app.lastErrorHost ?? "Not recorded")
        Error date: \(date(app.lastErrorAt))
        Protection: \(app.isBlockingEnabled ? "Enabled" : "Disabled")
        Rule list: \(ContentBlocker.identifier)
        Layout: \(app.websiteLayout.title); zoom: \(app.effectivePageZoom)
        Camera: \(app.cameraPermission.title); microphone: \(app.microphonePermission.title)
        Require media gesture: \(app.requiresMediaGesture)
        JavaScript: \(app.allowsJavaScript); website windows: \(app.allowsPopups)
        """
    }
}

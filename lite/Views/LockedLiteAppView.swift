import SwiftUI

struct LockedLiteAppView: View {
    let app: LiteApp
    var body: some View {
        ContainerAccessView(app: app) { LiteBrowserView(app: app) }
    }
}

/// The same biometric boundary protects browsing and profile inspection.
struct ContainerAccessView<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let app: LiteApp
    @ViewBuilder let content: () -> Content
    @State private var biometrics = BiometricService()
    @State private var isUnlocked = false
    @State private var authenticateOnReturn = false
    @State private var message: String?
    @State private var authenticationAppID: UUID?

    var body: some View {
        ZStack {
            if !app.isBiometricLocked || isUnlocked {
                content()
                    .opacity(needsPrivacyCover ? 0 : 1)
                    .accessibilityHidden(needsPrivacyCover)
                    .allowsHitTesting(!needsPrivacyCover)
            }
            if app.isBiometricLocked && (!isUnlocked || needsPrivacyCover) {
                lockScreen
            }
        }
        .background(Color(.systemBackground))
        .background {
            ContainerPrivacyShield(isProtected: app.isBiometricLocked, isActive: scenePhase == .active)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .task(id: app.id) {
            // Returning from a browser presented by Saved is the same access
            // scope. Only a new identity or backgrounding revokes its unlock.
            if authenticationAppID != app.id {
                authenticationAppID = app.id
                isUnlocked = !app.isBiometricLocked
            }
            if app.isBiometricLocked && !isUnlocked { await unlock() }
        }
        .onChange(of: app.id) { _, newID in
            biometrics.cancel()
            authenticationAppID = newID
            isUnlocked = false
            message = nil
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && app.isBiometricLocked {
                biometrics.cancel()
                isUnlocked = false
                authenticateOnReturn = true
            } else if phase == .active && authenticateOnReturn {
                authenticateOnReturn = false
                Task { await unlock() }
            }
        }
        .onDisappear { biometrics.cancel() }
    }

    private var needsPrivacyCover: Bool { app.isBiometricLocked && scenePhase != .active }

    private var lockScreen: some View {
        VStack(spacing: 20) {
            HStack {
                Button("Done") { dismiss() }.padding()
                Spacer()
            }
            Spacer()
            AppLockContent(
                app: app, biometricLabel: biometrics.label, message: message,
                isAuthenticating: biometrics.isAuthenticating,
                isAvailable: scenePhase == .active,
                unlock: { Task { await unlock() } }
            )
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private func unlock() async {
        let requestedAppID = app.id
        authenticationAppID = requestedAppID
        message = nil
        do {
            try await biometrics.authenticate(reason: "Unlock \(app.name).")
            guard scenePhase != .background,
                  authenticationAppID == requestedAppID,
                  app.id == requestedAppID else { return }
            isUnlocked = true
        } catch {
            guard authenticationAppID == requestedAppID else { return }
            message = BiometricService.message(for: error)
        }
    }
}

/// Shared lock presentation; authentication remains owned by ContainerAccessView.
struct AppLockContent: View {
    let app: LiteApp
    let biometricLabel: String
    var message: String? = nil
    var isAuthenticating = false
    var isAvailable = true
    let unlock: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            AppIconView(data: app.iconData, websiteURL: app.url, symbol: app.iconSymbol, size: 80)
            Text(app.name).font(.title2.bold()).multilineTextAlignment(.center)
            Label("This Lite App is locked", systemImage: "lock.fill").foregroundStyle(.secondary)
            if let message { Text(message).font(.callout).multilineTextAlignment(.center).foregroundStyle(.secondary) }
            Button(action: unlock) {
                if isAuthenticating { ProgressView().frame(minWidth: 120) }
                else { Text("Unlock with \(biometricLabel)") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAuthenticating || !isAvailable)
            .accessibilityIdentifier("lock.unlock")
        }
    }
}

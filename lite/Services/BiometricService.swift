import LocalAuthentication
import Observation

@MainActor
@Observable
final class BiometricService {
    private(set) var isAuthenticating = false
    @ObservationIgnored private var context: LAContext?
    @ObservationIgnored private var generation = UUID()

    // Avoid the synthesized isolated-deinit runtime crash on iOS 26.2 and older.
    // Authentication cleanup remains explicit in cancel() and authenticate().
    // https://github.com/swiftlang/swift/issues/88036
    deinit {}

    var label: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType == .touchID ? "Touch ID" : "Face ID"
    }

    func authenticate(reason: String) async throws {
        guard !isAuthenticating else { throw CancellationError() }
        let attempt = UUID()
        generation = attempt
        let context = LAContext()
        context.localizedFallbackTitle = ""
        context.touchIDAuthenticationAllowableReuseDuration = 0
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw error ?? BiometricError.unavailable
        }
        self.context = context
        isAuthenticating = true
        defer {
            if generation == attempt {
                isAuthenticating = false
                self.context = nil
            }
            context.invalidate()
        }
        let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        guard generation == attempt, !Task.isCancelled else { throw CancellationError() }
        guard success else { throw BiometricError.failed }
    }

    func cancel() {
        generation = UUID()
        context?.invalidate()
        context = nil
        isAuthenticating = false
    }

    static func message(for error: Error) -> String? {
        if error is CancellationError { return nil }
        if let error = error as? LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel: return nil
            case .biometryNotEnrolled: return "Set up Face ID or Touch ID in Settings, then try again."
            case .biometryLockout: return "Biometrics are temporarily locked. Unlock your iPhone with its passcode, then try again."
            case .biometryNotAvailable: return "Face ID or Touch ID isn’t available. Check your device settings and try again."
            default: break
            }
        }
        return "Authentication wasn’t completed. Please try again."
    }
}

private enum BiometricError: LocalizedError {
    case unavailable, failed
    var errorDescription: String? { "Face ID or Touch ID couldn’t verify your identity." }
}

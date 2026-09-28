import Foundation

/// Completion belongs to this installation, not to any website profile.
enum OnboardingPolicy {
    static let completionKey = "lite.onboarding.v1.completed"
    static let startedKey = "lite.onboarding.v1.started"
    static let legacyUseKey = "lite.iconBackfill.v2.completed"

    static func shouldPresent(completed: Bool, previouslyUsed: Bool, isUITesting: Bool, requestedByTest: Bool) -> Bool {
        guard !completed else { return false }
        if isUITesting { return requestedByTest }
        return !previouslyUsed
    }

    static var defaults: UserDefaults {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            return UserDefaults(suiteName: "aniket.lite.onboarding.tests")!
        }
        #endif
        return .standard
    }

    static func prepareForLaunch() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting"), arguments.contains("--uitesting-onboarding-reset") {
            defaults.removeObject(forKey: completionKey)
            defaults.removeObject(forKey: startedKey)
        }
        #endif
    }

    // Called by a State initializer, so this must remain read-only. Writing
    // defaults here re-invalidates AppStorage readers as HomeView is recreated.
    static func initialPresentation() -> Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let testing = arguments.contains("--uitesting")
        let shouldShow = shouldPresent(
            completed: defaults.bool(forKey: completionKey),
            previouslyUsed: UserDefaults.standard.bool(forKey: legacyUseKey) && !defaults.bool(forKey: startedKey),
            isUITesting: testing,
            requestedByTest: arguments.contains("--uitesting-onboarding")
        )
        #else
        let shouldShow = shouldPresent(completed: defaults.bool(forKey: completionKey),
                             previouslyUsed: defaults.bool(forKey: legacyUseKey) && !defaults.bool(forKey: startedKey),
                             isUITesting: false, requestedByTest: false)
        #endif
        return shouldShow
    }

    static func markStarted() {
        if !defaults.bool(forKey: startedKey) {
            defaults.set(true, forKey: startedKey)
        }
    }

    static func complete() {
        defaults.set(true, forKey: completionKey)
        defaults.removeObject(forKey: startedKey)
    }
}

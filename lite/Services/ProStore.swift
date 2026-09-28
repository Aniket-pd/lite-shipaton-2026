import Foundation
import Observation
import RevenueCat
import SwiftData

/// Purchase state never modifies the user's library or website data.
struct ProAccess: Equatable {
    var isActive = false
    var expiresAt: Date?
    var productID: String?
    var willRenew = false
    var hasBillingIssue = false

    func isUnlocked(at date: Date = .now) -> Bool {
        isActive && (expiresAt.map { $0 > date } ?? true)
    }
    func canCreateApp(count: Int, at date: Date = .now) -> Bool { count < 3 || isUnlocked(at: date) }
    func canCreateGroup(count: Int, at date: Date = .now) -> Bool { count < 1 || isUnlocked(at: date) }
}

enum ProFeature: String, Identifiable, Error {
    case apps, groups, customization
    var id: String { rawValue }
    var message: String {
        switch self {
        case .apps: "Your free plan includes 3 added profiles, plus the included starter apps. Add unlimited profiles with Lite Pro."
        case .groups: "Your free plan includes 1 group. Organize more groups with Lite Pro."
        case .customization: "Make every profile your own with more symbols and badge colors."
        }
    }
}

enum ProCatalog {
    static let monthly = "aniket.lite.pro.monthly"
    static let weekly = "aniket.lite.pro.weekly"
    static let lifetime = "aniket.lite.pro.lifetime"
    static let productIDs = [monthly, lifetime, weekly]
    static let symbols = ["book", "airplane", "gift", "leaf", "gamecontroller", "camera", "laptopcomputer", "music.note"]
    static let colors = ["purple", "red"]
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

}

@Observable @MainActor
final class ProStore {
    private(set) var access = ProAccess()
    private(set) var packages: [Package] = []
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    private(set) var trialEligibility: [String: IntroEligibility] = [:]
    var message: String?
    private let enabled: Bool

    // Match the existing iOS 26.2 isolated-deinit workaround used by BiometricService.
    deinit {}

    var isPro: Bool { access.isUnlocked() }
    var isBusy: Bool { isPurchasing || isRestoring }

    static func applicationStore() -> ProStore {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting") && !arguments.contains("--uitesting-live-purchases") {
            return ProStore(enabled: false)
        }
        #endif
        return ProStore()
    }

    init(enabled: Bool = true) {
        self.enabled = enabled
        guard enabled else { return }
        if !Purchases.isConfigured {
            // Public, app-scoped SDK key. No Apple or RevenueCat private keys ship in Lite.
            Purchases.configure(with: Configuration.builder(withAPIKey: "appl_ERTsqugzNpKGfrTQVQJtnmVaJiK")
                .with(automaticDeviceIdentifierCollectionEnabled: false).build())
        }
        if let info = Purchases.shared.cachedCustomerInfo { apply(info) }
    }

    func observePurchases() async {
        guard enabled else { return }
        await refresh()
        for await info in Purchases.shared.customerInfoStream {
            guard !Task.isCancelled else { return }
            apply(info)
        }
    }

    func refresh() async {
        guard enabled else { return }
        do { apply(try await Purchases.shared.customerInfo()) }
        catch { /* Keep the SDK's cached entitlement, bounded by its expiry date. */ }
    }

    func loadPlans() async {
        guard enabled, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let offering = try await Purchases.shared.offerings().current
            var loadedPackages = ProCatalog.productIDs.compactMap { id in
                offering?.availablePackages.first { $0.storeProduct.productIdentifier == id }
            }
            loadedPackages.sort { planOrder($0) < planOrder($1) }
            trialEligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
                productIdentifiers: loadedPackages.map { $0.storeProduct.productIdentifier }
            )
            packages = loadedPackages
            message = packages.isEmpty ? "Plans aren’t available right now. Please try again shortly." : nil
        } catch { message = "Couldn’t load plans. Check your connection and try again." }
    }

    private func planOrder(_ package: Package) -> Int {
        if package.storeProduct.productIdentifier == ProCatalog.weekly { return 0 }
        if package.storeProduct.productIdentifier == ProCatalog.lifetime { return 2 }
        return 1
    }

    func freeTrialDuration(for package: Package) -> String? {
        guard package.storeProduct.productIdentifier == ProCatalog.monthly,
              trialEligibility[package.storeProduct.productIdentifier]?.status == .eligible,
              let offer = package.storeProduct.introductoryDiscount,
              offer.paymentMode == .freeTrial else { return nil }
        let count = offer.subscriptionPeriod.value * offer.numberOfPeriods
        var components = DateComponents()
        switch offer.subscriptionPeriod.unit {
        case .day: components.day = count
        case .week: components.day = count * 7
        case .month: components.month = count
        case .year: components.year = count
        @unknown default: return nil
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        return formatter.string(from: components)
    }

    @discardableResult
    func purchase(_ package: Package) async -> Bool {
        guard enabled, !isBusy else { return false }
        isPurchasing = true
        message = nil
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(result.customerInfo)
            guard !result.userCancelled else { return false }
            if !isPro { message = "Your purchase is pending confirmation. Access updates automatically once Apple confirms it." }
            return isPro
        } catch {
            message = "The purchase didn’t complete. If approval is required, Lite Pro will unlock after approval. You can also try Restore Purchases."
            return false
        }
    }

    func restore() async {
        guard enabled, !isBusy else { return }
        isRestoring = true
        message = nil
        defer { isRestoring = false }
        do {
            apply(try await Purchases.shared.restorePurchases())
            message = isPro ? "Lite Pro is restored." : "No active Lite Pro purchase was found for this Apple Account."
        } catch { message = "Couldn’t restore purchases. Check your connection and Apple Account, then try again." }
    }

    func requireAppSlot(in context: ModelContext) throws {
        let addedProfiles = FetchDescriptor<LiteApp>(predicate: #Predicate { !$0.isStarterApp })
        guard access.canCreateApp(count: try context.fetchCount(addedProfiles)) else { throw ProFeature.apps }
    }
    func requireGroupSlot(in context: ModelContext) throws {
        guard access.canCreateGroup(count: try context.fetchCount(FetchDescriptor<LiteAppCollection>())) else { throw ProFeature.groups }
    }
    func requireAppearance(symbol: String, color: String, existing: LiteApp? = nil) throws {
        guard !isPro else { return }
        if (ProCatalog.symbols.contains(symbol) && symbol != existing?.iconSymbol) ||
            (ProCatalog.colors.contains(color) && color != existing?.iconColor) { throw ProFeature.customization }
    }

    private func apply(_ info: CustomerInfo) {
        guard let entitlement = info.entitlements["pro"], entitlement.verification != .failed else {
            access = ProAccess(); return
        }
        let graceEnd = info.subscriptionsByProductIdentifier[entitlement.productIdentifier]?.gracePeriodExpiresDate
        let expiration = [entitlement.expirationDate, graceEnd].compactMap { $0 }.max()
        access = ProAccess(isActive: entitlement.isActive, expiresAt: expiration,
                           productID: entitlement.productIdentifier, willRenew: entitlement.willRenew,
                           hasBillingIssue: entitlement.billingIssueDetectedAt != nil)
    }
}

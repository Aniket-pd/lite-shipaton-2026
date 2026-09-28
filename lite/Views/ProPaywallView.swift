import RevenueCat
import StoreKit
import SwiftUI

struct ProPaywallView: View {
    @Environment(ProStore.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    var feature: ProFeature?
    @State private var selection = ProCatalog.monthly
    @State private var showSubscriptions = false
    @State private var showsFreePlanDetails = false

    private var selectedPackage: Package? {
        pro.packages.first { $0.storeProduct.productIdentifier == selection }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            GeometryReader { geometry in
                // Keep the purchase decision in view while the supporting information scrolls.
                // On short displays or with larger text, let everything scroll instead of
                // allowing a fixed panel to consume the reading area.
                if geometry.size.height >= 660 && typeSize <= .xLarge {
                    GeometryReader { viewport in
                        ScrollView {
                            information(minimumHeroHeight: viewport.size.height)
                                .frame(maxWidth: 560)
                                .frame(maxWidth: .infinity)
                        }
                        .accessibilityIdentifier("pro.content")
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        purchasePanel.frame(maxWidth: 560)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            information()
                            purchasePanel
                        }
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("pro.content")
                }
            }
        }
        .foregroundStyle(.white)
        .background { ProPaywallBackground() }
        // Scope the paywall theme to its content; a presentation preference can
        // propagate into the Settings sheet that presents this view.
        .environment(\.colorScheme, .dark)
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(pro.isBusy)
        .manageSubscriptionsSheet(isPresented: $showSubscriptions)
        .task { await pro.loadPlans(); await pro.refresh() }
        .onChange(of: pro.packages.map(\.identifier), initial: true) {
            if selectedPackage == nil, let first = pro.packages.first {
                selection = first.storeProduct.productIdentifier
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
            Spacer()
            Label("PRO", systemImage: "bolt.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
                .accessibilityLabel("Lite Pro")
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ProPaywallStyle.secondary)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.06), in: .circle)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(pro.isBusy)
            .accessibilityLabel("Close paywall")
            .accessibilityIdentifier("pro.close")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .frame(maxWidth: 560)
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ProProfilePreview()
                .frame(maxWidth: 320)
                .padding(.vertical, 8)
            Text(pro.isPro ? "You’re on Lite Pro" : "More room for\nevery account.")
                .font(.title.weight(.semibold))
                .tracking(-0.8)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("pro.paywall")
            Text(feature?.message ?? "Unlimited profiles and groups.\nMore symbols. More colors.")
                .font(.subheadline)
                .foregroundStyle(ProPaywallStyle.secondary)
                .lineSpacing(3)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 28)
        .padding(.top, 8)
    }

    private var purchasePanel: some View {
        VStack(spacing: 10) {
            if pro.isPro {
                status
            } else {
                plans
                if let package = selectedPackage {
                    ZStack(alignment: .top) {
                        // Reserve the tallest localized purchase button so
                        // switching plans never moves the panel or its purchase button.
                        ForEach(pro.packages, id: \.identifier) { candidate in
                            purchaseButton(for: candidate)
                                .hidden()
                                .accessibilityHidden(true)
                        }
                        purchaseButton(for: package)
                    }
                }
            }
            if let message = pro.message {
                Text(message)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("pro.message")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background {
            ProPaywallSurface(cornerRadius: 28)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func information(minimumHeroHeight: CGFloat = 0) -> some View {
        VStack(spacing: 28) {
            hero
                // Supporting details begin beyond the initial viewport, above the fixed panel.
                .frame(minHeight: minimumHeroHeight, alignment: .top)
            VStack(spacing: 0) {
                Divider().overlay(.white.opacity(0.08))
                Button { showsFreePlanDetails.toggle() } label: {
                    HStack(spacing: 12) {
                        Text("What if I switch back to the free plan?")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: showsFreePlanDetails ? "chevron.down" : "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ProPaywallStyle.secondary)
                    .padding(.vertical, 18)
                    .contentShape(.rect)
                }
                .accessibilityValue(showsFreePlanDetails ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("pro.freePlanFAQ")
                if showsFreePlanDetails {
                    Text("Your saved profiles, groups, and data stay accessible if Pro ends. Free includes 3 added profiles, the starter apps, and 1 group. Pro is needed to add more beyond those limits or choose new Pro symbols and colors.")
                        .font(.subheadline)
                        .foregroundStyle(ProPaywallStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 16)
                        .accessibilityIdentifier("pro.freePlanDetails")
                }
                Divider().overlay(.white.opacity(0.08))
                footer.padding(.top, 10)
                if !pro.isPro && selectedPackage?.storeProduct.productIdentifier != ProCatalog.lifetime {
                    Button("Manage subscriptions") { showSubscriptions = true }
                        .font(.caption)
                        .foregroundStyle(ProPaywallStyle.secondary)
                        .frame(minHeight: 44)
                        .disabled(pro.isBusy)
                        .accessibilityIdentifier("pro.manage")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
        }
        .padding(.bottom, 20)
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("All Pro features unlocked", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)
            if pro.access.productID == ProCatalog.lifetime {
                Text("Lifetime access · One-time purchase")
            } else if let expiration = pro.access.expiresAt {
                Text("\(pro.access.willRenew ? "Renews" : "Access until") \(expiration.formatted(date: .abbreviated, time: .omitted))")
            }
            if pro.access.hasBillingIssue {
                Text("Apple reported a billing issue. Check your payment details in Manage Subscriptions.")
                    .foregroundStyle(.orange)
            }
            Button("Manage Subscriptions") { showSubscriptions = true }
                .foregroundStyle(ProPaywallStyle.accent)
                .frame(minHeight: 44)
                .disabled(pro.isBusy)
                .accessibilityIdentifier("pro.manage")
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var plans: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose your plan")
                .font(.subheadline)
                .foregroundStyle(ProPaywallStyle.secondary)
            if pro.isLoading {
                ProgressView("Loading plans…")
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
            ForEach(pro.packages, id: \.identifier) { package in
                ProPlanRow(package: package, isSelected: selection == package.storeProduct.productIdentifier,
                           hasFreeTrial: pro.freeTrialDuration(for: package) != nil) {
                    selection = package.storeProduct.productIdentifier
                }
                .disabled(pro.isBusy)
                .accessibilityIdentifier("pro.plan.\(package.storeProduct.productIdentifier)")
            }
            if !pro.isLoading && pro.packages.isEmpty {
                VStack(spacing: 8) {
                    if pro.message == nil {
                        Text("Plans aren’t available right now.")
                            .foregroundStyle(ProPaywallStyle.secondary)
                    }
                    Button("Try Again") { Task { await pro.loadPlans() } }
                        .foregroundStyle(ProPaywallStyle.accent)
                        .frame(minHeight: 44)
                        .disabled(pro.isBusy)
                        .accessibilityIdentifier("pro.retry")
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
    }

    private func purchaseButton(for package: Package) -> some View {
        Button {
            Task { if await pro.purchase(package) { dismiss() } }
        } label: {
            VStack(spacing: 5) {
                HStack(spacing: 10) {
                    if pro.isPurchasing { ProgressView().tint(.white) }
                    Text(pro.freeTrialDuration(for: package) != nil ? "Try for free" :
                            package.storeProduct.productIdentifier == ProCatalog.lifetime ? "Buy Lifetime" : "Subscribe")
                        .font(.title3.weight(.semibold))
                }
                Text(purchaseSubtitle(for: package))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 24)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .modifier(ProPurchaseButtonStyle())
        .disabled(pro.isBusy)
        .opacity(pro.isBusy ? 0.65 : 1)
        .accessibilityIdentifier("pro.purchase")
    }

    private func purchaseSubtitle(for package: Package) -> String {
        if let trial = pro.freeTrialDuration(for: package) {
            return "\(trial) free, then \(package.localizedPriceString)\(period(for: package))"
        }
        if package.storeProduct.productIdentifier == ProCatalog.lifetime {
            return "\(package.localizedPriceString) · One-time purchase"
        }
        return "\(package.localizedPriceString)\(period(for: package))"
    }

    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                restoreButton.fixedSize()
                Spacer(minLength: 0)
                termsLink.fixedSize()
                Spacer(minLength: 0)
                privacyLink.fixedSize()
            }
            VStack(spacing: 0) {
                restoreButton
                termsLink
                privacyLink
            }
            .frame(maxWidth: .infinity)
        }
        .font(.caption)
        .foregroundStyle(ProPaywallStyle.secondary)
    }

    private var restoreButton: some View {
        Button(pro.isRestoring ? "Restoring…" : "Restore purchases") { Task { await pro.restore() } }
            .frame(minHeight: 44)
            .disabled(pro.isBusy)
            .accessibilityIdentifier("pro.restore")
    }

    private var termsLink: some View {
        Link("Terms of use", destination: ProCatalog.termsURL)
            .frame(minHeight: 44)
            .accessibilityIdentifier("pro.terms")
    }

    private var privacyLink: some View {
        Link("Privacy policy", destination: URL(string: "https://aniket-pd.github.io/lite-app-support/#privacy")!)
            .frame(minHeight: 44)
            .accessibilityIdentifier("pro.privacy")
    }

    private func period(for package: Package) -> String {
        switch package.storeProduct.productIdentifier {
        case ProCatalog.weekly: "/week"
        case ProCatalog.monthly: "/month"
        default: ""
        }
    }


}

private struct ProPurchaseButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.borderedProminent)
            }
        }
        .tint(ProPaywallStyle.accent)
        .buttonBorderShape(.capsule)
    }
}

private enum ProPaywallStyle {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.09)
    static let surface = Color(red: 0.075, green: 0.11, blue: 0.16)
    static let secondary = Color(red: 0.70, green: 0.76, blue: 0.85)
    static let accent = Color(red: 0, green: 0.48, blue: 1)
}

private struct ProPaywallBackground: View {
    @AppStorage("lite.atmosphericBackground") private var atmosphericBackground = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var animationEpoch = Date.timeIntervalSinceReferenceDate
    @State private var isVisible = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ProPaywallStyle.background
                if atmosphericBackground {
                    // Keep the existing drifting particles in the exposed hero area.
                    AtmosphereBackground(isActive: isVisible && scenePhase == .active,
                                         animationEpoch: animationEpoch)
                        .frame(height: geometry.size.height * 0.65)
                        .mask {
                            LinearGradient(stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: 0.75),
                                .init(color: .clear, location: 1)
                            ], startPoint: .top, endPoint: .bottom)
                        }
                }
                if atmosphericBackground && !reduceTransparency && contrast != .increased {
                    RadialGradient(colors: [ProPaywallStyle.accent.opacity(0.10), .clear],
                                   center: .topTrailing, startRadius: 0, endRadius: 460)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

private struct ProPaywallSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    var cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(ProPaywallStyle.surface)
            .overlay {
                if !reduceTransparency {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.035), .clear],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(contrast == .increased ? 0.5 : 0.12), lineWidth: 0.75)
            }
    }
}

private struct ProPlanRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let package: Package
    let isSelected: Bool
    let hasFreeTrial: Bool
    let select: () -> Void

    private var title: String {
        switch package.storeProduct.productIdentifier {
        case ProCatalog.monthly: "1 Month"
        case ProCatalog.lifetime: "Lifetime"
        default: "1 Week"
        }
    }

    private var interval: String {
        switch package.storeProduct.productIdentifier {
        case ProCatalog.monthly: "per month"
        case ProCatalog.lifetime: "one-time"
        default: "per week"
        }
    }

    var body: some View {
        Button(action: select) {
            ViewThatFits(in: .horizontal) {
                if !typeSize.isAccessibilitySize {
                    HStack(spacing: 12) {
                        planTitle.fixedSize()
                        Spacer(minLength: 4)
                        if hasFreeTrial { trialBadge.fixedSize() }
                        price.fixedSize()
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    planTitle
                    if hasFreeTrial { trialBadge }
                    price
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(isSelected ? ProPaywallStyle.accent.opacity(0.12) : .white.opacity(0.025),
                        in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(isSelected ? ProPaywallStyle.accent : .white.opacity(0.3),
                                  lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(package.localizedPriceString) \(interval)\(hasFreeTrial ? ", free trial available" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var planTitle: some View {
        HStack(spacing: 6) {
            if package.storeProduct.productIdentifier == ProCatalog.lifetime {
                Image(systemName: "infinity").accessibilityHidden(true)
            }
            Text(title)
        }
        .font(.body.weight(.semibold))
    }

    private var trialBadge: some View {
        Text("Free trial")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(ProPaywallStyle.accent, in: .capsule)
    }

    private var price: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(package.localizedPriceString).font(.body.weight(.semibold))
            Text(interval).font(.caption).foregroundStyle(ProPaywallStyle.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Decorative examples, never real profiles or interactive account controls.
private struct ProProfilePreview: View {
    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width / 3.05, 104)
            HStack(spacing: -2) {
                ProPreviewCard(title: "Work", badgeColor: .blue, width: width)
                    .rotationEffect(.degrees(-5)).offset(y: 8)
                ProPreviewCard(title: "Personal", badgeColor: .purple, width: width)
                    .zIndex(1)
                ProPreviewCard(title: "Study", badgeColor: .teal, width: width)
                    .rotationEffect(.degrees(5)).offset(y: 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 126)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private struct ProPreviewCard: View {
    let title: String
    let badgeColor: Color
    let width: CGFloat

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "envelope.fill")
                .font(.system(size: width * 0.32, weight: .regular))
                .foregroundStyle(ProPaywallStyle.accent)
                .frame(width: width * 0.56, height: width * 0.56)
                .background(.white, in: .rect(cornerRadius: 14))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 25, height: 25)
                        .background(badgeColor, in: .circle)
                        .offset(x: 7, y: 6)
                }
            Text(title).font(.system(size: 13, weight: .medium))
        }
        .frame(width: width, height: 112)
        .background { ProPaywallSurface(cornerRadius: 18) }
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }
}

struct LitePrivacyView: View {
    var body: some View {
        List {
            Section("Your library") {
                Text("Lite stores your profiles, groups, bookmarks, and settings on your device. Each profile uses an isolated WebKit data store. Websites receive the information you provide to them and handle it under their own privacy policies.")
            }
            Section("Purchases") {
                Text("Apple processes payments. RevenueCat validates purchases and manages Lite Pro access using an anonymous app user ID, purchase history, and technical information needed to operate the purchase service and understand purchase performance. Lite does not send browsing history, website sign-ins, bookmarks, or downloaded files to RevenueCat. Automatic device identifier collection is disabled.")
                Link("RevenueCat privacy policy", destination: URL(string: "https://www.revenuecat.com/privacy/")!)
            }
            Section("Website icons and privacy") {
                Text("Icons may be requested from a website and its image hosts without sign-in cookies. Lite includes no advertising SDK and does not sell your browsing data. Optional camera, microphone, and biometric access requires your permission.")
            }
            Section("Your choices") {
                Text("Delete a profile to remove its local website data, or clear website data in App Settings. Deleting Lite removes its local library. Deleting the app does not cancel an Apple subscription; use Manage Subscriptions to cancel.")
                Link("Full privacy policy", destination: URL(string: "https://aniket-pd.github.io/lite-app-support/#privacy")!)
                Link("Contact support", destination: URL(string: "mailto:aniketprasad123@gmail.com")!)
            }
        }.navigationTitle("Privacy").navigationBarTitleDisplayMode(.inline)
    }
}

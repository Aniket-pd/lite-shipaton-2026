import SwiftUI

/// One stable selection drives the hero, copy, and progress. Preview artwork is
/// native, decorative UI: it never reads accounts or creates website sessions.
struct LiteOnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var page: IntroPage = .library
    @State private var finished = false
    @AccessibilityFocusState private var focusedPage: IntroPage?
    let onComplete: () -> Bool
    let onSkip: () -> Bool

    private var reduceMotion: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting"), arguments.contains("--uitesting-reduce-motion") {
            return true
        }
        #endif
        return systemReduceMotion
    }

    private var motion: Animation? {
        reduceMotion ? nil : .interpolatingSpring(duration: 0.65, bounce: 0, initialVelocity: 0)
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = typeSize.isAccessibilitySize || geometry.size.height < 580
            ZStack(alignment: .bottom) {
                if !compact {
                    // The preview shares the entire screen with the foreground;
                    // enlarged pages flow behind the copy and system safe areas.
                    GeometryReader { canvas in
                        hero(height: min(canvas.size.height * 0.70, (canvas.size.width - 72) / (0.49 * 1.3 * 1.052)))
                            .padding(.top, canvas.size.height * 0.16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    navigation
                    if compact {
                        ScrollView {
                            VStack(spacing: 24) {
                                hero(height: 190)
                                caption(page)
                                    .accessibilityFocused($focusedPage, equals: page)
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity)
                        }
                        footer
                    } else {
                        Spacer(minLength: 0)
                        VStack(spacing: 0) {
                            captions.padding(.vertical, 16)
                            footer
                        }
                        .background {
                            lowerBlur
                                .padding(.top, -24)
                                .padding(.horizontal, -40)
                                .padding(.bottom, -geometry.safeAreaInsets.bottom - 40)
                        }
                    }
                }
                .frame(maxWidth: 580)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .simultaneousGesture(pageSwipe)
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: page)
    }

    private var navigation: some View {
        HStack {
            backButton
            .disabled(page == .library)
            .opacity(page == .library ? 0 : 1)
            .accessibilityHidden(page == .library)
            .accessibilityLabel("Previous page")
            .accessibilityIdentifier("onboarding.back")
            Spacer()
            Button("Skip") { finish(create: false) }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("onboarding.skip")
        }
        .padding(.horizontal, 22)
    }

    @ViewBuilder private var backButton: some View {
        if #available(iOS 26.0, *) {
            backAction
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .frame(minWidth: 44, minHeight: 44)
        } else {
            backAction
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.08), in: .circle)
                .buttonStyle(.plain)
        }
    }

    private var backAction: some View {
        Button { move(to: page.previous) } label: {
            Image(systemName: "chevron.backward")
                .font(.body.weight(.semibold))
        }
    }

    private var pageSwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                // Ignore short or mostly vertical drags so accessible text can
                // scroll normally. Reuse the same transition as the buttons.
                let horizontal = value.translation.width
                guard abs(horizontal) >= 20,
                      abs(horizontal) > abs(value.translation.height) * 1.35,
                      abs(horizontal) >= 48 || abs(value.predictedEndTranslation.width) >= 120 else { return }
                move(to: horizontal < 0 ? page.next : page.previous)
            }
    }

    private func hero(height: CGFloat) -> some View {
        let phoneHeight = max(100, height - 30)
        let scale = reduceMotion ? 1 : page.scale
        // Resolve the pivot to a translation so scale and translation interpolate
        // together, without also animating a moving transform origin.
        let translation = CGSize(
            width: (0.5 - page.anchor.x) * (scale - 1) * phoneHeight * 0.49,
            height: (0.5 - page.anchor.y) * (scale - 1) * phoneHeight
        )
        return IntroPhonePreview(page: page, reduceMotion: reduceMotion)
            .frame(width: phoneHeight * 0.49, height: phoneHeight)
            .scaleEffect(scale)
            .offset(translation)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    private var captions: some View {
        // Measure the tallest caption, keeping the footer still on every page.
        ZStack {
            ForEach(IntroPage.allCases) { item in
                caption(item).hidden().accessibilityHidden(true)
            }
        }
        .overlay {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(IntroPage.allCases) { item in
                        caption(item)
                            .accessibilityFocused($focusedPage, equals: item)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .compositingGroup()
                            .blur(radius: reduceMotion || item == page ? 0 : 30)
                            .opacity(item == page ? 1 : 0)
                            .accessibilityHidden(item != page)
                            .id(item)
                    }
                }
                .offset(x: -CGFloat(page.position) * geometry.size.width)
                .frame(width: geometry.size.width, alignment: .leading)
                .clipped()
            }
        }
    }

    /// A feathered backdrop blurs the preview underneath the entire lower stack.
    /// Extending the surface offscreen avoids a panel edge at the home indicator.
    private var lowerBlur: some View {
        Group {
            if reduceTransparency {
                Rectangle().fill(.black)
            } else if #available(iOS 26.0, *) {
                Rectangle().fill(.clear)
                    .glassEffect(.clear.tint(.black.opacity(0.5)), in: .rect)
                    .blur(radius: 20)
            } else {
                Rectangle().fill(.ultraThinMaterial)
                    .overlay(.black.opacity(0.5))
                    .blur(radius: 20)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func caption(_ item: IntroPage) -> some View {
        VStack(spacing: 10) {
            Text(item.title)
                .font(.title.bold())
                .tracking(-0.5)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("onboarding.title.\(item.rawValue)")
            Text(item.message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .lineSpacing(2)
                .frame(maxWidth: 330)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        VStack(spacing: 22) {
            HStack(spacing: 6) {
                ForEach(IntroPage.allCases) { item in
                    Capsule()
                        .fill(.white.opacity(item == page ? 1 : 0.4))
                        .frame(width: item == page ? 25 : 6, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Onboarding progress")
            .accessibilityValue("Page \(page.position + 1) of \(IntroPage.allCases.count)")
            .accessibilityIdentifier("onboarding.progress")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: move(to: page.next)
                case .decrement: move(to: page.previous)
                @unknown default: break
                }
            }
            primaryButton
        }
        .padding(.horizontal, 30)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    @ViewBuilder private var primaryButton: some View {
        if #available(iOS 26.0, *) {
            actionButton.buttonStyle(.glassProminent).tint(.blue)
        } else {
            actionButton.buttonStyle(.borderedProminent).tint(.blue)
                .buttonBorderShape(.capsule)
        }
    }

    private var actionButton: some View {
        Button {
            if page == .protection { finish(create: true) }
            else { move(to: page.next) }
        } label: {
            Text(page == .protection ? "Open My Library" : "Continue")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 42)
                .padding(.vertical, 3)
        }
        .disabled(finished)
        .accessibilityIdentifier("onboarding.continue")
    }

    private func move(to destination: IntroPage) {
        guard !finished, destination != page else { return }
        withAnimation(motion) { page = destination }
        focusedPage = destination
    }

    private func finish(create: Bool) {
        guard !finished else { return }
        finished = create ? onComplete() : onSkip()
    }
}

enum IntroPage: String, CaseIterable, Identifiable {
    case library, webpage, accounts, privacy, protection
    var id: Self { self }
    var position: Int { Self.allCases.firstIndex(of: self)! }
    var next: Self { Self.allCases[min(position + 1, Self.allCases.count - 1)] }
    var previous: Self { Self.allCases[max(position - 1, 0)] }
    var scale: CGFloat {
        switch self { case .library: 1; case .webpage: 1.2; case .accounts: 1.3; case .privacy: 1.15; case .protection: 1.2 }
    }
    var anchor: UnitPoint {
        switch self { case .library: .center; case .webpage: .init(x: 0.5, y: 0.15); case .accounts: .bottom; case .privacy: .center; case .protection: .init(x: 0.5, y: -0.1) }
    }
    var title: LocalizedStringKey {
        switch self {
        case .library: "Your apps.\nA little lighter."
        case .webpage: "Browse any site.\nAdd it to Lite."
        case .accounts: "One website.\nYour own spaces."
        case .privacy: "Only you.\nUnlocked by you."
        case .protection: "Less tracking.\nMore privacy."
        }
    }
    var message: LocalizedStringKey {
        switch self {
        case .library: "Six apps are ready in your library. Open your favorite websites like apps, right here in Lite."
        case .webpage: "Browse any website or webpage in Discover, then tap Add to Lite to save it to your library."
        case .accounts: "Keep work and personal accounts separate. Each profile has its own sign-in and website data."
        case .privacy: "Require Face ID or Touch ID to open the profiles you choose."
        case .protection: "Ad and tracker blocking is on by default for every profile. Block known ads and trackers as you browse."
        }
    }
}

#Preview {
    LiteOnboardingView(onComplete: { true }, onSkip: { true })
}

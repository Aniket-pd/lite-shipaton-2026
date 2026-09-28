# Lite onboarding

## Release navigation regression (2026-09-24)

`OnboardingPolicy.initialPresentation()` must be read-only because it runs in
`HomeView`'s `@State` initializer. Writing the started preference there repeatedly
invalidated `@AppStorage` readers and recreated the view, keeping the main thread
in SwiftUI updates and preventing Continue and swipe input. The screen's `.task`
now calls the idempotent `markStarted()` before legacy-icon backfill can run.

Reproduced on a fresh iPhone 13 simulator with an unmodified Release build.
Verified the fix in Release: Continue, forward/backward swipes, all five pages,
and completion into the six-app starter library. Debug UI tests use a separate
defaults suite, so first-launch Release interaction remains a necessary smoke
check for this regression.

Lite now uses the [documented iOS 26 onboarding pattern](ONBOARDING_STYLE_REFERENCE.md) for a five-page introduction. It is implemented in native SwiftUI and supports the app’s iOS 17 deployment target.

## Experience

| Page | Preview | Action |
| --- | --- | --- |
| Your apps. A little lighter. | Shared library tiles using bundled website icons | Continue |
| Browse any site. Add it to Lite. | Actual Discover tab with its search/paste field and website suggestions | Continue or Back |
| One website. Your own spaces. | Personal and Work profiles with separate website data | Continue or Back |
| Only you. Unlocked by you. | Shared lock-screen content explaining Face ID / Touch ID | Continue or Back |
| Less tracking. More privacy. | Actual privacy settings with ad and tracker blocking enabled | Open My Library |

The final action and Skip save six starter profiles and open the library directly: Instagram, Reddit, X, LinkedIn, Gmail, and YouTube. There is no manual creation step. Saving completes before onboarding is marked complete; a failure leaves the intro available for retry. No website sign-in, purchase, or permission is requested. Preview content renders shared app UI with temporary sample models. It uses no personal data and makes no network requests. Samples are never inserted into SwiftData; taps and accessibility are disabled for the decorative canvas.

Captured implementation screens: [Welcome](screenshots/onboarding-welcome.png), [Add any webpage](screenshots/onboarding-webpage.png), [Separate accounts](screenshots/onboarding-accounts.png), [Face ID protection](screenshots/onboarding-privacy.png), [Ad and tracker protection](screenshots/onboarding-protection.png).

## Motion and layout

`IntroPage` is the single selection shared by two horizontal content strips, the phone’s scale and anchor, caption visibility, and the page capsules. Navigation supports buttons, horizontal swipes, and VoiceOver-adjustable progress. Horizontal swipes advance or return one page on release using the same transition; they never complete onboarding or wrap past an endpoint. A drag must travel at least 20 points, be predominantly horizontal (1.35× its vertical movement), and either travel 48 points or project to 120 points for a quick flick. The gesture runs simultaneously with the accessibility layout’s vertical scroll view. Both strips retain their contents and use stable enum identities. Their offsets are driven directly by the same animation transaction, removing independent programmatic scroll settling. There are no asynchronous delays or independent page counters.

Values from the reference:

- Interpolating spring: duration **0.65**, bounce **0**, initial velocity **0**.
- Caption blur: **30 → 0 points** on entry, with opacity **0 → 1**; outgoing text does the inverse while scrolling.
- Progress capsules: active **25 × 6**, inactive **6 × 6**, gap **6**, inactive opacity **0.4**.
- Hero: normal **1×**, Discover **1.2× / (0.5, 0.15) anchor**, profiles **1.3× / bottom anchor**, privacy **1.15× / center anchor**, blocking **1.2× / (0.5, −0.1) anchor**.
- Clear glass tinted black behind the entire lower stack, with an iOS 17 material-blur fallback.

Lite-specific adaptations: shared native app components replace screenshots, and the tallest caption determines reserved copy space. The preview occupies a full-screen layer that ignores safe areas, scales behind the foreground, and is no longer clipped into a separate upper section. Its width reserves lateral breathing room even at 1.3×, with a larger top inset. Page-specific pivots are resolved into a center-based scale plus translation, so a changing transform origin cannot distort the transition path. A feathered glass surface extends behind captions, progress, CTA, and the bottom safe area. The top navigation contains only Back and Skip, with no wordmark or upper blur. Back uses a native circular Liquid Glass button on iOS 26, with a plain circular fallback on iOS 17–25 and a minimum 44-point target. The footer ends at the primary action, with no account-needed caption. Controls retain safe-area insets for reachability. The outer onboarding background stays black with blurred glass and no added gradients. The atmospheric background inside the phone frame has been removed; previews use neutral system backgrounds. The rest of the app’s background preference is unchanged. The CTA and progress remain stationary across ordinary page changes. The separator’s 20-point blur is a chosen value; its call-site radius was not verified in the original tutorial. Unlike the reference’s scale-dependent opacity, Lite keeps the separator present on every page because the larger preview overlaps the foreground even at 1×.

Captions use Dynamic Type styles: bold title (28 points at the default size) and subheadline body (15 points), with 10-point spacing and 2-point body line spacing. These smaller styles keep the phone preview prominent while continuing to scale with accessibility settings.

Reduce Motion removes zoom, caption blur, and animated page movement. Reduce Transparency uses an opaque caption backing. Accessibility text sizes and short windows switch to a vertically scrollable preview/caption area with reachable actions. Decorative previews are excluded from VoiceOver; inactive captions are hidden, and progress is adjustable. The visible caption receives accessibility focus after navigation. A native selection haptic confirms each actual page change, including swipes and button navigation; taps or swipes against the first/last boundary produce no feedback. Physical haptic feel must be checked on a supported iPhone.

## First-launch policy

- Fresh, empty installations show the introduction.
- Completing or skipping stores `lite.onboarding.v1.completed`.
- Starting stores `lite.onboarding.v1.started`, so a later launch can resume the introduction even after startup backfill has completed. Page position itself restarts at page one.
- The existing `lite.iconBackfill.v2.completed` marker identifies prior app usage, including an existing empty library. These installations bypass onboarding.
- A populated library bypasses onboarding and clears pending enrollment through completion.
- An incoming widget, Shortcut, or URL open request takes priority and retains the existing authentication/missing-app behavior.
- Model-container failure handling remains outside onboarding.

`HomeView` preserves its state and shared sheet/browser presentation handlers while switching between onboarding and the tabs. The library is not exposed underneath the intro to accessibility or touch. Completion and Skip both use `StarterLibrary.installIfEmpty(in:)` and select Library. This only seeds a new, empty library leaving onboarding; existing installations are not changed. Completion persists, so deleting starter apps later does not restore them. Each starter has its own WebKit data-store identity, bundled icon, and blocking enabled. Starter profiles are exempt from the three added-profile limit; duplicates count toward that limit.

## Files

| File | Responsibility |
| --- | --- |
| `lite/Views/LiteOnboardingView.swift` | Layout, motion, accessibility, page model, buttons |
| `lite/Views/IntroPhonePreview.swift` | Phone frame and read-only compositions of shared app components |
| `lite/Services/OnboardingPolicy.swift` | Eligibility, completion, and interrupted-launch enrollment |
| `lite/Views/HomeView.swift` | Presentation and starter-library handoff |
| `lite/Services/StarterLibrary.swift` | Atomic, empty-library-only starter insertion |
| `liteTests/StarterLibraryTests.swift` | Persistence, idempotence, existing-data protection, and free-slot behavior |
| `lite/liteApp.swift` | Test-only preference preparation at launch |
| `liteTests/OnboardingPolicyTests.swift` | New/returning-user and UI-test eligibility |
| `liteUITests/OnboardingUITests.swift` | Navigation, completion, interruption, Skip, incoming links, accessibility |

## Development and verification

Ordinary `--uitesting` launches continue to bypass onboarding. Test completion uses a separate defaults suite, `aniket.lite.onboarding.tests`, leaving the installation’s real completion preference unchanged.

Debug launch arguments:

```text
--uitesting --uitesting-onboarding --uitesting-onboarding-reset
```

Remove `--uitesting-onboarding-reset` to check completion persistence. Add `--uitesting-reduce-motion` to exercise the same view branch as the system Reduce Motion preference without changing the simulator’s global setting. These options have no release behavior.

Run `OnboardingPolicyTests` and `OnboardingUITests`, plus existing catalog and locked-link UI tests when modifying `HomeView` routing. Visually inspect forward and reverse transitions, especially zoom clipping, caption clearance, progress, and the stationary CTA.

The implementation has been built with the iOS 26 SDK. Simulator test results and inspected screenshots are recorded in the task; iOS 17 has compile-time fallback coverage, not a runtime validation claim. A simulator recording was inspected for horizontal preview movement, caption blur, zoom, and fixed controls. This is a source-parameter match and visual verification, not a claim of pixel-for-pixel equivalence to the tutorial’s different artwork or frame-level timing measurement.

Validation on 24 September 2026:

- Swipe/glass revision: navigation/completion/relaunch, bidirectional swipe and endpoint handling, and vertical accessibility scrolling with Reduce Motion all passed (3 UI tests). Signed device build installed and launched on Aniket’s iPhone. Screenshots reflect this revision; simulator tests cannot validate the physical haptic sensation.

- Starter-library revision: all six onboarding UI tests, both onboarding policy tests, six entitlement tests, and three starter-library tests passed across the initial run and a targeted rerun. The rerun corrected two tests that prematurely released their model container. Signed device build succeeded and the onboarding preview was installed and launched on Aniket’s iPhone. Earlier screenshots have been refreshed for the swipe/glass revision.

Earlier validation on 23 September 2026:

- Header/footer cleanup: signed iPhone build and navigation/completion/relaunch UI test passed. The top wordmark, upper blur, and footer caption were removed.
- Discover-preview and smaller-text revision: signed iPhone build succeeded and was installed and launched on Aniket’s iPhone. Navigation/completion/relaunch, largest accessibility text, and Reduce Motion UI tests passed (3 tests) on iPhone 17 Pro, iOS 26.2.
- Earlier integration checks passed for both eligibility unit tests, Skip/interruption, existing-library bypass, incoming-link priority, compact website picker, independent profile creation, and icon/badge persistence. Earlier layout checks also passed on iPhone 16e.
- The existing `testGridSwitcherAndDeepLinkAllEnforceLock` has an outdated selector at line 377: it expects `home.app.Locked Fixture`, while the grouped library exposes `home.app.Example`. That test is unchanged and its lock assertions are not certified by this work.

## Shared app UI in previews

- `LibraryWebsiteTile` is extracted from `LiteAppGridButton`; the live library and onboarding use exactly the same icon, name, and badge presentation. The first onboarding preview omits the plus/profile toolbar controls.
- `DiscoverView` is embedded directly in a native tab container with Discover selected. Its per-instance `allowsAtmosphere` option is false only in onboarding, preserving the user's app background preference.
- `ProfilePickerRow` is used by the live profile picker and the onboarding accounts example. Preview callbacks do nothing and the canvas rejects input.
- `ContainerPreferencesView(privacyOnly: true)` supplies the final privacy preview using a detached sample profile. The canvas rejects input so no preferences can be saved.
- The preview uses native `NavigationStack`, `List`, and `TabView` containers. The canvas is 390 × 795 points; its 18-point strip spacing scales proportionally to the original 12-point gap on a 260-point canvas.
- Profile fetching, persistence, biometric prompts, and purchase flows remain outside the previews. The app's existing Pro environment supplies appearance-control availability without starting a second purchase observer.

## Protection messaging

The fifth step is dedicated to privacy, ad blocking, and tracker blocking. The real privacy controls show blocking enabled, and the caption explains that it is on by default for each profile. It does not promise that every ad will disappear. The fourth step explains optional Face ID / Touch ID protection. Its `AppLockContent` is the same presentation used by `ContainerAccessView`, supplied with an inert unlock callback; onboarding never changes locks, requests biometric authentication, or opens a browser. Authentication remains in `ContainerAccessView`.

## Adding webpages

The second step explicitly teaches: browse any website or webpage in Discover, then tap **Add to Lite** to save it to the library. It renders the real `DiscoverView`, including its search/paste field, suggested websites, and selected Discover tab. The preview remains decorative, cannot access the paste button through touch or VoiceOver, and does not open or fetch websites. The sequence teaches the core action before profiles and protection, then ends in a populated library.

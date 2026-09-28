# Run and evaluate Lite

This is a review snapshot of the latest main checkout, including current local fixes. See the source manifest in the submission review packet for provenance.

## Build

1. Open `lite.xcodeproj` in Xcode. Resolve Swift Package Manager dependencies (including RevenueCat).
2. Select scheme **Lite**, then an iPhone simulator. iOS 17 or later is the deployment target.
3. Run the app. Internet access is needed to load websites and RevenueCat offerings.

Command-line simulator build:

```sh
xcodebuild -project lite.xcodeproj -scheme Lite \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/LiteJudgingBuild CODE_SIGNING_ALLOWED=NO build
```

For a physical device, choose your own development team and configure the app/widget App Group entitlement. See README.md and Configuration/*.entitlements. No private signing keys are included.

## Suggested walkthrough

- Launch a fresh installation and read all five onboarding screens.
- Open Discover, search with DuckDuckGo for Wikipedia, visit the result, and choose Add to Lite.
- Give the website a profile name and create it. Reopen it from the Library.
- Create another profile for a service and inspect the account switcher. Use separate test accounts if testing real sign-in; the demo does not supply login credentials.
- Create a group and add several Lite Apps.
- Open an app's settings and inspect Privacy & permissions, website data, and Require Face ID. Simulator biometrics can be enrolled and matched through the simulator Features menu.
- Open Lite Pro to inspect the RevenueCat offering. Test purchases only with appropriate sandbox/TestFlight configuration. Do not make a real purchase to evaluate this draft.

## Monetization

RevenueCat project ID: `4fb07ddd`; entitlement: `pro`; offering: `default`. The embedded `appl_` SDK key is an app-scoped public identifier, not a server secret. No private RevenueCat or Apple credentials are included. `docs/LITE_PRO_SETUP.md` distinguishes completed setup from transaction scenarios that still need validation.

## Limitations

Websites can restrict embedded browsers or require native app features. Blocking is best effort, with per-profile controls. Storage savings are usage-dependent. The source package's first build is recorded in the review packet; previous testing is documented in `docs/TESTING.md`. A successful build is not proof that every sandbox purchase scenario has been completed.

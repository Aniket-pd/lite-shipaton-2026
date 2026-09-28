# Testing Lite

## Saved glass surfaces — September 21, 2026

Search now uses native interactive Liquid Glass in a capsule; the filter uses a
glass circle with a plain filter symbol. The header shares a GlassEffectContainer.
iOS 17–25 use a material fallback, and Reduce Transparency uses solid surfaces.
Saved rows and Groups cards now share `GroupCardMaterial`, preserving Groups’
translucent fill and highlight gradient. The filter stays beside the tabs and
search remains full-width below.

The search/sort/filter/reset and largest-text UI flows both passed on iPhone 16e,
iOS 26.0, as recorded in `/tmp/lite-saved-glass-tests.log`. The Mac ran out of
space while Xcode finalized that run’s result archive; the stalled archive was
discarded after preserving the log. After clearing older task build caches, the
complete header flow passed again with diagnostic collection disabled in
`/tmp/LiteSavedGlassPreview.xcresult`. Its [dark](screenshots/saved-glass-dark.png),
[light](screenshots/saved-glass-light.png), and
[downloads](screenshots/saved-glass-downloads.png) screenshots were inspected.
Older-iOS and accessibility-material fallbacks were reviewed in code only.

Signed Release **2.2 (15)** app and widget builds passed with valid signatures.
Build 15 was installed in place and launched on Aniket’s iPhone 13, preserving
app and account data. Build log: `/tmp/lite-saved-glass-device.log`; receipts:
`/tmp/LiteSavedGlassDeviceInstall.json` and `/tmp/LiteSavedGlassDeviceLaunch.json`.

## Saved alignment refinement — September 21, 2026

The filter now sits at the trailing end of the tabs row, with full-width search
8 points below. Section headings and list edges share the header's 16-point side
margins; section headings use 12-point top and 8-point bottom insets. This update
changes placement and spacing only.

Both focused UI flows passed in `/tmp/LiteSavedAlignmentTests.xcresult` on
iPhone 16e, iOS 26.0: search/sort/filter/reset and largest accessibility text.
Screenshots were inspected in [dark](screenshots/saved-alignment-dark.png),
[light](screenshots/saved-alignment-light.png), and
[large text](screenshots/saved-alignment-large-text.png).

Signed Release **2.2 (14)** app and widget builds passed, and signature validation
succeeded. Build 14 was installed in place and launched on Aniket’s iPhone 13.
No app or account data was removed. Build log:
`/tmp/lite-saved-alignment-device.log`; device receipts:
`/tmp/LiteSavedAlignmentDeviceInstall.json` and
`/tmp/LiteSavedAlignmentDeviceLaunch.json`.

## Minimal Saved header — September 21, 2026

Bookmarks and Downloads now use text tabs with a small selection underline.
The always-visible search field has a flat, borderless background, with filter
and sort combined in one adjacent button. Active filters show their scope and a
reset action. The tabs stack at accessibility text sizes, preserve selected
accessibility traits, and retain 44-point touch targets. Container Saved shares
the same tabs and search field.

Four focused Saved UI flows passed on iPhone 16e (390 × 844 points), iOS 26.0,
with Xcode 26.3 in `/tmp/LiteSavedHeaderTests.xcresult`: search/sorting/container
scope, locked-content search privacy, authentication before presentation, and
largest accessibility text. After correcting a faint placeholder in light
appearance, both the complete header interaction flow and largest-text flow
passed again in `/tmp/LiteSavedHeaderFinalTests.xcresult`.

Actual DEBUG-fixture screenshots were inspected in
[light](screenshots/saved-header-light.png),
[dark](screenshots/saved-header-dark.png), and
[large text](screenshots/saved-header-large-text.png); a
[downloads view](screenshots/saved-header-downloads.png) is also recorded.
VoiceOver speech and iOS 17 runtime behavior were not exercised in this update.

Signed Release **2.2 (13)** app and widget builds passed, including signature
verification and exclusion of the Saved layout fixture. The app is at
`/tmp/LiteSavedLayoutDeviceBuild/Build/Products/Release-iphoneos/lite.app`;
build log: `/tmp/lite-saved-header-device-final.log`.
After Aniket’s iPhone reconnected, build 13 was installed in place and launched
successfully. No app or account data was removed. Device receipts:
`/tmp/LiteSavedHeaderDeviceInstall.json` and
`/tmp/LiteSavedHeaderDeviceLaunch.json`.

## Compact Saved layout — September 21, 2026

Saved opens directly on its section switch, always-visible search, container
filter, and sort control, without a navigation-title row. Bookmarks and downloads
use compact date-grouped rows; name sorting uses natural numeric order. Active
downloads remain above completed files and show progress without disabled styling.
Locked containers appear only in the filter, with the existing authentication
boundary protecting their contents. The locked-only empty state explains where
to unlock; empty locked containers and private titles/counts remain hidden.

**24 distinct checks passed across the initial and focused runs** on iPhone 16e
(390 × 844 points), iOS 26.2, using Xcode 26.3: three calendar/sorting checks,
12 Saved storage checks, and nine Saved UI flows. Coverage includes daylight
saving boundaries, search and filtering, name ordering, active-download placement,
locked search privacy, authentication before presentation, restart persistence,
browser-state preservation, Quick Look, Files export cancellation, container
switching, and reachable controls at the largest accessibility text size.

The initial `/tmp/LiteSavedLayoutTests.xcresult` contains one test-only failure:
XCTest reported a 44-point action target as `43.99999999999994`. The assertion now
allows 0.001 points of numeric error while preserving the 44-point requirement.
Its focused rerun passed in `/tmp/LiteSavedLayoutAccessibility.xcresult`. After
visual refinements to container labels and download progress, all four affected
UI flows passed in `/tmp/LiteSavedLayoutFinalUI.xcresult`.
The final intrinsic-height adjustment for large search/filter labels also passed
in `/tmp/LiteSavedLayoutFinalFit.xcresult`, and its screenshot was inspected.

Actual simulator screenshots use isolated DEBUG fixtures:
[bookmarks](screenshots/saved-layout-bookmarks-dark.png),
[downloads](screenshots/saved-layout-downloads-dark.png), and
[large text](screenshots/saved-layout-large-text.png).
Light appearance, VoiceOver speech, iOS 17 runtime behavior, and successful
physical Face ID matching were not exercised in this run.

Signed Release **2.2 (12)** builds for the app and widget passed, including
`codesign --verify --deep --strict` and exclusion of the Saved layout fixtures.
The final build is at
`/tmp/LiteSavedLayoutDeviceBuild/Build/Products/Release-iphoneos/lite.app`;
log: `/tmp/lite-saved-layout-device-delivery-generic.log`.
Aniket’s iPhone 13 reconnected, and this build was successfully installed and
launched on September 21, 2026. No device app or account data was removed.

## Groups carousels — September 20, 2026

Seven focused checks passed on **iPhone 16e, 390 × 844 points, iOS 26.2** with Xcode 26.3 and the iOS 17 deployment target. The four UI flows cover centered snapping, independent group positions, direct launch from a neighbouring icon, position restoration after closing an app or changing tabs, the complete app list and biometric gate, editing the focused member, deleting a group while keeping its library apps, group creation, light appearance, and maximum accessibility text. The three existing collection tests cover migration, persisted membership/profile identity, and non-destructive group deletion.

Results: `/tmp/LiteGroupsTests.xcresult` (model and UI checks), `/tmp/LiteGroupsFinalUI.xcresult` (four UI flows after layout refinement), and `/tmp/LiteGroupsLabelsUI.xcresult` (launch and appearance checks after reserving two lines for account names). Initial-layout screenshots, before the final focus and dimming refinements, use DEBUG-only, in-memory fixtures: [dark](screenshots/groups-carousel-dark.png), [light](screenshots/groups-carousel-light.png), and [accessibility text](screenshots/groups-accessibility-text.png).

The final icons remain front-facing. Neighbours dim to 78% opacity, only the focused name appears with a 0.1-second fade, the selector fades over 0.2 seconds, and selection haptics accompany changes between valid app positions. Signed Release builds were installed in place and launched successfully on Aniket’s iPhone 13 throughout refinement. Haptic feel requires device review.

After integration with the latest main branch, all four focused regression checks passed in `/tmp/LiteGroupsMainIntegration.xcresult`: the three collection model tests and the carousel snapping, direct-launch, position-restoration, and biometric-gate UI flow.

Reduce Motion removes icon scaling and focus fades; Reduce Transparency uses a solid card surface; increased contrast strengthens borders and preserves icon opacity. Those environment branches were reviewed in code. VoiceOver speech, physical-device motion/performance, iPad layout, and the iOS 17 runtime were not exercised in this simulator run.

## Optional container proxy — September 19, 2026

**36 selected checks passed across the final validation runs**: 34 unit/integration cases in `/tmp/LiteProxyFinalTests.xcresult` and two final UI cases in `/tmp/LiteProxyUIRegression.xcresult`. The final signed Debug simulator build succeeded with Xcode 26.3, retaining the iOS 17 deployment target. Validation ran on iPhone 17 Pro / iOS 26.2. Use simulator ad-hoc signing (`CODE_SIGN_IDENTITY=-`), not `CODE_SIGNING_ALLOWED=NO`, for tests that exercise Keychain.

New checks cover endpoint/port validation, settings persistence and migration defaults, independent profile routes, refusing in-process route changes, authenticated duplicates blocking without credentials, Keychain separation, and deleting one profile’s credentials while preserving another’s. A controlled TCP listener observes a TLS handshake from the configured HTTPS proxy client and then rejects it. The test first confirms `https://example.com` is reachable directly, then verifies the separate proxied profile fails without receiving an HTTP response from that origin. This test needs public HTTPS access to example.com. A separate icon test confirms URLSession reaches the TLS proxy and returns no icon after rejection. Existing cookie-isolation, popup/protection, preference, data-cleanup, and favicon checks remain passing.

A localhost-origin probe exposed WebKit bypassing the proxy on iOS 26.2; that limitation is disclosed in settings and the README. Proxy failure protection is not a complete VPN or a DNS/WebRTC leak guarantee. The final UI tests cover validation, save/reopen, restart gating, and existing preferences/reset/diagnostics navigation. The settings screen was visually inspected from its test screenshot.

No live authenticated proxy provider, successful exit-IP change, or iOS 17 runtime was available for end-to-end validation. Before release, exercise a trusted HTTPS CONNECT provider with credentials, normal pages/subresources, login popups, downloads, and route changes across a full app restart. The signed Release 2.2 (5) build was subsequently installed in place on Aniket’s iPhone 13 (iOS 26.5.2) and launched successfully. The app was not uninstalled or its website data cleared. Signing verification passed, and the built binary contains the new proxy settings. Receipts: `/tmp/LiteProxyDeviceInstall.json` and `/tmp/LiteProxyDeviceLaunch.json`; build log: `/tmp/lite-popup-device-build.log`. Live authenticated-provider validation remains outstanding.

After integration with main’s Settings redesign, all **7 focused checks** (six proxy unit/integration tests and the complete proxy UI flow) passed in `/tmp/LiteProxyMainIntegration.xcresult`. The signed simulator build succeeded. Proxy entry points and help now use **App Settings → Encrypted Proxy**, matching main’s navigation.

## Immersive browser layout — September 19, 2026

All **19 selected checks passed** in `/tmp/LiteImmersiveRegression.xcresult`: three appearance/scroll-state tests, eight existing browser-protection integration tests, and eight UI flows. The final menu adjustment also passed the popup/More/return regression in `/tmp/LiteImmersiveMenuFinal.xcresult`. Debug and Release simulator builds succeeded using Xcode 26.3 / iOS 26.2 SDK, with the iOS 17 deployment target retained.

Validation used one representative device: **iPhone 16e, 390 × 844 points, iOS 26.2**, system dark appearance. Deterministic pages exercise both dark and light page backgrounds, an unrelated theme-color accent, fixed website headers/footers, downward collapse, upward/tap expansion, and keyboard entry. Assertions verify additional visible page height, reachable website navigation, and unchanged website `prefers-color-scheme` while native appearance follows the page. Existing UI checks cover popup approval/return, nested windows, ad redirects, native upload/download/dialogs, account switching/creation, and maximum accessibility text. Native SwiftUI menus emit an internal `_UIReparentingView` runtime warning in this simulator; the menu actions and all selected tests completed successfully.

The new observable toolbar state uses the same explicit nonisolated-deinitializer workaround as `WebPage`; a focused test exposed the already-documented Swift runtime issue before that workaround was applied. No production JavaScript, viewport-meta rewriting, private APIs, or account migrations were introduced. The expanded and collapsed ImageGen reference guided the control layout; screenshots below are actual app renders with test-only website content.

Screenshots: [expanded dark](screenshots/browser-expanded-dark.png), [collapsed dark](screenshots/browser-collapsed-dark.png), [light website](screenshots/browser-expanded-light.png), [keyboard](screenshots/browser-keyboard.png), and [large text](screenshots/browser-large-text.png). Older iOS runtimes, rotation, and authenticated third-party website behavior were not separately exercised; VoiceOver/Reduce Motion/Reduce Transparency behavior was reviewed in code. The page-background signal cannot guarantee separate color matches for every differently colored header/footer or full-screen media frame.

The signed Release build was installed as an in-place update on Aniket’s connected iPhone 13 and launched successfully, using the existing `aniket.lite` bundle identifier. The app was not uninstalled and no website data was cleared. Signing verification passed. Device receipts: `/tmp/LiteImmersiveDeviceInstall.json`, `/tmp/LiteImmersiveDeviceLaunch.json`; build log: `/tmp/lite-immersive-device-build.log`.

### Device version audit and build 5

A subsequent device check found a different installed bundle directory, still labeled 2.2 (4), from the original redesign installation. The intervening installer was not identified. To distinguish revisions, the app and widget build numbers are now **5**, and About Lite displays the actual bundle version/build. Signed Release **2.2 (5)** was rebuilt, verified to contain the redesigned browser types, installed without deleting app data, and launched with the existing instance terminated. The installed-app record, launch receipt, and live process executable all matched the newly installed bundle. Evidence: `/tmp/LiteBuild5Install.json`, `/tmp/LiteBuild5Launch.json`, `/tmp/LiteBuild5InstalledCheck.json`, `/tmp/LiteBuild5ProcessCheck.json`; build log: `/tmp/lite-build5-final.log`.

## Build and automated tests

Open `lite.xcodeproj`, select the shared **Lite** scheme, then choose an iPhone simulator. The app supports iOS 17 and later; V2 is built with Xcode 26.0 and its iOS 26.0 SDK, and tested on the installed iOS 26.2 simulator.

```sh
xcodebuild -project lite.xcodeproj -scheme Lite \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -derivedDataPath /tmp/LiteDerivedData build CODE_SIGNING_ALLOWED=NO

xcodebuild -project lite.xcodeproj -scheme Lite \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -derivedDataPath /tmp/LiteDerivedData \
  -parallel-testing-enabled NO test CODE_SIGN_IDENTITY=-
```

Use `xcrun simctl list devices available` to select a different installed simulator. Add `-only-testing:liteTests` or `-only-testing:liteUITests` for one suite. Device builds need a signed-in development team and App Group provisioning for both targets (`group.aniket.lite`). Existing V1 wildcard profiles do not support that capability.

The tests cover:

- Distinct app and WebKit profile identities for two accounts on the same site.
- SwiftData disk persistence of the original profile identifier, URL, icon, and security preferences.
- Actual `WebSession` WebViews attached to persistent identified stores, isolated same-domain cookies, retained cookies after creating a new session, and deleting one profile without disturbing the other.
- URL normalization and rejection of credentials, missing hosts, and executable/local schemes.
- Content-rule compilation by WebKit, domain-boundary matching for resources/documents, cosmetic blocking, and external-link policy.
- Catalog and custom website creation, duplicate services with distinct names, cancellation, deleting only the selected app, and rendering a live website in the full-screen WebView and closing it.

UI tests pass the `--uitesting` launch argument, which uses an empty in-memory SwiftData container in Debug builds only. They do not erase the normal library or require service credentials. Persistence tests use their own temporary disk store; WebKit tests use random profile identifiers and remove them afterward. Tests do not sign into real accounts. The browser UI smoke test requires live HTTPS access to example.com and waits up to 25 seconds for its “Example Domain” heading before capturing the rendered page and dismissing it. If this check fails, inspect the captured screenshot, accessibility hierarchy, and network state before deciding whether the failure is environmental or an application bug; do not retry without diagnosis. Reconstructing a WebView in one test process validates profile reuse; the device checks below also verify survival across app termination and OS restart.

## Required release checks on a physical iPhone

### Isolated accounts and persistence

1. Create **Instagram Personal** and **Instagram Work** (or two test accounts for another supported service), and sign into a different account in each.
2. Switch between apps and navigate beyond the landing page; verify the correct account remains active.
3. Close and reopen Lite, force quit it, then restart the phone. Verify both identities remain separate. Account expiration initiated by the website is outside Lite's control.
4. Rename an app. Verify its account is unchanged.
5. Delete one Lite App. Verify the other remains signed in, and recreating the deleted service starts with a fresh profile.
6. Repeat deletion after browsing multiple pages and opening a sign-in popup. Verify no live WebView keeps the deleted profile in use.

### Biometric lock

- With Face ID/Touch ID enrolled, enable a lock, close the Lite App, and reopen it. Verify the website appears only after successful authentication.
- Cancel authentication and test a biometric mismatch/lockout. Verify no protected page becomes visible.
- Background Lite while a protected page is open; verify the app-switcher snapshot is obscured and returning requires authentication as designed.
- Test Face ID permission denied, no biometric enrollment, and a device without a passcode. Verify a clear error and that the app never silently disables its lock.
- Verify removing the lock requires authentication and does not delete cookies.

Simulator **Features → Face ID** can exercise enrolled, matching, and nonmatching states, but is not a substitute for physical-device checks or the actual permission prompt.

### Website compatibility and navigation

For **Instagram, Reddit, X, LinkedIn, Gmail, Amazon, and YouTube**, test landing page, ordinary password login, two-factor challenge, logout, back gesture/button, forward, reload, and popup dismissal. Also test a custom HTTPS site.

- Test each provider's OAuth/SSO buttons separately. Providers can reject embedded WebViews; Lite must show the failure without moving authentication into a shared Safari session or weakening profile isolation. Record provider, OS version, sign-in method, and result before claiming compatibility.
- Verify `target="_blank"` links and user-initiated sign-in popups keep the original app's profile and close correctly.
- Test JavaScript alert, confirm, and prompt on a development page; cancellation or closing the app must resolve outstanding dialogs.
- Test email, phone, SMS, and maps links; verify opening another app requires the intended prompt. Unsupported custom schemes should fail clearly.
- Turn on airplane mode, retry, reconnect, and verify recovery. Test an invalid HTTPS certificate without bypassing transport security.
- Verify videos play inline, stop/pause when appropriate, and do not continue from a locked background page.
- Verify website camera/microphone requests show the platform prompt and handle refusal. Check file/photo upload on a site that supports it.
- Verify attachment and blob downloads, native Files export/cancel, multiple download rejection, network failure, and cleanup when closing or locking a browser. Downloads remain in their originating WebKit profile.

### Privacy and accessibility

- With Safari Web Inspector or a controlled test page, confirm a listed third-party tracker is blocked while first-party content still loads. Domain and cosmetic lists do not block every first-party or video ad.
- Toggle protection for a site that breaks under blocking. Verify the setting persists for only that Lite App.
- Check light/dark appearance, portrait/landscape, iPad split view, large Dynamic Type, VoiceOver labels, and a small iPhone screen with the keyboard visible.
- Confirm no session data, URLs containing credentials, or website content appear in application logs.
- Run again on the oldest supported iOS release before shipping; only installed simulator runtimes can be validated locally.

## Public API verification

The implementation uses public APIs verified against the installed iOS 26.2 SDK headers:

- `WKWebsiteDataStore(forIdentifier:)`, `identifier`, and `remove(forIdentifier:)`: iOS 17+ (`WKWebsiteDataStore.h`).
- `WKHTTPCookieStore`, including set/get cookies: iOS 11+ (`WKHTTPCookieStore.h`).
- `WKContentRuleListStore` and `WKUserContentController.add(_:)`: iOS 11+.
- `WKNavigationDelegate`, `WKUIDelegate`, and `WKWebViewConfiguration` for navigation and popup creation; no private selectors or cookie-directory manipulation.

Apple documentation: [identified data stores](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/init(foridentifier:)), [content rule lists](https://developer.apple.com/documentation/webkit/wkcontentruleliststore), [LocalAuthentication](https://developer.apple.com/documentation/localauthentication).

## V1 local validation record

On September 18, 2026, the complete automated run passed **17 tests with zero failures**: 13 unit tests and four UI tests. Validation used Xcode 26.3 / iOS 26.2 SDK and an iPhone 17 Pro simulator running iOS 26.2.

- Unit coverage includes favicon frame selection and downsampling, SwiftData persistence, URL validation, privacy rules, real persistent WebKit cookie isolation, reopening, and profile deletion.
- UI coverage includes cancellation, two accounts for one service, custom website creation/deletion, and WebView presentation/dismissal. The deletion test starts before any WebView has opened, covering a cold WebKit cleanup.
- The isolated-account regression verifies the removed identifier disappears from WebKit's store list while the other account retains its cookie. No delays or cookie-copying workarounds are used.
- Public SDK declarations compile with an iOS 17 deployment target. Runtime behavior on iOS 17 and physical-device biometric/provider authentication checks remain release validation tasks.

The full passing result is `/tmp/LiteMVPFinalTests.xcresult`. After final browser/home view lifecycle corrections, both affected UI flows passed again: live website rendering and dismissal in `/tmp/LiteRenderedBrowserTests.xcresult`, and custom creation/deletion in `/tmp/LiteStableHomeTests.xcresult`. The strengthened browser test verified the actual “Example Domain” webpage heading within its 25-second limit.

Screenshots for the empty library, catalog, creation form, and populated grid are in `/tmp/LiteMVPFinalAttachments`. The final loaded-page screenshot is `/tmp/LiteRenderedBrowserAttachments/0E7C1237-817E-42EE-A4A1-8FAE5A0507CC.png`. Test artifacts under `/tmp` are temporary and are not included in the repository. The single-scene Info.plist configuration is verified separately by the final app build.

## Icon quality validation — September 19, 2026

The icon suite now covers actual decoded size selection across HTML, manifests and root fallbacks; relative URLs; HTTPS-only image candidates; script/comment exclusion; manifest purposes; candidate deduplication/request limits; rejection of small, malformed, oversized and excessively wide artwork; cancellation; and all seven bundled 512×512 catalog assets with exact host matching.

The simulator UI regression turns website artwork off and saves, refreshes and cancels, then refreshes and saves again. It verifies that Cancel preserves the symbol choice and Save persists the refreshed icon. The 11 icon tests plus this UI regression passed in `/tmp/LiteIconQualityVerified.xcresult` on iPhone 17 Pro / iOS 26.2. [Refresh preview](screenshots/icon-refresh.png).

A live smoke run of the production discovery service (without the catalog shortcut) returned a 512-pixel icon for `https://x.com`; sites without qualifying accessible artwork returned the symbol fallback. Live websites can change and are not used as deterministic icon test fixtures.

The full regression run at `/tmp/LiteIconFinalTests.xcresult` also exercised creation, deletion, duplicate catalog entries and live WebView rendering. Its existing `WebKitIsolationTests.testIndependentCookiesSurviveReopeningAndDeletingOneProfile` reported a remaining profile identifier and `WKWebSiteDataStore` “Data store is in use” during cleanup. That test and the profile-cleanup implementation were not modified by the icon work; it passed in the earlier run but failed in this full run, so the full suite is not recorded as green.


## V2 regression coverage

`LiteV2Tests` adds on-disk migration from the exact V1 model shape, preservation of cleanup receipts and profile/lock/icon data, fresh identities for duplicated accounts, strict deep-link parsing, one-shot Shortcut requests, opt-in widget metadata minimization, safe resume URLs, and a real WebKit blob download with content and cleanup assertions.

UI coverage adds account switching, creating another account from the browser, rename/search, lock enforcement from the grid/switcher/custom URL scheme, and native file import/export, popup dismissal, and JavaScript dialogs. DEBUG test fixtures require `--uitesting` plus an additional fixture argument; they only use an in-memory library and are absent from Release builds.

`testCatalogPublicLandingPages` is a live compatibility audit of all seven services. Its screenshots and accessibility attachments record the public page actually returned by the provider, including provider errors or challenges. Passing the audit only means Lite remained operable and could close each page; it is not a login certification. For a fast offline-focused regression run, skip this audit and the example.com rendering smoke test:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project lite.xcodeproj -scheme Lite \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -parallel-testing-enabled NO \
  -skip-testing:liteUITests/LiteCreationUITests/testCatalogPublicLandingPages \
  -skip-testing:liteUITests/LiteCreationUITests/testOpensAndClosesAnAppWebView test
```

The native file test saves a 21-byte fixture through the actual iOS Files exporter, then opens and cancels the native upload picker. The saved fixture is visible in Files. They do not submit a file to a third-party account. Account-specific LinkedIn behavior, successful real Face ID matching, authenticated photo uploads, and third-party OAuth still need the corresponding device/account interaction.


## V2 completed validation and device update

On September 18, 2026, **20 unit cases and 8 functional UI cases passed across the final and targeted runs**. The separate seven-service public-page audit also completed; its pass means the browser stayed operable, not that every provider rendered correctly. See [the compatibility findings](COMPATIBILITY.md).

- `/tmp/LiteV2FilesAndCatalog.xcresult`: all 20 unit tests, the seven-service audit (including LinkedIn protection off), and the file/popup/dialog UI test passed.
- `/tmp/LiteV2Validation2.xcresult`: the other seven functional UI cases passed. Its two audit/test-fixture failures were diagnosed and corrected, then passed in the final bundle above.
- `/tmp/LiteV2FocusedUI.xcresult`: the strengthened lock test also passed when a direct link arrived over an edit sheet.
- `/tmp/LiteV2SignedDeviceFinal.log`: signed Release build succeeded using **Xcode 26.0 / iOS 26.0 SDK**. Main app and widget both contain the `group.aniket.lite` entitlement and valid provisioning profiles.
- **Aniket’s iPhone 13:** installed `aniket.lite` **2.0 (2)** as an update, without uninstalling. Launch succeeded; subsequent device process inspection showed both Lite and LiteWidget running. Installation and launch receipts: `/tmp/LiteV2DeviceInstall.json` and `/tmp/LiteV2DeviceLaunch.json`.

V1 remains committed as `58b1bd4` on `main`. V2 work is on `lite-v2-current`. The device update uses the same app bundle ID and SwiftData store location; migration preservation is covered by the populated V1 fixture test. Real account logins and successful physical Face ID matching were not automated.

Final file-flow screenshots: [Files export](screenshots/v2-files-export.png), [upload picker](screenshots/v2-files-import.png). The test artifacts under `/tmp` are local and temporary.

### V2 + icon merge validation

The combined V2/icon branch built successfully with Xcode 26.3. In `/tmp/LiteMergedIconTests.xcresult`, 26 of 27 unit tests passed, including all icon and V2 tests. The same unchanged WebKit profile-cleanup test failed with “Data store is in use.” Both affected UI flows passed: editing/searching the V2 library and refreshing icons with Save/Cancel. Icon refresh resolves the edited starting website and discards stale artwork when the origin changes.

## Discover — September 19, 2026

Discover now has an independent 21-entry editorial catalog, category and keyword search, direct HTTPS input, collections, details, temporary previews, and DuckDuckGo web search. The Library creation picker and persistent model schema are unchanged.

- Eight UI cases passed in `/tmp/LiteDiscoverVerified.xcresult`: browse/filter/search, preview/cancel, invalid URLs, maximum accessibility text, opening a locked saved app, finding and adding a website, two accounts for one service, and actual live DuckDuckGo results. The complete bundle is **not green**: a synchronous preview unit test exposed the Swift isolated-deinitializer runtime crash on iOS 26.2.
- The crash matched [Swift issue 88036](https://github.com/swiftlang/swift/issues/88036). `WebPage` now has an explicit empty nonisolated deinitializer; WebKit/KVO cleanup remains in its existing main-actor `tearDown()`. All six Discover unit tests and the preview/cancel UI regression subsequently passed in `/tmp/LiteDiscoverFinalChecks.xcresult`. The six existing URL/privacy checks also passed in the earlier bundle.
- At the time of this Discover validation, `WebKitIsolationTests.testIndependentCookiesSurviveReopeningAndDeletingOneProfile` failed with the previously recorded “Data store is in use” cleanup error. Its profile-identity and cookie-isolation checks complete; deletion verification fails. This persistent-profile cleanup behavior was not changed by Discover. The subsequent container-controls validation below records the updated cleanup test and its passing result.
- The final compact row layout was verified again in `/tmp/LiteDiscoverLayoutFinal.xcresult` (passed). Screenshots: [Discover](screenshots/discover.png), [catalog search](screenshots/discover-search.png), [live web search](screenshots/discover-web-search.png).
- Signed Release build **2.0 (3)** succeeded with Xcode 26.0. App and widget retain their existing bundle identifiers and `group.aniket.lite` entitlement. Installed as an update and launched on Aniket’s iPhone 13; receipts: `/tmp/LiteDiscoverDeviceInstall.json` and `/tmp/LiteDiscoverDeviceLaunch.json`.

The deterministic preview/search UI tests use DEBUG-only HTML fixtures. The separate `DiscoverLiveUITests` case uses real internet access and is a provider-availability smoke test. None of these checks certify third-party sign-in, purchases, playback, or every website’s compatibility.

## Container controls 2.1 validation

On September 19, 2026, the signed Release build **2.1 (3)** built with Xcode 26.3. All **35 unit/integration cases** passed, including:

- Populated V1 and V2 on-disk library migration without profile identity or existing preference loss.
- Persistence/reopening of all new controls and diagnostic values.
- Real WebKit configuration and JavaScript execution behavior.
- Real cookie isolation, cache removal that retains cookies/local storage, complete cleanup, and selected-record removal that retains other websites.
- Real Fetch Cache creation/removal through the browser Cache API, and local-storage preservation/removal.
- Preference reset retaining identity, lock, resume metadata and actual cookies.
- Observed navigation diagnostics and extraction of only the failing host from a URL containing sensitive components.

Six relevant UI flows passed across final and focused runs: details access protection for locked entries; existing grid/switcher/deep-link lock enforcement; saving/reopening/resetting preferences; per-record and whole-profile data cleanup and cancellation; actual popup blocking and disabling page scripts; and live HTTPS example.com rendering. The final four UI flows ran on the smaller iPhone 16e / iOS 26.2 simulator in dark mode; the lock flows also passed on iPhone 17 Pro / iOS 26.2. Screenshots: [preferences](screenshots/container-preferences-dark.png), [website-data empty state](screenshots/container-data-dark.png). These are actual native screens captured by UI tests; test-only profiles/pages are explicitly gated and excluded from Release.

The pre-existing profile-removal test’s immediate second deletion also failed on an unchanged baseline under Xcode 26.3 with `WKWebSiteDataStore` code 1 (store in use). Its cleanup assertion now exercises the existing durable-receipt retry contract with a bounded wait for asynchronous WebKit release; non-busy errors still fail immediately and the final removal assertions are unchanged. No production retry delay was added.

Final green result: `/tmp/LiteContainerBuild/Logs/Test/Test-Lite-2026.09.19_03-48-02-+0530.xcresult`. Signed build: `/tmp/lite-container-device-final.log`. `codesign --verify --deep --strict` succeeded, and Release executable inspection found no UI-test fixture strings.

Installed as an update on **Aniket’s iPhone 13**, using the existing `aniket.lite` identifier without uninstalling. Device launch succeeded with no test arguments. Installation/launch receipts: `/tmp/LiteContainerDeviceInstall.json`, `/tmp/LiteContainerDeviceLaunch.json`. Real account sign-ins, successful physical biometric matching, and camera/microphone hardware capture are not claimed as automated validation.

### Discover integration on main

After integrating Discover with the container-controls changes on `main`, all **42 selected checks passed** (41 unit/integration tests and the Discover locked-app UI regression) in `/tmp/LiteDiscoverMainIntegration.xcresult`. This includes the updated WebKit profile-removal test. Validation used Xcode 26.0 with the iPhone 17 Pro / iOS 26.2 simulator. The existing `main` version **2.1 (3)** was retained.


## Popup protection and ad blocker (2.2)

New deterministic tests use a loopback HTTP server and actual WebKit delegates. They verify:

- Website scripts cannot automatically open a window. A user-initiated window stays pending with no network request until approved, and dismissal/session close cancel it.
- Pending `about:blank` windows cannot fetch resources injected with `document.write`.
- Approving a popup retains its original POST method/body and opener; the original page's input and scroll position survive closing it.
- Window exceptions apply only to the selected container. Pending windows cannot redirect the opener or create a window storm.
- Known ad navigation and HTTP 302 redirects leave the original page usable. A policy/content-rule cancellation never covers that page with a generic failure overlay.
- `location.replace` recovery works without a Back entry, blocks the repeated redirect even with changed query tokens, and permits unrelated navigation afterward.
- WebKit compiles the bundled 53,524-domain rule set. Host-boundary tests reject misleading substrings and preserve known authentication/payment hosts. Cosmetic rules hide ad containers, retain normal dialogs, and can be disabled.
- New per-origin window exceptions persist; preference reset revokes them. Existing store migration and cookie-isolation tests remain required.

Native UI tests exercise Open/Dismiss, explicit close-and-return, nested written windows, known ad blocking, maximum accessibility text, existing popup/file/dialog controls, and Discover preview/search/add flows. Written `about:blank` windows can return an unusable XCTest accessibility hit point; the nested-window test sends an actual touch at the link's measured frame and requires a resulting popup request and successful return. This does not replace the interaction assertion with a state-only check.

The signed Release build excludes fixture HTML and retains the existing app/widget identifiers and app group. `script/run_on_iphone.sh` builds, verifies signing, installs as an update, and launches without test arguments. Physical account sign-ins and all third-party video/ad variants still require website-specific testing.

### Completed 2.2 validation and device update

On September 19, 2026, **50 unit/integration checks and 9 relevant UI checks passed across the final and focused runs**, using Xcode 26.3 and the iPhone 16e / iOS 26.2 simulator:

- `/tmp/LitePopupFinalUI.xcresult`: all 50 unit/integration checks and five UI checks passed (popup approval/dismissal, nested windows, ads/redirects, accessible popup controls, and Discover at maximum text size).
- `/tmp/LitePopupRecoveryFinal.xcresult`: all eight browser integration checks passed after strengthening recovery to retain the current SPA route, including a query-bearing route set by `history.replaceState`.
- `/tmp/LitePopupVerified.xcresult`: the other four relevant UI checks passed (Discover preview/cancel, search/add, advanced preferences, and native upload/download/popup/dialog controls). That intermediate bundle had a Discover maximum-text-size failure; the native keyboard-dismiss action and final passing check above resolve it. It is not an entirely green bundle.

Screenshot inspection led to a vertical action arrangement at accessibility text sizes. Native buttons retain readable labels and touch targets. The browser mounts only the active web view while its session retains opener instances. Screenshots: [popup approval](screenshots/popup-approval.png), [close and return](screenshots/popup-return.png), [maximum text size](screenshots/popup-accessibility.png).

Signed Release **2.2 (4)** built successfully; `codesign --verify --deep --strict` passed. Bundled list bytes matched the pinned source, credits/license were present, and the Release executable excluded fixture HTML. Installed **as an update** on **Aniket’s iPhone 13 (iOS 26.5.2)** without uninstalling or clearing data. Launch with no test arguments succeeded, and a subsequent process query confirmed Lite still running. Device app enumeration confirmed version 2.2, build 4. Receipts: `/tmp/LitePopupDeviceInstall.json`, `/tmp/LitePopupDeviceLaunch.json`, `/tmp/LitePopupDeviceProcesses.json`; signed build log: `/tmp/lite-popup-device-build.log`.

## Settings redesign — build 2.2 (6)

Implemented Appearance, searchable App Settings, configuration-based privacy
summaries, separate widget selection with a preview, grouped library organization,
and practical Help. Browsing and privacy controls no longer duplicate each other.
The existing authentication gate protects both new app-settings entry points.

Signed Release build succeeded with Xcode 26.0 and installed in place on Aniket’s
iPhone 13 on September 19, 2026. `devicectl` confirmed installation and launch;
receipts are `/tmp/LiteSettingsDeviceInstall.json` and
`/tmp/LiteSettingsDeviceLaunch.json`. Bundle identifiers and website profiles were
preserved. Screenshots: `screenshots/settings.png` and
`screenshots/widget-settings.png`.

Sixteen distinct checks passed across the runs: eight ContainerControls tests,
two persistence tests, the existing locked-details UI regression, and all five
new Settings UI tests (appearance persistence, searchable locked-app access,
privacy summaries and control grouping, widget/favorite independence, and empty
states/large-text Help). Final search and accessibility adjustments were checked
in focused reruns. Logs remain in `/tmp/lite-settings-*.log`; the initial combined
result is `/tmp/LiteSettingsChecked.xcresult`.

The existing `testContainerPreferencesDataResetAndDiagnostics` did not complete
successfully: it timed out during cold blocker preparation and website-data
loading; the last retry was interrupted when the Mac ran out of disk space.
This regression remains unverified. The related model/configuration, data-isolation,
cache-cleanup, and preference-reset unit/integration tests passed.

Testing also exposed the Swift synthesized isolated-deinitializer crash on older
iOS runtimes. An explicit empty BiometricService deinitializer avoids that path;
authentication cleanup remains in the existing cancel/authenticate methods.
Reference: https://github.com/swiftlang/swift/issues/88036. The ten selected
unit/integration checks and UI navigation then ran without that crash.

## Saved bookmarks and downloads — September 20, 2026

The signed Debug simulator build succeeds with Xcode 26.3 and the iOS 17
deployment target. All 27 selected unit/integration checks passed: 11 Saved
storage cases, seven Lite V2 cases, eight container-controls cases, and WebKit
profile isolation. Evidence is retained in `/tmp/lite-saved-final-tests.log`
and `/tmp/LiteSavedFinalTests-summary.json`. Bulky intermediate result bundles
were removed when the Mac ran out of disk space.
The final build, including the accessibility layout adjustment, passed for both
simulator architectures; log: `/tmp/lite-saved-delivery-build.log`.

Storage checks cover restart persistence, per-profile separation and deletion,
duplicate bookmarks, interrupted downloads, filename/path validation, symlink
rejection, protected files, and preserving unreadable metadata. The actual
WebKit blob-download check verifies that closing its session retains the file.
The enhanced isolation check in `/tmp/lite-saved-verified-tests.log` also
reopens a bookmark URL using its original cookies and verifies that pending
container deletion removes only that profile's bookmarks.

The Saved UI fixture uses three synthetic containers, including an empty locked
container, and a separate `LiteSavedUITests` storage directory. It is gated by
Debug launch arguments. UI checks cover hidden locked titles/counts during
global search, authentication before mounting private content, bookmark and
download persistence across app restart, native Quick Look and Files export,
preserving edited browser input through Saved, switching into another locked
container, and the largest accessibility text size. Run these on a dedicated
simulator: simultaneous tasks installing the same app/test-runner identifiers
on one device can terminate each other's tests.

Five Saved UI flows passed on iPhone 17 Pro / iOS 26.2 during development:
global search privacy, denied authentication, bookmark persistence, reachable
controls at maximum text size, and switching from a global bookmark into a
locked container. The strengthened bookmark test also passed on iPhone 16e,
verifying that edited page input survives opening Saved.

Follow-up checks exposed a tall-row action button below the visible area on
iPhone 16e and a Quick Look test race: the native close button appears during
the opening animation before the filename toolbar is ready. Download actions
now align to the top at accessibility sizes, and tests wait for the loaded
filename toolbar and actual dismissal. Manual iPhone 16e checks confirmed
previewing the file, returning to an interactive Saved list, and saving a copy
to Files while retaining the original. Authentication-unavailable content
remained hidden after backgrounding and returning; simulated enrollment was
restored afterward.

The final UI rerun is **not green**. Disk exhaustion (`mkstemp: No space left
on device`) prevented Xcode from finalizing its report. The preview timing and
small-screen layout adjustments still need a clean automated rerun; the native
upload/download regression also timed out at cold WebKit startup. The console
log is `/tmp/lite-saved-final-verification.log`. Successful biometric matching
and relocking from an authenticated preview were not completed because the
simulator's matching action was unavailable through automation.

Physical biometric hardware, iOS 17 runtime behavior, and authenticated
third-party downloads still require device release checks. Verify background
relocking while a protected preview/share/export is open, and confirm exported
copies remain accessible outside Lite after its container is locked or deleted.

The signed Release build was subsequently installed as an update on Aniket’s
iPhone 13 and launched successfully with no test arguments. Signing verification
passed. Receipts: `/tmp/LiteSavedDeviceInstall.json` and
`/tmp/LiteSavedDeviceLaunch.json`; build log: `/tmp/lite-saved-device-build.log`.
This installation does not replace the outstanding functional release checks above.

## Website preview redesign — September 22, 2026

The Discover preview now has a compact domain header, a grouped navigation
capsule, an Add to Lite action, and a native website-information sheet. The
information sheet preserves the active webpage and dismisses before handing
its selected website to the existing creation flow. Toolbar symbols retain
44-point touch targets; large text stacks actions and expands the sheet.

Seven Discover unit checks and four preview UI flows passed on iPhone 17 Pro
with iOS 26.2. The information/creation and maximum-accessibility-text flows
also passed on iPhone 16e with iOS 26.0. These exercise disabled Add on search
results, cancellation without creation, search-to-add, page-state preservation,
fixed website controls above the toolbar, and returning to the start page.
The final visual pass uses an explicit Lite appearance override for light and
dark screenshots. Cold blocker compilation gets a bounded 60-second test wait;
production protection and session behavior are unchanged.

The Journal page in the screenshots is a DEBUG-only local fixture, including
a fixed footer and an in-page state change. It is not injected into real sites.
The simulator build uses Xcode 26.3 and retains the iOS 17 deployment target.
The signed Release build was installed as an update and launched on Aniket’s
iPhone 13. Third-party sign-in verification is not included.

Validation logs: `/tmp/lite-preview-final-tests.log` (7 unit + 4 UI checks)
and `/tmp/lite-preview-verified.log` (final 2 UI checks on iPhone 16e).
Final screenshots: [preview](screenshots/discover-preview-light.png),
[website information](screenshots/discover-preview-information-light.png),
[large-text preview](screenshots/discover-preview-accessibility-dark.png), and
[large-text information](screenshots/discover-preview-information-accessibility-dark.png).

The preview controls now use native iOS 26 Liquid Glass: circular close/reload
controls, a glass navigation capsule, and glass-prominent Add to Lite actions.
The information sheet uses the system presentation background. Older systems
and Reduce Transparency retain filled controls. The surrounding chrome stays
solid on iOS 26 to keep the control surfaces visually distinct.

Both focused preview UI flows passed after the glass update on iPhone 17 Pro
(iOS 26.2); log: `/tmp/lite-preview-glass-verified.log`. The test launch disables
the decorative atmospheric background to avoid simulator idle stalls. Updated
screenshots above reflect Liquid Glass. Release signing, installation, and launch
on Aniket’s iPhone 13 also succeeded.

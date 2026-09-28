# Lite Pro setup

Configured September 22, 2026 for version 2.3 (16).

## Access policy

Free Lite permits 3 user-added profiles (including separate accounts for the same website), the six included starter apps for new installations, and 1 user-created group. Starter duplicates consume an added-profile slot. Pro permits unlimited creation and additional symbols and badge colors. Core privacy, biometric locks, basic bookmarks/downloads, widgets, and existing manually configured proxies remain free. There is no managed VPN or Lite Connect service.

Expiry only prevents new actions beyond the free limits. Existing profiles, groups, files, locks, and saved premium appearance remain usable and editable. Purchase state never deletes library data. Creation is checked at persistence time, including duplication and additional account flows.

## Store configuration

| Item | Value |
| --- | --- |
| Bundle ID | `aniket.lite` |
| App Store Connect app | `6814814280` |
| Subscription group | `22404532` (Lite Pro) |
| RevenueCat project | `4fb07ddd` (Lite) |
| RevenueCat Apple app | `appfe4aa00af8` |
| Entitlement | `pro` |
| Current offering | `default` (`ofrng8b95d982e7`) |

| Product | Type | US base price | Apple ID |
| --- | --- | --- | --- |
| `aniket.lite.pro.weekly` | Auto-renewing, 1 week | $0.99/week | `6814818866` |
| `aniket.lite.pro.monthly` | Auto-renewing, 1 month | $2.99/month | `6814815030` |
| `aniket.lite.pro.lifetime` | Non-consumable | $39.99 once | `6814820331` |

Both subscriptions have service level 1. All three products grant the same `pro` entitlement and are mapped in the current offering. Monthly is selected and recommended on the paywall; lifetime and weekly remain visible. No introductory trial is configured. Apple generates regional prices; the app displays actual localized StoreKit prices rather than hardcoded dollar amounts.

RevenueCat SDK 5.90.2 is pinned in Swift Package Manager. The public app-scoped SDK key is embedded in `ProStore.swift`; no private Apple or RevenueCat key belongs in source control. Existing Apple credentials are connected in RevenueCat. Apple production and sandbox server notification URLs both point to RevenueCat; its dashboard confirms the configuration is correct.

## Purchase behavior

`ProStore` loads the current offering, purchases packages, restores purchases, listens for customer-info changes, and refreshes on foreground entry. Cached access is bounded by the entitlement expiration date, including a billing grace period reported by Apple/RevenueCat. A lifetime entitlement has no expiration. Failed entitlement verification is rejected.

Cancellation does not end a paid period early. Purchase errors or pending approvals do not unlock Pro without an active entitlement. Restore and Apple's subscription management sheet are available. Debug UI tests disable purchases unless `--uitesting-live-purchases` is also supplied; release builds always use the real SDK.

## Public pages and privacy

- Support: https://aniket-pd.github.io/lite-app-support/#support
- Privacy: https://aniket-pd.github.io/lite-app-support/#privacy
- Standard Apple EULA: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- Support page source: https://github.com/Aniket-pd/lite-app-support

Only the support website was published to GitHub. Purchase history is disclosed for App Functionality and Analytics, not linked to identity and not used for tracking. RevenueCat uses its anonymous app user ID; automatic device identifier collection is disabled. Browsing history, website sign-ins, bookmarks, and downloads are not sent to RevenueCat. Keep the privacy manifest, in-app explanation, public policy, and App Store disclosure synchronized when adding SDK features.

## Validation completed

- 97 unit tests passed, including free limits, creation enforcement, expiry, cancellation-period access, lifetime access, and preservation of premium appearance.
- 2 Pro UI tests passed: fourth-profile paywall and preservation/editing of an existing over-limit library.
- 1 live StoreKit catalog UI test passed: all three actual Apple products loaded with US prices; monthly selection and lifetime purchase label verified.
- Store capture checks passed on iPhone 17 Pro Max and iPad Pro 13-inch, including the live Apple catalog in both layouts. iPad's floating tab bar exposes duplicate accessibility elements; the capture test uses the first matching tab button.
- Signed generic iOS archive succeeded. A permanent copy is saved in `~/Library/Developer/Xcode/Archives/2026-09-22/Lite Pro 2.3 16.xcarchive`.
- Paywall captures: `output/lite-pro/paywall-monthly.png` and `paywall-lifetime.png`.

Catalog loading is not a completed sandbox transaction. Before release, verify purchase, cancel, pending approval, renewal, expiry, refund/revocation, reinstall/restore, and an offline relaunch using an Apple sandbox tester or TestFlight. Confirm RevenueCat customer events and entitlement changes for those transactions. Do not use a production purchase for this check.

## Release status

The app and products are drafts, not publicly released. App metadata uses manual release. TestFlight upload was attempted but Xcode reported no App Store Connect account access for team `6J37W2X7S6`; sign in to the developer Apple Account in Xcode Settings > Accounts, then retry. The archive itself compiled and signed successfully. An updated Apple Developer agreement banner was also present in the web account; the Account Holder must review any outstanding agreements before submission.

All three products have review instructions and actual paywall screenshots. The App Store privacy label is published. The app is configured as a free download in all 175 storefronts, with Productivity and Utilities categories and the subtitle “Separate accounts. One place.” Apple's questionnaire calculates a 16+ rating because the app allows unrestricted web browsing; Lite supplies no mature editorial content of its own. App Review contact details are stored only in App Store Connect.

Three actual iPhone 6.9-inch screenshots are uploaded in Media Manager and inherited by the 6.5-inch listing. Two iPad 13-inch screenshots are uploaded and apply to other supported iPad sizes. Source captures live in `output/lite-pro/store/iphone` and `output/lite-pro/store/ipad`. `StoreScreenshotTests` is an explicit capture workflow; use `LiveProStoreUITests` for the live catalog check and `ProUITests` for free-limit UI behavior.

After Xcode account access is repaired, retry upload using the archived version and the generated `/tmp/LiteProExportOptions.plist`:

```sh
xcodebuild -exportArchive \
  -archivePath "$HOME/Library/Developer/Xcode/Archives/2026-09-22/Lite Pro 2.3 16.xcarchive" \
  -exportPath /tmp/LiteProExport \
  -exportOptionsPlist /tmp/LiteProExportOptions.plist \
  -allowProvisioningUpdates
```

The export options use `method=app-store-connect`, `destination=upload`, automatic signing, team `6J37W2X7S6`, symbol upload, and no automatic version/build-number changes. Alternatively, open the archive in Xcode Organizer and choose Distribute App > App Store Connect. Uploading is separate from submitting the draft for App Review or releasing it.

The Account Holder still needs to confirm Content Rights for the website content and branding. Do not assert ownership or third-party permissions without that confirmation. The account's existing non-trader declaration was not changed; verify that it still reflects the developer's circumstances before release.

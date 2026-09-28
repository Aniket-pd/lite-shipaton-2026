# Lite 2.1

A native iOS home for lightweight web apps. Built with SwiftUI, WebKit, SwiftData, and LocalAuthentication. RevenueCat manages optional Lite Pro purchases.

## Run

Open `lite.xcodeproj`, select the **Lite** scheme, and run on an iPhone simulator or a device with **iOS 17 or later**. For a physical device, sign into the development team under Xcode Settings → Apple Accounts. Both the app and widget need the `group.aniket.lite` App Group enabled in their provisioning profiles. The existing bundle identifier stays `aniket.lite`, so updating preserves the library.

V2 builds with Xcode 26.0 / iOS 26.0 SDK and runs on the installed iOS 26.2 simulator. The iOS 17 deployment target remains. Xcode 26.3 is also installed; no newer SDK validation is claimed.

```sh
xcodebuild -project lite.xcodeproj -scheme Lite \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/LiteDerivedData CODE_SIGNING_ALLOWED=NO build
```

## Included

- A five-page first-launch introduction with a continuous phone preview, synchronized page/zoom/blur transitions, accessible navigation, and a ready-to-use library of six starter apps. It explains browsing any site in Discover and tapping Add to Lite, separate profiles, Face ID, and ad/tracker blocking. Returning installations bypass it. See [onboarding behavior and implementation](docs/ONBOARDING.md).
- An adaptive icon grid, search, pinned favorites, manual ordering, light/dark appearance, and native creation and editing sheets.
- A Groups tab with translucent cards and horizontal app carousels. Front-facing icons scale and dim around the focused app, whose name and selector fade into view. Light selection haptics accompany scrolling, and apps snap to the center; tap any visible app to launch it. Each group remembers its position during the session. Tap a group title for the complete list, or use its menu to edit membership or delete the group. Each app keeps its own profile and website data. Larger accessibility text uses full-width rows; reduced motion and transparency preferences are respected.
- A search-first Discover tab with 21 editorial app entries, category filters, featured collections, website details and previews, and account-aware Open/Add actions. Names and task keywords search the catalog locally; pasted HTTPS addresses go directly to website details.
- Search the web from Discover using DuckDuckGo in an in-app browser. Open a result and choose Add to Lite to create a Lite App. Internet results are provider webpages, not a native app index; no paid search API or API key is required.
- Discover previews use a compact domain header with Close and Reload, a grouped Back/Forward/More toolbar, and an **Add to Lite** action. Tap the domain or **Temporary session** to see website information and the sign-in explanation. Adding from that sheet continues into the existing profile-creation flow. Start Page and redirect recovery are in More; larger text stacks the actions and expands the information sheet.
- Instagram, Reddit, X, LinkedIn, Gmail, Amazon, and YouTube catalog entries, plus custom HTTPS websites.
- Editable names and starting URLs, bundled catalog artwork, high-resolution website icons, SF Symbol alternatives, icon colors, and local persistence; existing profile IDs stay unchanged.
- Start-page or last-suitable-page launches, an in-browser account switcher, and Create Another Account with a fresh profile.
- An Open Lite App Shortcuts action and a Home Screen widget for apps explicitly selected in Widgets & Shortcuts. Both use the same biometric gate.
- A Saved tab with page bookmarks and persistent container downloads, search, container filtering, previews, sharing, and export to Files; native website file/photo selection.
- A unique persistent WebKit profile for every Lite App, including multiple copies of the same service.
- Container Details from each library tile’s long-press menu, protected by the same biometric gate as browsing.
- Saved per-container mobile/desktop/automatic layout, 75–200% page zoom, autoplay, camera/microphone Ask/Block policies, and advanced JavaScript/popup controls.
- Actual WebKit website-data records and categories, cache-only cleanup, individual website-data removal, complete session cleanup, and preference reset with confirmations.
- Last-opened time and observed navigation diagnostics (host, connection state, HTTP status, duration and error codes), with a redacted local-only clipboard summary.
- A minimal WebView with back gestures, back/forward, loading progress, reload, start page, sharing, popup windows, native website dialogs, and actionable errors.
- Page-colored status/home safe areas and a centered floating toolbar with separate Close and More buttons. Back and Reload flank the domain inside the main capsule. On iOS 26, Liquid Glass floats over webpage content while WebKit keeps fixed website controls above it; earlier releases use a frosted, reserved-area fallback. Scrolling down shrinks and lowers the domain pill as the side buttons recede; tap it or scroll up to expand. Website clearance contracts and expands with the toolbar, moving fixed website tabs down in reading mode and back up above the expanded controls. Start Page, sharing, and account switching live in More.
- Bundled ad/tracker blocking for over 53,000 domains, cosmetic ad hiding, and a per-container switch.
- Popup approval before switching pages, explicit close-and-return controls, and recovery from replacement redirects.
- Optional biometric lock, authentication before WebView creation, background relocking, and a privacy cover while inactive.
- Removal of the selected app’s website data, with durable cleanup receipts for interrupted deletion.

## Session isolation

`LiteApp.dataStoreIdentifier` is created once and saved with the model. `WebSession` supplies `WKWebsiteDataStore(forIdentifier:)` to the configuration **before** creating a WebView. Popup windows keep the same profile as their opener. Different Lite Apps never use a shared/default cookie store. Renaming or changing protection does not replace the profile ID.

The browser is destroyed when dismissed, while WebKit persists its profile data. Persistent cookies remain subject to website expiry and logout policies; websites can also choose session-only cookies. Lite does not export, copy, or synchronize cookies.

Lite uses one app scene, keeping library deletion and active browser ownership in the same window.

## Privacy and locking

The app contains no analytics, advertising, or cloud-sync SDK. Seven reviewed catalog icons are bundled; other Discover services show a built-in symbol immediately and may load validated artwork through the same custom icon discovery used when creating an app. Discovery reads public metadata at the website origin, a same-origin web app manifest, and HTTPS image URLs declared by that metadata (which may use the website’s CDN). Requests use independent ephemeral, cookie-free sessions with no credential storage, cache, or referrer, bounded downloads, origin-preserving redirects (including canonical `www` variants), and image downsampling; no favicon aggregator is used. Website traffic still goes to the websites and their resources; Lite bundles HaGeZi PRO mini domain rules and conservative cosmetic rules. Same-site ads and some tracking can remain; blocking can be disabled per container.

Discover filters saved apps and the editorial catalog on device. A query is sent to DuckDuckGo only when Search is submitted or Search the web is tapped. Website previews and web search use a temporary, nonpersistent WebKit store with the content blocker, never a saved app's account. Preview sign-ins are not transferred when adding an app. Adding from a visited webpage selects the known catalog start URL or the website origin, excluding private paths, query tokens, and fragments; an explicitly pasted URL is preserved by the existing creation flow. Catalog inclusion is not a certification of embedded sign-in, playback, or other website features.

Face ID/Touch ID uses `deviceOwnerAuthenticationWithBiometrics`, without a passcode bypass. Enabling or removing a lock requires authentication. If biometrics become unavailable, the app stays locked. Configure/unlock biometrics through device Settings and retry. Deleting a locked app removes its website session; creating another copy creates a fresh profile.

Saved content follows the container's lock. Global Bookmarks and Downloads lists and search exclude protected items, including names and counts; each locked container has the same generic unlock row even when empty. Unlocking opens only that container's saved content. Its browser and Saved screen share access within that flow; returning to the global list ends access. Backgrounding revokes access, and a window-level privacy cover obscures native previews and presentations while inactive. Exported/shared copies are outside Lite's container lock.

Bookmarks and download metadata are stored in private `Application Support/LiteSaved/<profile UUID>/` manifests. Completed files stay under that profile with iOS complete file protection until deleted. This is separate from the existing SwiftData library and does not replace account or WebKit identities. Bookmarks reopen in their original container; Favorites continue to identify whole Lite Apps. Deleting a container queues deletion of its saved files along with its website data. Clearing website cache/data does not delete bookmarks or downloaded files.

## Scope and compatibility

- Custom apps require HTTPS. App Transport Security and normal TLS validation remain enabled.
- Websites control embedded-browser compatibility. Some providers, including Google OAuth flows, may reject embedded sign-in. Lite does not spoof a browser or transfer Safari cookies to bypass that policy.
- User-activated web links stay in Lite where public WebKit APIs permit. Email, phone, messages, and maps links require explicit confirmation before opening another app. Some OS-controlled universal-link behavior remains platform-dependent.
- Downloads use the active profile’s `WKDownload`, with one active transfer per browser. Closing or locking that browser cancels an unfinished download; completed files remain in Saved. Files export saves a copy without removing the original. Interrupted downloads show a failed state after relaunch. There is no background download manager.
- Continue Last Page stores successful same-site GET pages, excluding authentication paths, queries, and fragments. If a suitable page is unavailable, the start page opens. It does not replay forms.
- Saved websites remain inside Lite. Widgets and Shortcuts provide direct access; push notifications, subscriptions, cloud session sync, and website script extensions are deferred.

## Structure

| Directory | Responsibility |
| --- | --- |
| `lite/Models` | SwiftData models and the service catalog |
| `lite/Views` | Native screens, sheets, grid, and the authentication gate |
| `lite/ViewModels` | Creation state and save workflow |
| `lite/Services` | Biometric authentication, favicon fetching, profile cleanup |
| `lite/WebKit` | WebView lifecycle, navigation policy, windows, dialogs, content rules |
| `lite/Utilities` | Website and resume URL validation |
| `LiteWidget` | WidgetKit extension; names/icons/app IDs only |
| `liteTests`, `liteUITests` | Persistence, isolation, privacy, validation, and UI tests |

See [WebKit API verification](docs/WEBKIT.md), [testing and device validation](docs/TESTING.md), and [observed website compatibility limits](docs/COMPATIBILITY.md). The icon assets can be regenerated with `swift Tools/GenerateAppIcon.swift`.

Future UI reference: [iOS 26 onboarding style](docs/ONBOARDING_STYLE_REFERENCE.md) documents the Kavsoft tutorial’s composition, SwiftUI view structure, synchronized transitions, customization points, and a proposed iOS 17-compatible integration path for Lite.

Simulator screenshots: [My Lite Apps](docs/screenshots/my-lite-apps.png), [catalog](docs/screenshots/catalog.png), [creation](docs/screenshots/create-lite-app.png), and [loaded website](docs/screenshots/browser.png).

## Icon quality

- All seven catalog services include reviewed 512×512 publisher artwork, with provenance in [CATALOG_ICON_SOURCES.json](docs/CATALOG_ICON_SOURCES.json). Existing catalog apps using website icons immediately display the bundled version. Explicit symbol choices remain symbols.
- Custom websites are checked for HTML `icon` / `apple-touch-icon` links, web app manifest icons, and conventional root icon files. Only HTTPS images are fetched. Source intent and declared sizes prioritize up to eight metadata candidates, while three conventional root files retain reserved fallback attempts; decoded dimensions and visual quality determine the best usable image.
- Images must measure at least 128 pixels on both sides, with 192 pixels preferred, and have an aspect ratio no wider than 2:1. Tiny, blank, transparent, and solid-color images are rejected and artwork is never upscaled. Accepted artwork is normalized onto a square transparent canvas, decoded to PNG, and capped at 512 pixels; unsupported formats (including SVG) fall back to another candidate or a visible symbol/initial.
- Discovery uses the public origin root, omitting the saved URL’s path, query, and fragment. It has an 18-second overall deadline, 1 MiB per HTML/image download, 256 KiB per manifest, and at most three origin-preserving HTTPS redirects per request; redirects may add or remove the canonical `www` prefix.
- To update a saved custom app, long-press its tile → **Edit → Refresh icon → Save**. Refresh previews are discarded on Cancel; a failed refresh keeps an existing sharp icon. If only low-quality art exists, Lite uses the app’s symbol. No website profiles or sign-ins are changed.


V2 **2.0 (2)** was built with Xcode 26.0, installed as an update, and launched on Aniket’s iPhone. Twenty unit tests and eight functional UI cases passed across validation runs. Public-site testing identified DNS failures for required LinkedIn/Reddit asset hosts in the development network; LinkedIn remains unstyled there even with Lite protection disabled. No network or TLS settings were changed.

## Container controls (2.1)

Touch and hold a saved app → **App Settings**. The screen exposes **Browsing**, **Privacy & permissions**, **Website data**, and **Diagnostics**. Editing, biometric protection, and creating another account remain available. Locked containers authenticate before any website-data query; backgrounding relocks and covers the details screen too.

Preferences save immediately and take effect the next time the container opens. WebKit receives the selected layout, JavaScript, media-playback, and popup preferences before page creation, including child windows; page zoom applies to each web view. Camera and microphone **Ask** delegates origin-specific consent to WebKit/iOS, while **Block** denies matching requests. A combined camera/microphone request is denied if either permission is blocked. iOS app-level permissions still apply. No automatic permission grants or custom browser user-agent spoofing are used.

**Clear Cache** removes disk/memory/offline/fetch caches while keeping cookies and website storage. **Clear All Website Data** clears this profile’s WebKit data and forgets the saved resume page and diagnostics; the container’s identity, name, settings and lock remain. **Reset Container Preferences** resets browsing/protection/permission choices, keeping identity, the lock and all website data. Per-website removal uses the actual selected WebKit record. Deep-link opens wait for ongoing cleanup of that profile before creating a new web view.

Diagnostics are observations from completed navigations, not inferred from the starting URL or a continuous security check. Older entries show **Not recorded yet** until a new event is observed. Only hosts, timestamps and technical values are retained; no error userInfo, authentication URL paths, query strings or cookie values are persisted. Copied summaries exclude container names and page addresses, stay off Universal Clipboard, and expire after five minutes. WebKit does not provide record byte sizes through the public record API, so the UI shows data types and record counts instead of estimated megabytes.


## Popup protection and ad blocking (2.2)

New website windows keep the current page visible until **Open** is chosen. **Dismiss** cancels the pending request. Approved windows display **Close popup and return**, and **Start Page** remains available outside website content. **Always allow windows from this website** is an explicit, per-origin exception scoped to the container; remove exceptions in **Browsing → Advanced**. Automatic JavaScript windows remain disabled, and ad-domain blocking still applies to allowed windows.

The original web view is retained under a popup, preserving its live page state. For same-window redirects, **Return to previous page** uses a retained history entry or a GET reload when `location.replace` removed that entry. Recovery also blocks the same redirect destination from immediately taking over again. Reload recovery cannot preserve unsaved form content, and approved websites can still update their opener. Login/payment provider compatibility remains subject to the provider’s embedded-browser rules.

The blocker ships the pinned **HaGeZi Multi PRO mini** list (53,522 upstream domains, plus Lite’s original domain coverage), matches document/subresource requests and native popup/redirect destinations, and hides recognizable ad containers. It performs no browsing-time list downloads. Rules are compiled locally and cached with a content-derived identifier. Missing/invalid rules fail preparation rather than silently disabling enabled protection. Update the snapshot with `python3 Tools/update_content_blocker.py <upstream-commit-sha>` and rerun the WebKit privacy tests. Source, revision, checksum and the original GPL-3.0 list license are bundled in `lite/Resources`; credits/license are accessible in About Lite. This is domain/cosmetic blocking, not a promise to remove every first-party or video ad.

Discover previews also ask before navigating to a requested new-window link and provide native return/start controls. Previews remain ephemeral and do not support saved-account popup authentication flows.

To build and update Aniket’s paired iPhone without uninstalling Lite: `./script/run_on_iphone.sh`. Pass another paired device UDID as its first argument when needed.

Validation: 50 unit/integration and 9 relevant UI checks passed across final/focused runs. Release **2.2 (4)** was installed in place and launched on Aniket’s iPhone 13. See [validation details](docs/TESTING.md#completed-22-validation-and-device-update).


## Settings redesign (build 6)

Settings now groups Appearance, Organize Library, Widgets & Shortcuts, App Settings,
Privacy & Permissions, Help & Troubleshooting, and About Lite. System/Light/Dark
appearance is saved on this device. App Settings provides search and reuses the
biometric gate before showing a locked app’s settings or querying website data.
Privacy summaries show saved blocking and lock configuration, with routes to each
app’s controls. Browsing and Privacy & Permissions have distinct settings, and
changes are labelled as taking effect the next time the Lite App opens.

Organize Library separates Favorites and Other Apps so reordering matches the
library. Widget selection now has its own screen with a medium-widget preview and
setup instructions; selection remains independent of favorites. The widget’s
visible name is Lite Shortcuts, while its existing identifier is preserved.

## Optional encrypted proxy per container

Touch and hold a saved app → **App Settings → Encrypted proxy**. Enable it, enter an HTTPS CONNECT server hostname and port (443 by default), add credentials if required, and save. Lite does not supply proxy servers or a country-selection subscription. TLS to the proxy and normal website certificate validation remain enabled; HTTP-only and SOCKS servers are not supported by this setting.

Each container has an independent route. Root pages, popup windows and WebKit downloads share that container’s configured data store. Explicit icon refreshes use the same proxy in their separate cookie-free URLSession. Direct failover is disabled. Invalid configuration or unavailable credentials block browsing instead of opening the saved profile directly. “Configured” means settings are saved, not that connectivity or an exit IP has been verified.

If the container has already opened in this process, **quit Lite from the app switcher and reopen it after changing its proxy settings**, including turning the proxy off. Lite blocks reopening under a changed route until then, because previously established connections may survive an in-process configuration change. Cookies and profile identity are preserved.

Passwords are stored in device-only Keychain entries, never SwiftData or widget metadata, and are removed with profile deletion. An authenticated duplicate keeps the proxy enabled but requires its own password before browsing. Resetting browsing preferences and clearing website data preserve proxy settings; turn it off explicitly in Encrypted Proxy.

This is a web proxy, not a device VPN. WebKit may bypass the proxy for localhost destinations. WebRTC/UDP and DNS coverage are not guaranteed. Discover, creation-time icon discovery before a container exists, and links opened in other apps are outside this route. iOS 17+ is supported by the API; the implementation uses only public WebKit, Network and Security APIs.

## Lite Pro

The free tier includes 3 user-added profiles, six included starter apps for new installations, and 1 user-created group. Duplicating a starter app counts as an added profile. Lite Pro unlocks unlimited profile/group creation and additional profile symbols and colors. Expiry never deletes or blocks access to existing profiles, groups, files, or saved customization. Core privacy tools remain free.

RevenueCat project: `4fb07ddd`; App Store app: `6814814280`; entitlement: `pro`; current offering: `default`. Products: `aniket.lite.pro.weekly`, `aniket.lite.pro.monthly`, and non-consumable `aniket.lite.pro.lifetime`. US base prices are $0.99/week, $2.99/month, and $39.99 once; the app always displays localized StoreKit prices. The app-scoped public SDK key is safe to ship; private Apple keys stay in RevenueCat.

Purchase history is processed for app functionality and purchase analytics; RevenueCat uses an anonymous app user ID. Automatic device identifier collection is disabled. No browsing history, cookies, bookmarks, or downloaded files are sent to RevenueCat. See `docs/LITE_PRO_SETUP.md` for release checks and store configuration.

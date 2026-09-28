# V2 website compatibility observations

Checked on September 18, 2026 with Xcode 26.0, the iOS 26.0 SDK, and an iOS 26.2 iPhone simulator. These are fresh, unauthenticated profiles. They do not certify provider sign-in or the user's authenticated iPhone session.

| Service | Observed public-page result |
| --- | --- |
| LinkedIn | Public HTML loads without styling; sign-in navigation reaches another unstyled page. See the DNS diagnosis below. |
| Instagram | Public mobile landing content loads. No credentials submitted. |
| Reddit | Public feed content loads, with missing styling/resources. Its asset hostname fails DNS resolution on the host network. |
| X | A load failure and an unsupported app-link notice were observed. Not certified compatible. |
| Gmail | Google sign-in page and email/phone field render. No sign-in performed. |
| Amazon | Public page loads with missing styling/images; not certified for account or purchase flows. |
| YouTube | Mobile landing page renders its search/feed prompt; playback and sign-in not exercised. |

## LinkedIn resource failure

The downloaded public LinkedIn HTML references a stylesheet on `static.licdn.com`. Fetching that resource directly outside Lite failed with `nodename nor servname provided, or not known`. Independent system resolver calls confirmed:

- `www.linkedin.com`: resolves.
- `static.licdn.com`: resolution fails.
- `www.redditstatic.com`: resolution fails.

This explains the observed missing LinkedIn CSS/scripts in this development environment. The failure also occurs without Lite's content blocker; the explicit protection-off rerun remained unstyled. Lite's rules do not list either asset host. No DNS, VPN, content-filter, TLS, or device security settings were changed. Retest on a network that resolves the required asset hosts, and compare the exact failing iPhone page with Safari there before assigning the phone's issue to the same cause.

The V2 navigation change preserves WebKit's original web requests, including referrer and user activation. It fixes a concrete weakness in V1's cross-domain GET reissuance but is not presented as a proven fix for the reported LinkedIn page.

Screenshots and page accessibility captures are in the local compatibility test result attachments. No user credentials were entered and no messages or files were submitted to these services.

# iOS2: running two Hamme iOS apps side by side

Guide for shipping the `ios2` branch as a **second App Store listing** while the
old iOS app stays live. Android is **not** affected: it keeps `com.hamme.app` on
Google Play, the `hamme` URL scheme, and its existing Firebase / Play billing
setup.

| | Old iOS app | New iOS app (`ios2`) | Android |
| --- | --- | --- | --- |
| Bundle id / package | `com.akash.hammeapp` | `com.hamme.app` | `com.hamme.app` |
| URL scheme | `hamme` | `hamme2` | `hamme` |
| Firebase iOS app | existing | **new** (add it) | existing Android app |
| Subscription | `hamme_pro_weekly` | `hamme_pro_weekly` (recreate) | Play Console |
| Web landing deployment | existing Vercel project | **second** Vercel project | either |

`com.hamme.app` was chosen because it matches the Android package and the bundle
id already in `codemagic.yaml`. To use a different id, replace it in the three
`PRODUCT_BUNDLE_IDENTIFIER` entries in `ios/Runner.xcodeproj/project.pbxproj`,
in `codemagic.yaml` (`ios_signing.bundle_identifier`), and in
`APPLE_IAP_BUNDLE_ID` below.

## What the code already does (committed on `ios2`)

- iOS bundle id is `com.hamme.app` (`project.pbxproj`).
- iOS registers the `hamme2` URL scheme (`ios/Runner/Info.plist`); the Flutter
  app accepts both `hamme` and the configured `APP_SCHEME` (`lib/app.dart`).
- The iOS Codemagic workflow builds with `APP_SCHEME=hamme2`.
- The web landing page opens `VITE_IOS_APP_SCHEME` on iOS and always `hamme` on
  Android (`client/src/App.jsx`).
- The backend verifies Apple purchases for several apps
  (`APPLE_IAP_BUNDLE_ID` + `APPLE_IAP_EXTRA_APPS`), and refreshes a stored
  subscription by trying each configured app.

Everything below is manual work that lives outside git.

## 1. App name

Two different names exist, and only one has to be unique:

- **App Store name** (App Store Connect > App Information > Name, up to 30
  characters). Must be unique across the whole App Store. The old listing already
  owns "Hamme", so the new listing needs a different name, for example
  "Hamme: Anonymous Polls" (the subtitle can carry the rest).
- **Home-screen name** (`CFBundleDisplayName` in `ios/Runner/Info.plist`,
  currently "Hamme"). Does not have to be unique. It can stay "Hamme", but then a
  user with both apps sees two identical icons. Change it only if that matters.

## 2. Apple Developer portal

1. Use the **same developer team** as the old app. The steps in sections 3 and 4
   (shared keys) assume this.
2. Certificates, Identifiers & Profiles > Identifiers > register `com.hamme.app`
   (explicit App ID).
3. Enable the same capabilities as the old app. At minimum **Push
   Notifications** (`aps-environment` in `ios/Runner/Runner.entitlements`). Add
   Sign in with Apple or Associated Domains only if the app uses them.

## 3. App Store Connect

1. My Apps > + > New App. Platform iOS, the new name, bundle id `com.hamme.app`,
   an SKU such as `hamme-ios-2`.
2. Choose the category you want (this is the reason for the new listing). Fill in
   privacy policy URL, support URL, age rating, App Privacy labels, screenshots.
3. **Subscriptions**: create a subscription group and the auto-renewing product
   `hamme_pro_weekly` (same product id string as the old app, which the code and
   backend expect). Add price, localization, and the review screenshot of the
   paywall. The first subscription must be attached to the app version when you
   submit it for review.
4. Note the **numeric Apple ID** of the new app (App Information > General
   Information > Apple ID). You need it for the backend.
5. Note the numeric Apple ID of the **old** app as well.
6. Paid Apps agreement, tax, and banking are per team. If you use the same team
   they are already active.
7. The App Store Connect **In-App Purchase key** (Users and Access >
   Integrations > In-App Purchase) is team-wide: the issuer id, key id, and `.p8`
   already stored in the backend work for both apps.
8. Review notes: give App Review a working demo account and explain how to reach
   the paywall and the report/block controls.

## 4. Firebase (project `hamme-app`)

1. Project settings > Add app > iOS, bundle id `com.hamme.app`.
2. Download the new `GoogleService-Info.plist` and replace
   `ios/Runner/GoogleService-Info.plist`. The file in the repo still describes the
   old app (`com.akash.hammeapp`), so push and auth for the new app are not
   reliable until you do this.
3. Cloud Messaging > Apple app configuration: upload the APNs **authentication
   key** (.p8) for the new iOS app. One APNs key works for every app in the team,
   so reuse the existing key.
4. If Google Sign-In is used: copy `REVERSED_CLIENT_ID` from the new plist into
   the `CFBundleURLSchemes` of `ios/Runner/Info.plist` (as an extra scheme entry).
5. Using the **same Firebase project** keeps one user base and the same
   `FIREBASE_SERVICE_ACCOUNT_JSON` on the backend. Push notifications reach both
   apps because each device registers its own FCM token.

## 5. Backend environment (host variables, NOT in git)

Set these on the host (for example Vercel > Project > Settings > Environment
Variables), then redeploy:

| Variable | Value |
| --- | --- |
| `APPLE_IAP_ISSUER_ID`, `APPLE_IAP_KEY_ID`, `APPLE_IAP_PRIVATE_KEY_BASE64` | unchanged (team-wide key) |
| `APPLE_IAP_BUNDLE_ID` | `com.hamme.app` (new app, primary) |
| `APPLE_IAP_APP_ID` | numeric Apple ID of the **new** app |
| `APPLE_IAP_EXTRA_APPS` | `com.akash.hammeapp:<numeric Apple ID of the old app>` |
| `PRO_PRODUCT_IDS` | `hamme_pro_weekly` (unchanged) |

Notes:

- Production purchases are rejected if a bundle id has no numeric Apple ID, so
  fill in both IDs. Sandbox / TestFlight purchases do not need them.
- A user's Pro status is stored on their Hamme account. A user who subscribed in
  the old app is still Pro when they sign in to the new app: the backend finds
  the owning app by trying each configured one. Subscriptions themselves belong
  to the app they were bought in, so a user can end up subscribed in both and
  paying twice. Consider a note in the paywall or support page.
- To retire the old app later, remove `APPLE_IAP_EXTRA_APPS`.

## 6. Deep links and the web landing page

A custom URL scheme is not unique on iOS: if two installed apps register
`hamme`, iOS picks one of them and you cannot control which. The fix is one
scheme per app, and a landing page that opens the right one.

How it works with two iOS apps:

1. Each app builds share links from its own `SHARE_LINK_BASE` / `APP_HOST`.
2. Each web deployment opens one iOS scheme and one App Store URL.
3. A tap on a link always opens the app that created it (or the store page if it
   is not installed). Both apps can be installed and each opens only its own
   links. The old landing page keeps opening `hamme`; the new one opens `hamme2`.

Steps:

1. Create a **second Vercel project** from the same `client` folder.
2. Set its environment variables:
   - `VITE_API_BASE_URL` same as the first project
   - `VITE_APP_STORE_URL` the **new** app's App Store URL
   - `VITE_IOS_APP_SCHEME=hamme2`
   - `VITE_PENDING_TTL_SECONDS` same as the backend
3. Note its domain, for example `hamme-ios2.vercel.app` (or a custom domain).
4. In `codemagic.yaml` (iOS workflow only) set `SHARE_LINK_BASE` and `APP_HOST`
   to the new domain (`https://<domain>/poll` and `<domain>`), then commit.
5. Leave the first Vercel project and the Android workflow alone.

Caveats:

- Links already shared from the old app keep opening the old app.
- iOS does not let a web page detect whether an app is installed, so with the
  app missing Safari may show its "cannot open page" alert before the App Store
  fallback. This already happens with the single-app setup.
- A cleaner long-term option is **Universal Links** (an `apple-app-site-association`
  file plus the Associated Domains capability). It is not set up in this
  project, and when two apps claim the same domain iOS still opens only one, so a
  separate domain per app is still needed.

## 7. Codemagic

1. Codemagic > Teams > Integrations: confirm the App Store Connect API key
   (`app_store_credentials` group) belongs to the same team.
2. The iOS workflow signs with bundle id `com.hamme.app`. Generate or fetch the
   distribution certificate and App Store provisioning profile for that id.
3. Run the iOS workflow and publish to TestFlight.

## 8. Release checklist

- [ ] Bundle id registered, new App Store Connect app created
- [ ] `GoogleService-Info.plist` replaced with the new iOS app's file
- [ ] `hamme_pro_weekly` created in the new app and attached to the version
- [ ] Backend env vars updated and redeployed (section 5)
- [ ] Second Vercel project live; `SHARE_LINK_BASE` / `APP_HOST` updated
- [ ] TestFlight build installed next to the old app on a device
- [ ] Sandbox purchase on the new app succeeds and unlocks Pro
- [ ] A new-app share link opens the new app; an old-app share link opens the old one
- [ ] Push notification received on the new app
- [ ] Android still builds and its share links still open the Android app
- [ ] Review notes and demo account added, submitted for review

## What does not carry over to the new app

Ratings and reviews, download history, TestFlight testers, push tokens, and
active Pro subscriptions are all tied to the old App Store app.

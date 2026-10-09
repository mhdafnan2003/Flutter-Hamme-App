# iOS2: shipping Hamme as a new App Store app

The `ios2` branch moves the iOS app to a new bundle id so it can be submitted as a
separate App Store listing.

| | Old iOS app | New iOS app (`ios2`) |
| --- | --- | --- |
| Bundle id | `com.akash.hammeapp` | `com.hamme.app` |
| Android package | `com.hamme.app` | unchanged |

The bundle id is set in three places in `ios/Runner.xcodeproj/project.pbxproj`
(Debug/Release/Profile). If a different id is chosen, replace all three, plus
`codemagic.yaml` (`ios_signing.bundle_identifier`) and `APPLE_IAP_BUNDLE_ID`.

## Manual steps (not in git)

1. **Apple Developer portal**: register the App ID `com.hamme.app`. Enable Push
   Notifications (matches `aps-environment` in `ios/Runner/Runner.entitlements`)
   and any other capabilities in use.
2. **App Store Connect**: create the new app record, then recreate the
   `hamme_pro_weekly` auto-renewing subscription (and its subscription group) on
   it. Note the new numeric Apple ID (App Information).
3. **Firebase** (project `hamme-app`): add a new iOS app with bundle id
   `com.hamme.app`, download its `GoogleService-Info.plist`, and replace
   `ios/Runner/GoogleService-Info.plist`. The current file still points at the old
   app (`com.akash.hammeapp`). If Google Sign-In is used, also update the
   reversed client id URL scheme in `ios/Runner/Info.plist`.
4. **Backend environment** (host env vars, e.g. Vercel; not tracked in git):
   - `APPLE_IAP_BUNDLE_ID=com.hamme.app`
   - `APPLE_IAP_APP_ID=<new numeric Apple ID>`
   The backend verifies a single bundle id, so the old iOS app's purchases will
   be rejected once these change.
5. **Codemagic**: generate signing for `com.hamme.app` (App Store distribution).
6. Bump the version in `pubspec.yaml` if needed, archive, upload, and submit the
   new app version together with the subscription for review.

## Does not carry over

Ratings/reviews, download history, push tokens, TestFlight testers, and active
Pro subscriptions all belong to the old app.

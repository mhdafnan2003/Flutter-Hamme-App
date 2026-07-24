# 1. iOS Instagram Story sharing fix

## Changes already made

- `ios/Runner/Info.plist` now allows the app to query the `instagram` and
  `instagram-stories` URL schemes. iOS otherwise reports Instagram as
  unavailable even when it is installed.
- Both Instagram Story share flows now read the Meta App ID from the
  `META_APP_ID` build setting instead of sending an empty value.

## Required setup before an iOS release

1. Create or use a Meta developer app and copy its numeric **App ID**.
2. Configure the app's iOS bundle identifier in Meta to match the Runner
   bundle identifier used for the release build.
3. Build with the App ID. For example:

   ```powershell
   flutter build ipa --dart-define=META_APP_ID=123456789012345
   ```

   Use the same `--dart-define` when running locally:

   ```powershell
   flutter run --dart-define=META_APP_ID=123456789012345
   ```

4. Fully uninstall and reinstall the app on a physical iPhone after changing
   `Info.plist`; a hot restart does not apply plist changes.
5. Install Instagram and test the Inbox share button. It should open the
   Instagram Story composer with the generated share image. The link is copied
   to the clipboard for the user to add with Instagram's Link sticker.

## Why Android already worked

Android launches Instagram through an explicit native intent targeting
`com.instagram.android`. Its package visibility is already declared in
`AndroidManifest.xml`. iOS uses protected URL schemes instead, and Apple
requires those schemes to be listed in `LSApplicationQueriesSchemes` before
`canOpenURL` is allowed to detect or open them.

## Notes

- Instagram Story sharing must be tested on a real iPhone; the iOS Simulator
  cannot run Instagram.
- Do not commit a secret in `META_APP_ID`. A Meta App ID is normally public,
  but CI should still provide it through a build variable rather than source
  code.

# 2. Match popup persistence

## Current approach

The Play screen saves IDs of match popups already shown in `SharedPreferences`
on the device. This prevents the same match from appearing every time the app
is reopened while allowing newly created match IDs to appear normally.

This is intentionally local-only because the current product is used on one
device and does not require cross-device account state.

## Retention recommendation

The current saved-ID list is capped at 500 entries. It removes only the
oldest ID when the limit is exceeded; it does not clear all saved data.

The backend only returns matches from the previous 24 hours, so IDs older than
that cannot reappear. In the unlikely event that more than 500 matches arrive
within one 24-hour window, only an evicted oldest match could be shown again.

For a complete local-only solution, store each shown match ID with the time it
was shown and remove entries only after 24 hours. That prevents repeats even
when more than 500 matches are received in one day, without requiring a server
change.

## When server-side persistence is needed

Move match-seen state to the backend only when it must survive app-data
clearing or reinstall, or when the same user can use multiple devices.


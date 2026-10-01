# UI review notes

## Splash screen

- Figma frames `iPhone 16 - 99` and `iPhone 16 - 127` show only the centered wordmark on the gradient. The app also displays a connection error message and Retry button when session restoration fails. This conditional UI is extra relative to those frames and has been preserved.

## Onboarding community rules

- `CommunityRulesScreen` is present in the app's onboarding route, but no matching community rules frame was found among the 90 top-level frames on Figma's DESIGN page. The screen has been kept for review rather than removed.

## Share/Home profile card

- `HomeProfileCard._changeProfileImage` is currently unused. It uploads a photo and writes the URL to the onboarding draft, but does not update the server profile. If that method were connected to the edit icon, the photo might not persist. The icon now opens the existing Profile screen, whose photo edit flow updates the server profile.

## Inbox

- The app can show a vote-management section below the reaction cards for hiding, reporting, and blocking votes. The visible Inbox Figma frames do not depict this section. It has been preserved because it supports existing moderation actions.
- The Inbox share-export widget accepts `isInstagram`, and its comment says the value changes a cosmetic badge color, but the parameter is not read and currently has no effect. This behavior was left unchanged during the UI alignment pass.

## Matches

- Match rows in the app include a separate report/block menu beside the close button. The populated Matches Figma frame shows only the close button. The safety control has been kept because it enables existing moderation actions.
- The match detail/reply screen has a safety menu at the upper left. Its Figma variants show only the close button; the safety menu remains to preserve report/block access.
- The match detail Figma pill appears to offer Instagram/Snapchat selection. The app's existing Reply action automatically prefers Instagram when present, otherwise Snapchat. The new pill reflects that choice visually but does not switch platforms; adding selection behavior is outside this UI-only pass.

## Match success

- The app shows a top-right close button on the match success overlay. The corresponding Figma share screen has no close control. It is retained so users can dismiss the overlay.

## Story sharing

- Figma's active DESIGN page contains two story templates: the Instagram-style “PLACE LINK STICKER HERE” prompt (`4593:569`) and a “HAMME.LINK” treatment (`4673:1474`). The export now supports both visual variants, selecting the HAMME.LINK treatment for the Snapchat share path while keeping the existing share destinations and clipboard behavior unchanged.
- The Figma template frame is 360×800 (9:20), while the exported story image remains 1080×1920 (9:16), the standard story-media canvas. This aspect-ratio difference is preserved for platform compatibility; confirm with the design owner if the export should instead follow the 9:20 Figma frame.
- `SharePlayingScreen.autoShare` is parsed and passed by the router but not read by the screen; `initState` always starts sharing. A direct `/share/playing` route with `autoShare=false` still triggers a share. This behavior was not changed in the UI-only pass.

## Screens without a current DESIGN reference

- The active Figma `DESIGN` page has no complete screen matching the current `/profile`, `/settings`, `/settings/notifications`, `/settings/appearance`, community-guidelines, or blocked-users routes. The `MISC` page has an older combined profile/preferences frame (`iPhone 16 - 38`, 360×1080) with different content (age/stats, socials, and “Pause my link”), so it is not a safe visual target for the current screens. The app UI is preserved pending confirmation that this older frame is still authoritative.

## Play non-match state

- `poll_not_a_match_overlay.dart` is currently unreferenced. The matching Figma design is the embedded non-match state inside Play, which retains the top bar and bottom navigation. The live Play state was aligned; the unused standalone widget remains in the repository.

## Client website

- The Figma desktop landing hero had no matching root page in `client/`; `/` showed an invalid share-link state. A responsive landing hero was added at `/`. The production build passes. The existing ESLint run still reports four issues in `client/src/App.jsx` (an empty catch and unused values/functions); these are outside the UI change and were present before this page was added.
- The public poll question frame shows only Terms and Privacy in its footer. The website also retains Guidelines and Support links, the app's voting disclosure (Terms/Community Guidelines agreement text), and the additional “Report this profile” link. The disclosure has been compacted and the page spacing adapted so these extras do not push the Figma footer off standard phone-height viewports.
- The Figma Reveal state does not include the app's separate “Your response was sent anonymously” status line; it is retained as a compact secondary status below “Sent!”. The Already Voted state also has no matching frame in the Figma file and is preserved as an app-only state.

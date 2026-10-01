# UI review notes

## Splash screen

- Figma frames `iPhone 16 - 99` and `iPhone 16 - 127` show only the centered wordmark on the gradient. The app also displays a connection error message and Retry button when session restoration fails. This conditional UI is extra relative to those frames and has been preserved.

## Onboarding community rules

- `CommunityRulesScreen` is present in the app's onboarding route, but no matching community rules frame was found among the 90 top-level frames on Figma's DESIGN page. The screen has been kept for review rather than removed.

## Share/Home profile card

- `HomeProfileCard._changeProfileImage` is currently unused. It uploads a photo and writes the URL to the onboarding draft, but does not update the server profile. If that method were connected to the edit icon, the photo might not persist. The icon now opens the existing Profile screen, whose photo edit flow updates the server profile.

## Inbox

- The app can show a vote-management section below the reaction cards for hiding, reporting, and blocking votes. The visible Inbox Figma frames do not depict this section. It has been preserved because it supports existing moderation actions.

## Matches

- Match rows in the app include a separate report/block menu beside the close button. The populated Matches Figma frame shows only the close button. The safety control has been kept because it enables existing moderation actions.
- The match detail/reply screen has a safety menu at the upper left. Its Figma variants show only the close button; the safety menu remains to preserve report/block access.
- The match detail Figma pill appears to offer Instagram/Snapchat selection. The app's existing Reply action automatically prefers Instagram when present, otherwise Snapchat. The new pill reflects that choice visually but does not switch platforms; adding selection behavior is outside this UI-only pass.

## Match success

- The app shows a top-right close button on the match success overlay. The corresponding Figma share screen has no close control. It is retained so users can dismiss the overlay.

## Play non-match state

- `poll_not_a_match_overlay.dart` is currently unreferenced. The matching Figma design is the embedded non-match state inside Play, which retains the top bar and bottom navigation. The live Play state was aligned; the unused standalone widget remains in the repository.

## Client website

- The Figma desktop landing hero had no matching root page in `client/`; `/` showed an invalid share-link state. A responsive landing hero was added at `/`. The production build passes. The existing ESLint run still reports four issues in `client/src/App.jsx` (an empty catch and unused values/functions); these are outside the UI change and were present before this page was added.
- The public poll question frame shows only Terms and Privacy in its footer. The website also retains Guidelines and Support links, the app's voting disclosure (Terms/Community Guidelines agreement text), and the additional “Report this profile” link. The disclosure has been compacted and the page spacing adapted so these extras do not push the Figma footer off standard phone-height viewports.

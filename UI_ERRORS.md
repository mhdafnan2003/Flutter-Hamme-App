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

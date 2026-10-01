# Client UI review — October 1, 2026

Live HAMME Figma references were retrieved read-only through Figma Console MCP's desktop bridge. REST retrieval was rate limited, so the parent agent cached current node geometry/font/fill trees and exported reference PNGs in the temporary review directory. Source screenshots were never used as implementation assets.

## Implemented and checked

- **Landing `/` — DESIGN 5342:1155, 1024 × 500.** Nunito typography was already present; corrected reaction tilt direction/origin, gradients, shadow, dimensions and content centers. Figma positive rotations run opposite to CSS. Kept responsive stacked layout, because no mobile landing reference was supplied.
- **Public question `/poll/:code` and legacy `/u/:code` — DESIGN 5305:877, 360 × 800.** Reused local Figma-style emoji images instead of platform-dependent system emoji; matched 18px/800 reaction and question text, 14px/600 anonymous label, avatar/bar geometry, reaction y298/354/410 positions, gradients and shadows. Added the existing Schibsted Grotesk font for the footer tagline and corrected friend-avatar colors/weights.
- **Reveal after voting — DESIGN 5365:725, 360 × 800.** Fixed CSS overriding absolute label/arrow placement and hiding the raised base. Matched Sent at y90, three title rows in 32px/800 Nunito with 44px line height, reference countdown sizes/progress y401 and CTA at y416 with 328 × 56 size. Names can wrap safely instead of forcing unpredictable title line breaks. Kept reduced-motion handling, expiration/disabled behavior, deep links, timers and vote handling. Prevented extra footer from overlapping the CTA on short screens.
- Production build passes. Browser assertions cover 1024 × 500 landing; 360 × 800, 320 × 568, 390 × 844 and 844 × 390 public flows, plus an unbroken long name at 320px. These intercept API requests and do not send real votes. Assertions check reference geometry, loaded images/fonts, horizontal overflow, usable reaction controls and Reveal positioning/shadow/footer clearance. Screenshots were manually compared with Figma at reference sizes and inspected at narrow/short sizes.
- Client lint retains the same four existing App.jsx issues: empty catch, unused question `profileName`, unused fallback URL helper and unused copy-link helper. No new lint errors were introduced.

## Doubts and preserved extras for final review

1. **Reveal reference differs from existing product flow.** Latest 5365:725 has a black `Make my own link` CTA at y518 and no friends-playing banner. Existing website has friends-playing and a response/match status line. These extras remain, per the user's instruction. The new CTA is skipped until its intended destination and behavior are agreed; adding an unconnected button or redirecting the existing Reveal logic would change product behavior. Consequently Reveal is not an exact whole-page match yet.
2. **Safety UI differs from Figma.** Consent text below the reaction buttons, Guidelines/Support footer links and Report this profile link are retained. These add content absent from the reference; they are not removed to achieve a screenshot match.
3. **Landing mobile layout.** Only desktop 1024 × 500 reference was available. Narrow/short layout is verified usable, but exact mobile Figma fidelity cannot be claimed without the intended reference.
4. **Extra client pages/states lack supplied Figma references.** Privacy Policy, Terms of Service, Community Guidelines, Support, loading, invalid/missing profile, blocked voting, rate limiting, submission errors, already-voted, link-expired and dynamic match-status states remain. Their logic/content was not removed or redesigned from an invented reference.
5. **Dynamic images/names.** Browser review uses a local placeholder profile photo and a test name, so those pixels deliberately differ from Figma's sample photo/name. Production remains driven by the profile API.
6. **Native app/store opening needs device verification.** Mocked desktop browser checks do not prove installed-app behavior on Android/iOS. No changes were made to those handlers.

## Re-run browser checks

Run `npm run build`, then `npm run preview -- --host 127.0.0.1 --port 5174` in `client`. With Playwright installed and Chrome available, set `UI_TEST_ORIGIN=http://127.0.0.1:5174`, optionally `PLAYWRIGHT_MODULE` to the installed Playwright package location, and run `node client/ui-tests/landing-layout.cjs` and `node client/ui-tests/public-poll-layout.cjs` from the repository root. `UI_SCREENSHOT_DIR` optionally saves full-page screenshots.

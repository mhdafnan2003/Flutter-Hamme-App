# Onboarding UI review

Reference: HAMME Figma m2H92wOLmAMzXX7z0DfXGb, DESIGN; live geometry cached 2026-10-01 by parent reviewer in figma-client-onboarding.json. These are progress notes, not a claim of full screen perfection.

## Implemented
- DOB: title 24px Nunito Black with 33px linebox; age 48px ExtraBold/65px linebox; years 20px ExtraBold/27px linebox. Fixed card now grows with text scaling rather than overflowing. Real Nunito test covers 320x480 at 2x scaling; prior version failed with 221px overflow.
- Name: matching title and input 33px lineboxes, helper 19px linebox; compensated default gaps to preserve vertical anchors. Content filter and validation unchanged.
- Profile upload: matching title 33px linebox and adjusted following gap. Photo picker/upload validation unchanged.

## Still requiring verification and decisions
- DOB: matched wheel pitch to 35px and text linebox to 27px from reference 4673:1534 (five age rows at y506/537/572/607/638), scaling row height with system font size. Actual-font rendered overlay and exact wheel row geometry remain outstanding; do not claim the full page verified.
- All screens: compare rendered actual-font 393x852 with platform safe areas to reference, including CTA bottom inset. Initial existing tests omit real device insets and are insufficient to prove fidelity.
- Name frames 4373:697/4482:410 include native iOS keyboard; app preserves platform keyboard and validation errors. Test keyboard-open geometry with actual fonts.
- Photo frames 4373:698/4473:1135: current profile prompt chips and photo callsites/assets need actual rendered overlay.
- Social frames 4408:1753/4482:427: matched 33px title/input and 22px selector lineboxes, retained y130 title/y204 selectors/y287 input/y429 CTA with real Nunito and keyboard insets in three passing tests. Preserve Skip and registration validation. Large font variants and final rendered overlay remain outstanding.
- Pro: latest 5064:1085 omits social proof; older 4744:4263 includes social proof currently in app. Preserve that extra pending client decision; billing, restore, terms and platform interactions must remain.
- Community rules page is an additional app flow with consent, terms and legal links. No mapped Figma frame supplied; preserve it and obtain intended reference rather than removing consent.
- Splash 4424:2844 shows the centered outlined wordmark. Preserve added offline retry/session restore state; default wordmark and error state rendered verification outstanding.


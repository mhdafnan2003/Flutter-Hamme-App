# Onboarding UI review

Reviewed 2026-10-01 against HAMME file `m2H92wOLmAMzXX7z0DfXGb`, DESIGN page. Live geometry and typography were read through Figma Console MCP. Actual Flutter renders use the application theme, bundled Nunito and Schibsted Grotesk, loaded raster assets, 393x852 reference viewport, top inset 59, bottom inset 34, and keyboard inset 343 for name/social. Native status bars and native keyboard appearance are supplied by the OS rather than app widgets.

| Screen | Actual Figma reference | Verification and result |
| --- | --- | --- |
| Splash | 4424:2844 | Rendered and compared outlined wordmark and purple gradient. Corrected unwanted FittedBox shrink by using the 65px linebox. Centering tests pass at 393 and 320 widths. Offline restore/retry extra preserved. |
| Age / DOB | 4593:478, 4673:1534 | Rendered comparison, 24px Nunito Black/33px title, 48px ExtraBold/65px age, 20px ExtraBold/27px years, 35px wheel pitch, 130x112 default card. Reference anchors title130/years348/CTA735 verified with actual font. Compact 320x480 and 2x-font tests pass; card/wheel grow and page scrolls. Sample `00` remains actual selected age instead of fake design data. |
| Name | 4373:697, 4482:410 | Rendered reference keyboard layout. Title130/input285/helper398 verified using bundled fonts. Existing compact and content validation tests preserved. |
| Photo | 4373:698, 4473:1135 | Rendered reference title, camera, 192px first chip, tilted second chip, 158px avatar at365, and CTA735. Corrected cropped silhouette and clock assets; exact live exports preserved locally. Compact tests pass. Dynamic selected profile photo remains dynamic. |
| Social | 4408:1753, 4482:427 | Rendered reference keyboard layout with actual fonts. Existing coordinate tests verify title130/selectors204/input287/CTA429. Three tests pass, including compact platform switching. Skip, validation and registration logic preserved. |
| Pro | 4744:4263, 5064:1085 | Rendered with actual fonts and assets. Use older 4744:4263 composition to preserve existing social-proof UI. Geometry test verifies title196/features328,428,526/CTA690/footer804. Fixed duplicate bottom inset and compressed feature typography. Three existing tests pass at reference, shorter and very short sizes. Billing, restore, legal links, submission and error handling unchanged. |
| Community rules | No matching frame found | Live DESIGN text query for community/good vibes/terms acceptance found no reference. Rendered existing consent screen without overflow at reference size. Preserve consent/version/legal links and scrollable rules. Exact redesign deferred pending a reference. |

## Asset verification

- `assets/icons/onboarding_profile_user.svg`: direct SVG export of Figma 4373:802, intrinsic 60x60, rendered in the 60x60 avatar icon slot. Replaces a cropped 146x181 source that made the head and torso too large.
- `assets/icons/onboarding_profile_clock.svg`: direct SVG export of 4373:796, intrinsic 20x20, rendered in the 20x20 chip slot.
- Profile rectangle icon uses the existing 16px asset in its 16px slot; plus uses existing 24px asset in its 24px slot; their local files are non-empty. The existing speech-tail slot and tilt were retained and compared visually.
- Cake, speaking head and camera PNGs are non-empty, explicitly preloaded in render verification and shown at the 24px reference slots.
- Pro header curve 393x156, logo143x38, close17x17, and unlocked/infinity/rewind/lightning assets were explicitly loaded and visually inspected. Header wordmark remains centered across phone widths.

## Decisions still required

1. Latest Pro frame 5064:1085 omits social proof and moves the CTA; older 4744:4263 includes the existing row. User requested preserving extras, so retain the older composition until the client chooses. Do not silently delete the row.
2. Community rules, offline retry, form validation errors and dynamic loading/submission states are additional product states with no supplied Figma counterparts. Preserve them; obtain references if the client wants their exact styling changed.
3. OS keyboard/status-bar appearance differs by platform; these are not replaced with Figma screenshot imagery.

`test/onboarding_render_review_test.dart` verifies seven actual-font screens and the listed reference anchors. Set `RENDER_UI=1` when running it to write PNGs to the system temporary `hamme-ui-review` directory. Pro no-scroll assertions allow only 0.001 logical pixels of floating-point rounding, rather than introducing a whole-pixel gap to satisfy an exact zero comparison.

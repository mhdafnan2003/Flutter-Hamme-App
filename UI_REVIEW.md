# Figma alignment review

Source: HAMME, file `m2H92wOLmAMzXX7z0DfXGb`, DESIGN page. Measurements and rendered references were obtained through the live Figma Console bridge on 2026-10-01. The user's current two-tab requirement overrides older three-tab frames. Inbox routes and data remain intact.

This is a coverage and ambiguity log, not a claim that every screen is pixel-perfect. Page-specific notes contain detailed verification and remaining differences.

| App page/state | Reference | Review coverage |
| --- | --- | --- |
| Splash | 4424:2844 | Onboarding review |
| Age / date wheel | 4593:478, 4673:1534 | Actual Nunito, scaled text and compact layout tests; onboarding visual review |
| Name / keyboard | 4373:697, 4482:410 | Onboarding review |
| Profile photo upload | 4373:698, 4473:1135 | Onboarding review |
| Social selection / keyboard | 4408:1753, 4482:427 | Onboarding review |
| Pro | 5064:1085, 4744:4263 | Onboarding review; retained extra social proof |
| Home | 5347:1176 | Home / Inbox review |
| Instagram tutorial, steps 1–4 | 4724:2585, 4724:2936, 4724:3034, 4724:3123 | Typography/card measurements and compact scrolling tests; Close routing regression fixed |
| Snapchat tutorial, steps 1–4 | 4768:750, 4768:525, 4768:644, 4724:3312 | Same shared card; platform switching and all steps tested |
| Story export | 4593:569, 4673:1474 | Home / Inbox review; canvas aspect ratio needs decision |
| Empty / populated Inbox | 4441:1043, 4744:4315, 4744:4373, 4744:4436 | Home / Inbox review; route retained and navigation tab hidden |
| Inbox exports | 4424:3013, 4440:587, 4440:690 | Home / Inbox review |
| Play queue / anonymous queue | 5347:1222, 5347:1275 | Play / Matches review |
| Nonmatch / rewind | 5305:779 | Play / Matches review; compact overflow fixed |
| Match success | 5305:751 | Play / Matches review |
| Play cooldown | 4744:4197 | Play / Matches review |
| Empty Play / empty Matches | 4468:839, 4468:774 | Play / Matches review |
| Matches list / reply / anonymous reply | 5036:759, 5036:858, 5305:985 | Play / Matches review |
| Original-poller match popup | 4440:725, 5036:858 | Active Play call site; shared Reply layout with preserved dismissal and haptics |
| Match share exports: Friend / Frenemy / Crush | 4440:433, 4440:472, 4441:900 | Play / Matches export review |
| Website landing / question / reveal | 5342:1155, 5305:877, 5365:725 | Client review and production-browser checks |
| Expired website Reveal | 4702:2047 | Expired control styles applied to current Reveal composition; timer and disabled behavior tested |

## Screens without an identified current matching design

The DESIGN page's frame text inventory does not identify full screens for Profile editor, Settings, Notification settings, Appearance settings, Community guidelines, Blocked users, Terms acceptance, or Account suspended. Preserve these extra screens and their behavior. Do not substitute onboarding profile-upload or website Terms links for these screens. Exact visual redesign is deferred until matching frames are provided or selected.

Community rules/consent and safety menus are additional functional UI. The file does contain older block/report mockups (4733:3579 and 4733:3660), but they describe a combined block-and-report flow. The app has separate reporting reasons, blocking, hiding, and async error states. Preserve these controls; deciding how to combine them requires a product decision.

The final coverage audit searched all 90 DESIGN frames and checked active app call sites. `PollMatchOverlay` is active and reviewed separately from the post-vote celebration. `PollNotAMatchOverlay`, `AuthTextField`, the old date-picker wheel chain, `PlayingFriendsRow`, and `ShareOptionButton` have no active call sites and are retained as unused code; they are not claimed as verified app pages. The explanatory user-flow diagram 4473:1030 is not an app screen.

## Remaining decisions

- Multiple old and new Figma versions coexist. Use the listed current references; record conflicting variants rather than silently combining them.
- Story exports use a platform-compatible 1080×1920 canvas. Figma source frames have different aspect ratios. Preserve uniform scaling and native sharing while deciding the final crop/composition.
- Website Reveal's latest frame includes “Make my own link”. Its intended destination/behavior is not specified by the existing flow; see client notes.
- Keep extra safety, billing, consent, friends/status, and profile controls. Their absence from a frame does not authorize deleting them.

## Verification

Targeted widget checks load the real bundled fonts where metrics matter. Tutorial tests exercise Close routing and all platform steps on a 320×568 phone. Home and Inbox tests cover reference and shorter devices. Browser tests use production CSS and include narrow, short, landscape, and long-name cases. Full-suite results and build status will be recorded after all parallel page changes land.

Related notes: [Onboarding](UI_REVIEW_ONBOARDING.md), [Client](UI_REVIEW_CLIENT.md), [Home and Inbox](UI_REVIEW_HOME_INBOX.md), [Play and Matches](UI_REVIEW_PLAY_MATCHES.md).

# Play and Matches UI review

Reference: HAMME Figma file `m2H92wOLmAMzXX7z0DfXGb`, DESIGN page. Read from the live Console MCP bridge on 2026-10-01; REST API was rate limited, so live geometry and node exports were used.

## References used

- Play queue: `5347:1222` (named), `5347:1275` (anonymous).
- Non-match: `5305:779`.
- Cooldown: `4744:4197`.
- New match celebration: `5305:751`, a 360 × 852 frame.
- Existing match Reply: `5036:858`, a 393 × 852 frame. Anonymous alternative: `5305:985`.
- Matches list: `5036:759`; empty Matches: `4468:774`; empty Play: `4468:839`.

## Preserved extras and decisions needing client review

1. Report/block controls remain on Play cards and Matches rows, and the Reply screen still has its safety menu. Figma's populated list only shows the dismiss control. Removing safety controls would change available behavior, so they are preserved.
2. The app currently shows its Hamme logo in the Matches header. The selected populated Figma frame exports with no visible logo. This is retained as an app extra pending a client decision.
3. Anonymous match details preserve hidden names/social handles and never expose a Reply action. The anonymous Reply position follows frame `5305:985`; safety behavior is preserved.
4. Some Figma frames have three bottom tabs and newer queue frames have two. The user's explicit two-tab instruction governs the implementation.
5. Dynamic avatar photos and usernames use actual app data and existing fallbacks. Figma sample photographs and sample reaction counts are not hardcoded.
6. Match success has a close control in the app although its 360 px Figma frame omits it. It remains available and now stays tappable when the content scrolls.
7. Non-match's crying glyph still uses the device emoji font because no corresponding bundled exact asset was found. Queue and match-choice emojis now use the existing verified bitmap assets that match the Figma images. Native emoji can differ between Android and iOS.
8. The existing match image export component is retained. No authoritative export frame was mapped from the assigned references; its share preview and output need a mapped design reference and a device-level check.
9. Native Instagram/Snapchat launching and image sharing still require a device-level integration check. Unit/widget verification covers available-platform selection, disabled missing profiles, anonymity, scrolling, and dismiss callbacks.

## Verification approach

Widget tests load the bundled Nunito variable font and exercise the actual Play voting transition, rather than reproducing only the Rewind row. Standard, narrow, and short phone sizes are covered. Reply and the Play voting/non-match transition also exercise 1.5 text scale. Optional screenshots are written outside the repository with `--dart-define=UI_SCREENSHOTS=true`; they use real fonts, icons, preloaded images, and painted shadows. Dynamic photographs are represented by normal fallback avatars in test data.

The final repository-wide test/build results are recorded by the parent review. This note is not a claim that every app page or native sharing flow is complete.

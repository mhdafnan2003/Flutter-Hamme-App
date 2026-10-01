# Extra screens: responsive audit

These product screens have no matching Figma frame identified in the DESIGN page. Existing visuals, content, navigation, consent, support and safety logic are retained. This audit addresses reproduced compact-device layout failures, rather than inventing Figma designs.

Baseline: 320x480, safe-area insets 24/16, actual bundled Nunito at 2x text scaling. All five original checks failed. Baseline log is in the system temporary hamme-ui-review/extra_screens_baseline.log.

| Screen | Reproduced issue | Change |
| --- | --- | --- |
| Profile | Upgrade row overflowed28px horizontally; page overflowed8px vertically. | Scrollable minimum-height layout preserves Spacer distribution on normal phones. Name/handle wrap within horizontal padding. Upgrade label wraps and button can grow vertically; photo upload/Pro/dev logout handlers unchanged. |
| Account suspended | Page overflowed342px vertically; secondary action row also overflowed. | Scrollable minimum-height layout preserves both Spacers on normal phones. Terms/OK actions wrap on narrow/enlarged layouts. Support launch, acknowledgement and non-dismissable PopScope unchanged. |
| Terms acceptance | Log out/Delete account row overflowed72px horizontally. | Secondary actions wrap; pinned agreement/save controls and scrollable rules remain. No consent or account-action changes. |
| Settings | Unconstrained section-title row overflowed at enlarged text. | Title takes remaining width and wraps after the icon. List content and settings callbacks unchanged. |
| Blocked users | Unblock all row overflowed17px horizontally. | Enlarged-font or very narrow cards place their existing action below the identity row. Normal-size cards retain the original Row layout. Data, confirmations and unblock handlers unchanged. |

Verification lives in test/extra_screens_responsive_test.dart. It checks all five compact/enlarged cases using fake auth/safety data, explicit long account name, and action visibility after scrolling. Two reference-size checks cover normal Profile upgrade height58/top728 and Account suspended support top690 to protect previous positions. No actual support email, remote API, account deletion or unblock mutation is launched by these checks.

Result: final targeted run passed all seven checks. Baseline failures and fixed-run evidence are retained in the temporary logs; the parent performs final repository-wide analysis, tests and native build after these commits.

# Pro feature and purchase validation

## Changes

- Store initialization reads the current authenticated entitlement after awaiting
  store availability. A slow initialization cannot overwrite a newly resolved
  Pro session. Stale status requests cannot overwrite a newer entitlement.
- Pro bypasses the free cooldown even when a prior vote returns an older free
  limit. Visiting the upgrade screen while already Pro dismisses it.
- Rewind opens the previous poll directly for Pro. Returning from a successful
  upgrade also resumes that rewind. The next answer sends `rewind: true` with
  the original interaction ID, and waits for the first answer to finish saving.
- The backend checks Pro and poll ownership, updates the existing response,
  and can create a resulting match. Anonymous polls are supported. Hidden,
  blocked, and already-matched polls cannot be rewound.
- Active Pro voters appear before free voters in Play, preserving newest-first
  ordering within each group. Priority is applied before the queue is truncated.
- Billing starts with the app and refreshes entitlement on resume. Pending or
  unverified payments can be reconciled after returning to the app.

## Purchase recovery behavior

| Outcome | User experience | Entitlement / transaction |
| --- | --- | --- |
| Approved | Confirmation; purchase page closes | Pro after backend verification; then transaction completion |
| Declined | Check/change payment method, then Try again | Free; checkout can be retried |
| Canceled | Return quietly to the purchase screen | Free; controls enabled |
| Pending | Payment pending; user can close the page | Free until approval; duplicate checkout blocked |
| Store connection failure | Connection guidance and retry | No local Pro grant |
| Paid but verification unavailable | Restore purchase CTA; do not purchase again | No transaction completion until verification succeeds |
| Already owned | Discover store subscription; restore onto current profile | No second checkout; transfer requires confirmation |
| Expired / held / revoked | No active entitlement | No Pro grant; renewal checkout remains possible |

Prices come from the store; the page no longer invents a USD fallback price.
Verification errors retain the subscription restoration flow, and server
configuration failures are presented as a recoverable verification failure.

## Automated checks

- Flutter billing state tests: approval, decline, cancellation, pending approval,
  pending decline, verification outage/restore, slow initialization, stale limit,
  and Android ownership preflight finding a pending payment.
- Flutter Play test: Pro bypasses a stale cooldown, Rewind opens the poll without
  a purchase route, and the changed response waits for the original save.
- Pro screen and Play layout tests; related terms/session and notification tests.
- Backend tests: Android/iOS restoration, ownership transfer/rollback,
  subscription lifecycle, pending/held/paused/expired rejection, grace and paid
  cancellation access, priority order, registered/anonymous rewind and guards.
- Static analysis and backend JavaScript syntax checks.

Automated purchase cases use a simulated store. They do not count as real card
transactions. Device checkout results must be recorded separately.

## Android sandbox results (2 October 2026)

Tested on the connected Realme device with Google Play license-test checkout.
The sheet explicitly displayed a test subscription and stated that no charge
would be made. The test profile was `billing-30d86f`.

| Device case | Observed result |
| --- | --- |
| Always declines | Google displayed the test decline. Hamme stayed free, showed payment/Restore guidance, and enabled Try again. |
| Retry after decline | A second Google checkout opened successfully. |
| Close checkout | Hamme returned without an error or stuck spinner; Continue was enabled. |
| Always approves | Backend recorded active Android store Pro; Hamme closed the paywall and displayed Pro Plan. |
| Update/restart | The session and Pro Plan persisted after installing the updated APK and restarting the app. Play displayed its empty queue, without a free cooldown or upgrade prompt. |

Google offered approve, decline and chargeback test cards for this subscription.
Slow pending cards were not offered in this checkout. Pending approval/decline
and verification outage recovery were tested with automated store simulations.
Chargeback was not submitted; its end-to-end notification delivery still needs
a separate test. Rewind persistence and priority ordering passed automated
tests; this test profile had no incoming polls for a device rewind test.

The updated debug build installed at 10:51 and passed restart checks. A later
APK containing the additional pending-ownership guard built successfully but
could not replace it: Android's scan passed, then installation returned
`INSTALL_FAILED_INSUFFICIENT_STORAGE`. The installed app and session were
preserved. The final APK is at
`build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`.

## Release

Deploy the backend changes together with the Flutter update. The response
endpoint needs support for `rewind: true`; an older backend will reject a
registered poll's rewind as an anonymous response. No new products or database
schema changes are required. Use `ALLOW_UNVERIFIED_IAP=false` for real billing
validation and deployed environments.

Use a Google Play license tester and confirm that the store sheet explicitly
shows a test payment instrument before submitting a purchase. Test decline and
cancellation before approval, because approval creates an owned subscription.
Pending test instruments depend on the product/base plan supported by Play.
For renewals, grace, hold and recovery, use Play Billing Lab.

Reference: [Google Play billing testing](https://developer.android.com/google/play/billing/test).

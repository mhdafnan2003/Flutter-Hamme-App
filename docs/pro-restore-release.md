# Pro restoration release checklist

## Expected behavior

After reinstalling or deleting a Hamme account, finish setting up the new
profile using the same Google Play / Apple purchase account. Android checks
owned subscriptions before opening checkout. An already-owned purchase or the
Restore button opens a confirmation to link the active subscription here.
Confirming moves store Pro to this profile without charging again. It does not
recover the old profile's votes, matches, photos, or login credentials.

Expired, refunded, revoked, and on-hold purchases do not grant Pro. Cancellation
retains access through the paid period, and supported billing grace periods
retain access. Complimentary admin Pro remains independent of store Pro.

## Backend deployment

- Deploy the backend before releasing both mobile updates. Drain old backend
  instances before allowing transfers: the old code assumes immutable ownership.
- MongoDB must support transactions (Atlas, a replica set, or a sharded cluster).
  A standalone local MongoDB instance is insufficient. Use MongoDB 5+.
- The database user needs collection/index creation and index deletion rights.
  On the first billing write, the backend creates `BillingOwnership` and the
  `pro_purchase_lookup` index, then removes the legacy unique
  `proPurchaseToken_1` index. Subscription uniqueness and concurrent claims are
  enforced through the stable ownership record within a transaction.
- Back up the database before deployment and verify this migration in staging.
  A failed transfer rolls back both profiles. Do not roll back to the old billing
  backend after transfers begin without reconciling subscription ownership.
- `/billing/restore` requires the current profile's access token, platform,
  product ID, store verification data, and explicit `confirmTransfer: true`.
  Without confirmation a new linkage returns `409 RESTORE_REQUIRED`.
- `/billing/restore-session` returns 410. Older app builds that relied on it need
  updating; a purchase no longer signs the user into somebody else's profile.
- Keep `ALLOW_UNVERIFIED_IAP=false` in deployed environments.

## Google Play

Keep the existing active `hamme_pro_weekly` product/base plan, Android package
`com.hamme.app`, Developer API service-account permissions, and authenticated
RTDN configuration described in [Google Play setup](google-play-billing-setup.md).
The obfuscated Hamme account ID recorded at initial purchase is attribution,
not a permanent restriction on future user-confirmed restores.

## App Store

Configure these backend values using App Store Connect's In-App Purchase key:

- `APPLE_IAP_ISSUER_ID`
- `APPLE_IAP_KEY_ID`
- `APPLE_IAP_PRIVATE_KEY_BASE64` (base64 of the private .p8 key)
- `APPLE_IAP_BUNDLE_ID` matching the released iOS bundle
- `APPLE_IAP_APP_ID` (numeric App Store app ID; required for production)

Use the existing `hamme_pro_weekly` auto-renewing subscription in the intended
subscription group. Paid Apps agreements, tax, banking, and product availability
must be active. No product recreation or new purchase is required for restoration.

The installed Flutter plugin uses StoreKit 2 and supplies signed transaction
data. The backend verifies its signature using the bundled public Apple Root
CA G3, then queries current subscription status with Apple's server API. Original
transaction IDs identify renewals and transfers. Stored IDs are accepted only
for internal status checks; client requests must supply signed transactions.
Production and Sandbox purchases are supported. Old unsigned receipt clients
must update. No Apple private signing certificate is committed to the repo.

Apple server notifications are not implemented in this change. iOS lifecycle
updates use the existing authenticated status reconciliation, cached up to 12
hours (paid expiry forces rechecking). Do not configure a nonexistent Apple
notification endpoint; immediate background refund/revocation handling remains
a separate backend capability.

## Device and staging acceptance tests

Run with Play internal testing/license testers and iOS TestFlight/Sandbox:

1. Buy Pro on a fresh profile; confirm its server entitlement and store
   acknowledgement, then reopen the app.
2. Uninstall, reinstall with the same store account, and create a new profile.
   Android Continue must offer restoration before checkout. iOS Restore must
   discover the existing subscription; an already-owned checkout must also
   offer restoration.
3. Cancel the restore prompt: neither profile changes and no new charge occurs.
4. Confirm: the current profile becomes Pro; the old profile loses only its
   store grant. Old profile data is not copied and the current user ID remains.
5. Delete the original account and repeat: no missing-profile error occurs.
6. Restore again on the current profile: success is idempotent.
7. Switch to a different store account: no subscription is found and checkout
   remains available. Use the original account to restore the purchase.
8. Check cancellation before expiry, expiry, refund/revocation, grace period,
   network failure, and pending payment. A failed verification must not
   acknowledge or grant the transaction.
9. Restore from two profiles concurrently in staging: the final subscription
   owner is unique, with no doubled store entitlement. Inject a database write
   failure and confirm neither side of the transfer commits.
10. Keep the old profile open on another device, refresh its authenticated
    status, and confirm its moved entitlement is revoked there too.

Automated tests use mocked stores/database transactions; real store and MongoDB
staging tests are still required before release.

## References

- [Google Play billing integration](https://developer.android.com/google/play/billing/integrate)
- [Apple transaction restoration](https://developer.apple.com/documentation/storekit/appstore/sync())
- [Apple SignedDataVerifier](https://apple.github.io/app-store-server-library-node/classes/SignedDataVerifier.html)
- [Apple public root certificates](https://www.apple.com/certificateauthority/)

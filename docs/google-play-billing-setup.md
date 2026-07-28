# Hamme Google Play subscription setup

This is the complete setup checklist for selling Hamme Pro through Google Play.

## Values already configured in the code

| Item | Value |
|---|---|
| Android package | `com.hamme.app` |
| Subscription product ID | `hamme_pro_weekly` |
| Suggested base plan ID | `weekly` |
| Purchase verification endpoint | `POST /api/v1/billing/verify` |
| Entitlement reconciliation endpoint | `GET /api/v1/billing/status` |
| Google RTDN push endpoint | `POST /api/v1/billing/google-play/rtdn` |

Do not create a different Play product ID unless the Flutter and backend product
IDs are changed at the same time.

## 1. Complete the Indian merchant verification

For an Indian Google Play merchant account, complete the BillDesk merchant KYC
before launching real subscriptions.

BillDesk verification is not only a bank-withdrawal requirement. Google states
that it is required to sell on Google Play and receive payouts under the RBI
Payment Aggregator Cross Border rules.

- Merchants who started monetizing on or after January 1, 2026 must complete
  BillDesk verification before real transactions can be processed.
- Merchants who were monetizing before December 31, 2025 currently have a
  verification deadline of August 31, 2026. Missing the deadline blocks new
  sales.

Look for an email from `onboarding@billdesk.com` with a subject similar to
**Verification required with BillDesk to receive payments on Google Play**.

Official guidance:

- [Account Verification, Taxes, and FIRC for sales in India](https://support.google.com/paymentscenter/answer/7421525?hl=en)
- [Create a Google Play payments profile](https://support.google.com/googleplay/android-developer/answer/7161426?hl=en)

BillDesk is not integrated into the Flutter application. Customers still pay
through the normal Google Play purchase screen.

## 2. Create the subscription in Play Console

Open:

**Play Console > Hamme > Monetize with Play > Products > Subscriptions**

Select **Create subscription** and enter:

```text
Product ID: hamme_pro_weekly
Name: Hamme Pro
```

Add accurate Pro benefits. Do not put a price or free-trial claim in the
benefits because not every user will necessarily receive the same offer.

Suggested benefits include:

```text
Unlimited card viewing
No card cooldown
Access to Pro features
```

Save the subscription.

Official guidance:

- [Create and manage subscriptions](https://support.google.com/googleplay/android-developer/answer/140504?hl=en)

## 3. Create and activate the weekly base plan

Under the `hamme_pro_weekly` subscription, select **Add base plan**.

Use:

```text
Base plan ID: weekly
Type: Auto-renewing
Billing period: Weekly
Price: Your intended weekly price
Countries/regions: Regions where Hamme is distributed
```

Recommended initial approach:

- Use one weekly base plan.
- Do not add a free trial or introductory offer until normal purchasing works.
- Enable a grace period.
- Keep the automatically calculated account-hold setting unless the business
  has a specific recovery policy.
- Activate the base plan after reviewing all regions and prices.

The subscription cannot be purchased until at least one base plan is active.

### Which fields can be changed later?

| Setting | Change later? | Notes |
|---|---:|---|
| Product ID | No | Treat `hamme_pro_weekly` as permanent. |
| Base plan ID | No | It cannot be changed or reused after activation. |
| Auto-renewing/prepaid type | No | Create another base plan to change type. |
| Weekly billing period | No | Create another base plan for monthly/yearly billing. |
| Price | Yes | New customers receive the new price. Existing customers may remain in a legacy price cohort. |
| Countries/regions | Yes | Removing a region prevents new purchases there. |
| Grace period | Yes | Controls how long paid access remains during payment recovery. |
| Account hold | Yes | Subject to Google’s permitted recovery-period rules. |
| Activation | Yes | A plan can be deactivated/reactivated. Existing subscribers are not immediately canceled by deactivation. |

If a monthly or annual plan is introduced later, update the Hamme purchase UI
to explicitly display and select the correct plan/offer.

Price-change guidance:

- [Understanding subscriptions and price changes](https://support.google.com/googleplay/android-developer/answer/12154973?hl=en)

## 4. Create the Google Play API service account

This service account is used only by the backend to verify purchases and
acknowledge initial subscriptions.

1. Open Google Cloud Console.
2. Create or select a Google Cloud project for Hamme.
3. Open **APIs & Services > Library**.
4. Enable **Google Play Android Developer API**.
5. Open **IAM & Admin > Service Accounts**.
6. Create a service account, for example:

   `hamme-play-billing`

7. Create and download a JSON key.
8. Open Play Console **Users and permissions**.
9. Invite the service-account email.
10. Give it access to the Hamme app.
11. Grant:

    - **View financial data, orders, and cancellation survey responses**
    - **Manage orders and subscriptions**

Official instructions:

- [Google Play Developer API setup](https://developers.google.com/android-publisher/getting_started)

The JSON key is a backend secret. Never put it in Flutter, the APK/AAB, source
control, a web frontend, screenshots, chat messages, or Play Store metadata.

## 5. Configure backend purchase-verification variables

Add the following variables to the deployed backend:

```env
PRO_PRODUCT_IDS=hamme_pro_weekly
ANDROID_PACKAGE_NAME=com.hamme.app
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
```

The JSON must normally be stored as a single-line environment variable. If the
hosting platform securely supports mounted secret files, this can be used
instead:

```env
GOOGLE_PLAY_SERVICE_ACCOUNT_FILE=/absolute/private/path/google-play-key.json
```

Use only one credential method.

There is intentionally no `ALLOW_UNVERIFIED_IAP` production bypass. If Google
verification is missing or unavailable, the backend will not grant paid Pro.

## 6. Configure Real-time Developer Notifications

Real-time Developer Notifications (RTDN) keep Hamme synchronized when a
subscription:

- Renews
- Is canceled
- Reaches its paid expiry
- Enters or leaves a grace period
- Enters account hold
- Recovers from a payment failure
- Is revoked
- Changes plan

### Create the Pub/Sub topic

1. Open Google Cloud Console.
2. Open **Pub/Sub > Topics**.
3. Create a topic, for example:

   `hamme-google-play-billing`

4. On the topic, grant **Pub/Sub Publisher** to:

   `google-play-developer-notifications@system.gserviceaccount.com`

### Connect the topic to Play Console

1. Open Play Console.
2. Open **Hamme > Monetize with Play > Monetization setup**.
3. Find **Real-time developer notifications**.
4. Enter the complete topic name:

   `projects/YOUR_PROJECT_ID/topics/hamme-google-play-billing`

5. Save it.
6. Use Play Console’s test-notification action.

### Create the authenticated push subscription

1. Open the Pub/Sub topic.
2. Create a subscription.
3. Select **Push** delivery.
4. Set the endpoint to:

   `https://YOUR_BACKEND/api/v1/billing/google-play/rtdn`

5. Enable authentication.
6. Select or create a push-authentication service account, for example:

   `hamme-pubsub-push@YOUR_PROJECT_ID.iam.gserviceaccount.com`

7. Set the OIDC audience to the exact endpoint:

   `https://YOUR_BACKEND/api/v1/billing/google-play/rtdn`

8. Configure these backend variables:

```env
GOOGLE_PLAY_RTDN_AUDIENCE=https://YOUR_BACKEND/api/v1/billing/google-play/rtdn
GOOGLE_PLAY_RTDN_SERVICE_ACCOUNT_EMAIL=hamme-pubsub-push@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

The audience, endpoint and environment value must match exactly, including
`https`, path and trailing-slash behavior.

The Hamme endpoint verifies Google’s signed OIDC token and rejects unsigned
requests or tokens issued for another audience/service account. Pub/Sub retries
non-successful requests, and notification processing is idempotent.

## 7. How Hamme stores Pro access

Hamme now separates complimentary access from paid access:

```text
isPro = adminPro OR storeProActive
```

- `adminPro`: Complimentary access controlled through the admin panel.
- `storeProActive`: Access backed by a verified Google Play subscription.
- `isPro`: Effective backward-compatible value consumed by the app.

Removing an admin grant does not remove an active paid subscription. Expiry or
cancellation of a paid subscription does not remove a separate admin grant.

The backend also stores:

- Verified product ID
- Purchase token
- Subscription state
- Paid expiry time
- Auto-renewal state
- Last verification time

Purchase tokens are unique, so the same Google purchase cannot activate
multiple Hamme accounts.

The Flutter purchase request sends the opaque Hamme user ID to Google as the
obfuscated account identifier. This helps the backend attribute an initial RTDN
even if it arrives before the app’s verification request.

### Entitlement decisions

| Google state | Hamme paid Pro |
|---|---:|
| Active with unexpired paid period | Yes |
| Grace period with unexpired paid period | Yes |
| Canceled but paid period not expired | Yes |
| Account hold | No |
| Paused | No |
| Pending purchase | No |
| Revoked | No |
| Expired | No |

The app reconciles entitlement with the backend on startup. The backend also
checks the stored expiry when enforcing unlimited card access, providing a
fallback if an RTDN is delayed.

## 8. Deploy the backend

Before testing purchases:

1. Deploy the updated backend code.
2. Add every required environment variable.
3. Confirm the normal health endpoint works.
4. Confirm the HTTPS RTDN endpoint is publicly reachable.
5. Do not expose the service-account JSON in deployment logs.
6. Restart/redeploy after changing environment variables.

Required billing variables:

```env
PRO_PRODUCT_IDS=hamme_pro_weekly
ANDROID_PACKAGE_NAME=com.hamme.app
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
GOOGLE_PLAY_RTDN_AUDIENCE=https://YOUR_BACKEND/api/v1/billing/google-play/rtdn
GOOGLE_PLAY_RTDN_SERVICE_ACCOUNT_EMAIL=hamme-pubsub-push@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

## 9. Build and upload the Android application

Increase the build number in `pubspec.yaml`, then run:

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

The generated bundle is normally located at:

```text
build/app/outputs/bundle/release/app-release.aab
```

Upload the AAB to Play Console’s **Internal testing** track.

## 10. Configure testers

1. Open Play Console **Settings > License testing**.
2. Add the Google accounts that will test billing.
3. Add the same accounts to the internal-testing tester list.
4. Publish the internal-test release.
5. Open the opt-in link using the tester’s Google account.
6. Install Hamme from Google Play—not from an unrelated APK.

The Google account that downloaded the app should be the license-test account.
License testers receive Google test payment methods and are not charged for test
purchases.

Official testing guidance:

- [Test Google Play Billing](https://developer.android.com/google/play/billing/test)

## 11. End-to-end test checklist

### Initial purchase

1. Sign into a normal Free Hamme account.
2. Confirm the admin panel displays `FREE`.
3. Open **Upgrade to Pro**.
4. Confirm the Play price and weekly billing period are displayed correctly.
5. Complete the purchase with a Google test payment method.
6. Confirm the app switches to Pro.
7. Confirm the admin panel displays `PRO · PLAY`.
8. Confirm unlimited-card behavior works.

### Restore

1. Sign out or reinstall the app.
2. Sign into the same Hamme account.
3. Use the same Google Play account.
4. Select **Restore Purchases**.
5. Confirm Pro is restored.

### Admin grant isolation

1. Give a Free user an admin Pro grant.
2. Confirm the panel displays `PRO · ADMIN`.
3. Remove the grant and confirm the user returns to Free.
4. Give a paid user an admin grant.
5. Confirm the panel displays `PRO · PLAY + ADMIN`.
6. Remove only the admin grant.
7. Confirm the paid subscription remains `PRO · PLAY`.

### Subscription lifecycle

Using Google’s accelerated license-testing periods, test:

- Renewal
- User cancellation
- Access until paid expiry after cancellation
- Grace period
- Payment recovery
- Account hold
- Revocation/refund
- Final expiry

After each event, confirm RTDN receives HTTP `204` and the Hamme user’s
entitlement matches the table above.

## 12. Common problems

### “Pro plan is not available”

Check:

- Product ID is exactly `hamme_pro_weekly`.
- The weekly base plan is active.
- The selected country/region is enabled.
- The app was installed through the Play testing link.
- The Play Store account is an authorized tester.
- Play Console changes have had time to propagate.

### “Purchase verification is not configured”

Check:

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` or
  `GOOGLE_PLAY_SERVICE_ACCOUNT_FILE` is configured.
- `ANDROID_PACKAGE_NAME` is exactly `com.hamme.app`.
- Google Play Android Developer API is enabled.
- The service account was invited to Play Console.
- Both required Play Console permissions were granted.

### RTDN returns 401

Check:

- Pub/Sub push authentication is enabled.
- The configured audience exactly matches
  `GOOGLE_PLAY_RTDN_AUDIENCE`.
- The push service-account email exactly matches
  `GOOGLE_PLAY_RTDN_SERVICE_ACCOUNT_EMAIL`.
- The endpoint uses HTTPS.

### RTDN returns 503

Check:

- All backend environment variables are deployed.
- The Google service-account JSON is valid.
- The service account still has Play Console access.
- The Android Publisher API is enabled.

### Purchase works but Pro does not activate

Check backend logs for:

- Product ID mismatch
- Purchase token already linked to another Hamme account
- Wrong Android package
- Inactive or expired subscription state
- Google API permission failure

Never solve a production verification failure by trusting the token supplied by
the phone or by enabling an unverified purchase bypass.

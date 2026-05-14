# prompts

So theres a premum plan purchasing and restoring option. i think this app planning to purchase through google play pay option. so tell me how it works , how restore works if we dont using any username and password like things. we only identifying device id i guess. or any other unique id. ?? analyze ethe project and tell me

So how the database and backend is working? I don't understand what we will store in our database. 

We store—if we not storing the device id, what we store? We store the Google account? Okay, you can store that. For—we storing that just for the payment and restore purpose, no other is related to that, right? 

Like we don't need to store their username and age and image details with that unique ID we creating for restoring the premium plan identification proposal.

The issue is that we are locking that premium with the customer, not user. Maybe that mobile or that Gmail; I don't know. If he uninstalls the app, we delete his user data. We don't remember his user data, but when he reinstalls our app and then looks for "restore purchase," then we need to restore that plan. 

But I don't know; we don't want our user data, but we want this payment data. So, how to do this? How do I explain this to my friend? Can you tell me? So we are connecting it with the Gmail account. If he reset his phone, this purchase plan cannot be...reconnect? Use device ID ? We can restore based on device ID. I don't know. You can decide.


Ok, then can you please implement this feature? And when the user  upgraded to Pro plan; maybe display it in-app anywhere "Pro" after successful purchase. 

Ok, so we need to test it before cluster release. So provide any option to manually test this inside the app, like any input box and we manually pasting some true/false value. I don't know, you can decide. We can remove it before going to production.


Yeah, you can implement those original features. Considering I am uploading this app to Play Store tomorrow, you can implement all the features now, but just provide an option for me to test locally. That's what I am asking, so please implement the feature in a really working state. Okay.

# Subscription Feature Notes

## Purpose
This document captures everything implemented and discussed for the Pro subscription feature, including architecture, backend + app changes, testing strategy, and launch notes.

## Conversation Summary (Product Decisions)
- Premium should be restorable after uninstall/reinstall.
- Premium should not depend on app profile data (username/age/image).
- Premium identity should not depend on device ID.
- Premium should be tied to Google Play purchase ownership (Google account + purchase token verification).
- Real end-to-end billing validation requires Play distribution via Internal/Closed/Open testing track.
- Keep a local debug way to test before/without full Play billing.

## Key Clarifications From Discussion
- Restore is based on Google Play account ownership, not device ID.
- If user resets/changing phone, restore still works with same Google account.
- If user uses different Google account, restore should not work (expected).
- Public release is not required for testing, but Play test track is required for real purchase flow.

## Current Implementation Scope
Implemented both:
1. Production-style flow (purchase token verification via backend).
2. Local development test options (debug override + backend mock verification).

## Flutter App Changes

### Dependency
- Added `in_app_purchase` in `pubspec.yaml`.

### Premium State and Billing Orchestration
File:
- `lib/providers/premium_providers.dart`

What it does:
- Checks Play store availability.
- Loads product details for product id: `hamme_pro_weekly`.
- Starts purchase flow (`buyNonConsumable`).
- Restores purchases (`restorePurchases`).
- Listens to purchase stream.
- On purchase/restore event, sends token to backend: `POST /billing/verify/android`.
- Fetches backend entitlement on startup/refresh: `GET /billing/entitlement`.
- Persists local cache (`premium_active`) for resilience.
- Supports debug manual override (true/false/clear).
- Supports debug backend mock verification buttons.

### Pro Screen
File:
- `lib/features/onboarding/presentation/screens/pro_screen.dart`

Added:
- `Subscribe via Google Play` action.
- `Restore Purchases` action.
- Entitlement status messaging.
- Debug-only panel (`kDebugMode`) with:
  - Text input: `true`, `false`, `clear` for manual PRO override.
  - Buttons: `Mock Backend PRO` / `Mock Backend OFF`.
- Footer `Restore` is now clickable and triggers restore.

### In-App PRO Indicator
Files:
- `lib/features/shared/presentation/widgets/hamme_top_bar.dart`
- `lib/features/home/presentation/screens/home_screen.dart`

Added:
- `isPro` prop in top bar.
- Visible `PRO` badge in top bar when entitlement is active.

## Backend Changes

### New Billing Entitlement Model
File:
- `backend/src/models/BillingEntitlement.js`

Stored fields:
- `userId`
- `platform` (`android`)
- `productId`
- `purchaseToken` (unique)
- `orderId`
- `status` (`active`, `grace`, `hold`, `paused`, `canceled`, `expired`, `inactive`)
- `isAutoRenewing`
- `expiryTime`
- `lastVerifiedAt`
- `verificationPayload`
- `source`

### Billing Service
File:
- `backend/src/services/billingService.js`

Responsibilities:
- Verify Android subscription token against Google Play Developer API (`subscriptionsv2.get`).
- Map Google subscription state -> app entitlement state.
- Upsert entitlement record by `purchaseToken`.
- Compute active entitlement by user for app consumption.
- Support `BILLING_MOCK_MODE=true` for local backend mock verification.

### New Controller + Routes
Files:
- `backend/src/controllers/billingController.js`
- `backend/src/routes/billingRoutes.js`
- `backend/src/routes/index.js` (mounted route)

Endpoints:
- `GET /api/v1/billing/entitlement`
- `POST /api/v1/billing/verify/android`
  - body: `{ "purchaseToken": "..." }`
- `POST /api/v1/billing/restore/android`
  - body: `{ "purchaseTokens": ["...", "..."] }`

### Env Config Additions
File:
- `backend/src/config/env.js`

Variables:
- `GOOGLE_PLAY_PACKAGE_NAME`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY`
- `BILLING_MOCK_MODE`

## Google Play Integration Notes
- Verification endpoint used: `purchases.subscriptionsv2.get`.
- Package name must match Play Console app package.
- Service account must have Play Android Publisher access.
- Private key should preserve newlines (`\n` in env, converted server-side).

## Local Development Testing

### Option A: Manual UI Override (No backend dependency)
In Pro screen debug panel:
- `true` => force PRO on
- `false` => force PRO off
- `clear` => clear override, revert to real entitlement/cache

### Option B: Backend Mock Verification Path
Set backend env:
- `BILLING_MOCK_MODE=true`

Then in Pro screen debug panel:
- `Mock Backend PRO` => verifies mock active token via backend and sets entitlement active.
- `Mock Backend OFF` => verifies mock inactive token via backend and sets entitlement inactive.

This tests the full app->backend entitlement flow without real Play purchase.

## Real Billing Testing (Required Before Launch)
- Use Play Console Internal Testing track.
- Add subscription product with exact product id used by app (`hamme_pro_weekly`) or update app constant.
- Add tester Gmail accounts.
- Install app from Play test link.
- Verify:
  - purchase success
  - restore after reinstall
  - entitlement fetch on fresh login/session
  - PRO badge visibility

## Release Checklist
1. Confirm product ID matches Play Console exactly.
2. Set production env values for Play verification.
3. Set `BILLING_MOCK_MODE=false` in production.
4. Ensure service account has correct Play Console/API access.
5. Test on Internal track using tester accounts.
6. Verify restore works after uninstall/reinstall with same Google account.
7. Confirm debug-only controls are not exposed in release (`kDebugMode` guards applied).

## Known Gaps / Follow-Ups
- Current restore endpoint accepts purchase tokens from client. This works, but webhook-based lifecycle sync (RTDN) is recommended later for robust renewal/cancellation handling.
- iOS subscription flow not implemented in this feature (Android focus only).
- Product id currently hardcoded in provider; move to config if multiple plans are needed.

## File Change Index
- `pubspec.yaml`
- `lib/providers/premium_providers.dart`
- `lib/features/onboarding/presentation/screens/pro_screen.dart`
- `lib/features/shared/presentation/widgets/hamme_top_bar.dart`
- `lib/features/home/presentation/screens/home_screen.dart`
- `backend/src/models/BillingEntitlement.js`
- `backend/src/services/billingService.js`
- `backend/src/controllers/billingController.js`
- `backend/src/routes/billingRoutes.js`
- `backend/src/routes/index.js`
- `backend/src/config/env.js`

## Why This Design
- Device ID based restore is fragile.
- Google Play account ownership is the reliable restore anchor.
- Backend verification is needed for trust and fraud resistance.
- Debug override + mock backend mode gives fast local QA before Play track testing.

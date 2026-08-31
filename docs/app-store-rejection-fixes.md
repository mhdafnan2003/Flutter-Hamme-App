# App Store rejection fixes (Hamme 1.0)

Apple rejected **version 1.0 (13)** on **4 August 2026**. Submission ID: `c1c6464d-b999-4b48-ba50-769c161169de`. Review devices: **iPad Air 11-inch (M3)** and **iPhone 17 Pro Max** (iOS 26.6).

That binary is outdated. Ship a **new build** (for example **1.0 (14)**) after the items below are done. Reply in App Store Connect with what changed, and attach the account-deletion screen recording.

---

## 1. Guideline 2.3.8 — Accurate metadata (placeholder icons)

**What Apple said:** The app or its metadata does not appear to include final content. Specifically, the app icons appear to be placeholder icons.

**Why:** Build 13 almost certainly used the Flutter bird in App Store Connect. The current iOS icon (purple background + the word “Hamme”) is better, but Apple often still treats a word-only, flat-color icon as unfinished.

**Do this:**

- Design a real mark (monogram or symbol), not only the word “Hamme”.
- Use the **same** 1024×1024 icon (no transparency / no alpha) in:
  - `ios/Runner/Assets.xcassets/AppIcon.appiconset`
  - App Store Connect → **App Information** → app icon
- Home-screen name must stay **Hamme**.
- Rebuild so reviewers install that icon, not Flutter.

After generating icons from `assets/hamme_app_icon.png`, confirm App Store Connect is not still showing the Flutter logo.

---

## 2. Guideline 2.1(b) — App completeness (could not purchase)

**What Apple said:** The In-App Purchase products exhibited bugs. They were unable to purchase the IAP in sandbox. They also noted that the Account Holder must accept the **Paid Apps Agreement**.

**Why:** Sandbox purchase fails while **Paid Apps** is **Pending User Info** (bank + tax incomplete).

**Do this:**

- App Store Connect → **Business** → complete bank account and tax forms until **Paid Apps Agreement** is **Active**.
- Create/finish the subscription product **`hamme_pro_weekly`** (price, localization, review screenshot of the paywall).
- Test on a **real iPhone and iPad** (they used both): Sandbox Apple ID → Unlock Unlimited Access → subscribe must complete with no error.
- In **App Review Information** notes, include:
  - Sandbox Apple ID + password
  - Hamme demo login
  - Steps: open app → Unlock Unlimited Access → subscribe

Do not resubmit until a sandbox purchase succeeds on device.

---

## 3. Guideline 2.1(b) — IAP products not submitted

**What Apple said:** One or more IAP products have not been submitted for review. Submit the products, provide an App Review screenshot for the IAP, and upload a **new binary**.

**Do this:**

- Subscriptions → `hamme_pro_weekly` → **Submit for Review** (requires the IAP review screenshot).
- Version **1.0** → **In-App Purchases and Subscriptions** → add `hamme_pro_weekly`.
- Upload a **new** build. Old **1.0 (13)** cannot pick this up.

Product ID in code and App Store Connect must stay **`hamme_pro_weekly`**.

---

## 4. Guideline 5.1.1(v) — Account deletion

**What Apple said:** The app supports account creation but had no way to initiate account deletion. Temporary deactivation is not enough. They want a **screen recording on a physical device** of the full delete flow.

**Current app (not in build 13):** Profile → **Settings** → **Delete account**. That calls `DELETE /profiles/me` and permanently removes the account.

**Do this:**

- Include that flow in the new binary.
- On a physical iPhone, record:
  1. Create a new account **or** sign in with the demo account
  2. Navigate to **Settings → Delete account**
  3. Confirm deletion through to success
- Put the video in **App Review Information → Notes**.
- Reply in Resolution Center with that recording.

---

## Resubmit order

1. Paid Apps Agreement → **Active**.
2. Submit `hamme_pro_weekly` for review and attach it to version 1.0.
3. Final icon in the **binary** and in **App Store Connect**.
4. New build that includes **Delete account**.
5. Bump build number (for example **14**), archive, upload.
6. Reply to App Review: icons replaced, IAP submitted and sandbox-tested, deletion recording attached.

Until Paid Apps is Active, purchase review (items 2 and 3) will fail again even if the Flutter billing code is correct.

---

## Review notes template

Paste into App Review Information / Resolution Center:

```text
Thank you for the review.

1. Icons: Replaced placeholder/Flutter icons with the final Hamme app icon in the binary and in App Store Connect.

2. In-App Purchase: Paid Apps Agreement is Active. Subscription hamme_pro_weekly is submitted for review and attached to this version. Sandbox purchase was tested on iPhone and iPad.

Demo account: [email] / [password]
Sandbox Apple ID: [id] / [password]
Path: Unlock Unlimited Access → subscribe (weekly Pro).

3. Account deletion: Settings → Delete account (permanent). Screen recording of sign-in through confirmed deletion is attached in Notes.
```

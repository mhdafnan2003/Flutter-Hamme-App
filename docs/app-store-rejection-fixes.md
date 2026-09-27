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

---

# Guideline 1.2 — Safety: user-generated content (rejection of 24 September 2026)

**What Apple said:** The app lets users post content anonymously but does not have the proper precautions. Apple asked for all of the following: an 18+ age rating, a required EULA with zero tolerance for objectionable content, content filtering, flagging, blocking, immediate removal from the feed, acting on reports within 24 hours, and in-app contact information.

**Why:** Anonymous web votes showed up in the Play queue with **no report button**. The flag icon was hidden on anonymous cards, and the backend refused to report anonymous votes. There was also no required terms agreement, no filter on names or handles, and no contact information in the app.

## What changed

| Apple requirement | Where it is now |
|---|---|
| Agree to terms (EULA) with zero tolerance | Required **Community rules** agreement (checkbox + "I agree") before the account is created. Existing users see a blocking agreement screen on next launch. Acceptance is stored server-side (`termsAcceptedAt`, `termsVersion`). |
| Filter objectionable content | Votes are fixed choices (friend / crush / frenemy), so there is no free text. Names, usernames and Instagram/Snapchat handles are checked by a profanity filter in the app and enforced on the server (`OBJECTIONABLE_CONTENT`). |
| Flag objectionable content | Flag button on **every** vote card in Play, anonymous ones included, plus a **•••** menu on every match (Matches list and match screen) → Report → reason → optional details. |
| Block abusive users | Report has "Also block" on by default, and there is a separate **Block** action. Blocking works both ways and covers anonymous voters (by browser session). Settings → **Blocked users** to unblock. |
| Remove content from the feed immediately | **Hide this vote**, Report and Block all remove the card at once, before the network call finishes. |
| Act on reports within 24 hours | Admin panel (`/api/v1/admin`) shows the report queue with **Overdue** (>24h) flags. **Remove & ban** deletes the content and bans the account (or the anonymous voter's session). An optional `MODERATION_WEBHOOK_URL` sends every new report to Slack/Discord. |
| Contact info in the app | Settings → **Safety & support**: Community Guidelines, Contact us, Report a safety concern (`support@hamme.app`). |
| Age rating | Set in App Store Connect (see below). |

## Before resubmitting

1. **Deploy the backend first.** The new app build calls the new endpoints. Optional env vars: `MODERATION_WEBHOOK_URL`, `CLOUDINARY_MODERATION`.
2. **Deploy the web client** (updated Terms of Service, the new `/community-guidelines` page, the report link on the poll page). `client/hamme-terms-of-service.pdf` is out of date. Regenerate it if you publish it anywhere.
3. **Age rating:** App Store Connect → App Information → Age Rating. Answer "Yes" to user-generated content / messaging. Apple's message asks for **18+**. You can ask to keep 13+ in the reply (below), but if they insist, switch to 18+.
4. **Staff the queue:** someone checks the admin panel (or the webhook channel) at least daily and acts on every report within 24 hours. Apple can test this.
5. Bump the build number, archive, upload.
6. Record a short screen video on a physical iPhone: agreement screen at signup → flag on an anonymous vote → report with block → card disappears → Settings → Blocked users → Safety & support.

## Review reply template (Guideline 1.2)

```text
Thank you for the review. We added the following precautions for user-generated content in this build:

1. Terms (EULA): New users must agree to the Terms of Use and Community Guidelines (checkbox + "I agree") before an account is created. The terms state that Hamme has zero tolerance for objectionable content or abusive users. Existing users must accept them on their next launch.
2. Filtering: Votes are fixed choices (friend / crush / frenemy); there is no free-text posting. Names, usernames and social handles are checked by a profanity filter in the app and on our server, and objectionable ones are rejected.
3. Flagging: Every vote card, anonymous ones included, has a flag button (Report → choose a reason). Every match has the same options in its "•••" menu.
4. Blocking: Reporting blocks the sender by default, and there is a separate Block action. Blocking also works for anonymous voters. Blocked users can be managed in Settings → Blocked users.
5. Immediate removal: "Hide this vote", Report and Block remove the content from the feed immediately.
6. 24-hour moderation: Every report goes to our moderation queue and alerts our team. We review reports within 24 hours, remove offending content, and ban the user who posted it.
7. Contact: Settings → Safety & support has "Contact us" and "Report a safety concern" (support@hamme.app), plus in-app Community Guidelines.

A screen recording of these flows is attached. The app contains no free-text user content and all voting options are pre-written by us, so we would like to keep the 13+ rating. If Apple still requires 18+, we will update the rating.
```

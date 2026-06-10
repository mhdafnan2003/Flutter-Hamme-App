# Hamme — Post-Deployment Test Cases

Manual test checklist covering every issue discussed and fixed. Run these against
the **deployed backend** and a **rebuilt app** (the fixes are backend + Flutter
source changes, so an old deployment will still show the old behavior).

Legend: ✅ = expected pass, ⛔ = expected blocked/rejected.

---

## 0. Pre-flight

- [ ] Backend redeployed with latest `backend/src` changes.
- [ ] App rebuilt from latest `lib` changes and installed.
- [ ] `PENDING_TTL_SECONDS=60` (or your chosen value ≥ 30) set in backend env.
- [ ] MongoDB indexes synced (the new TTL index on `PendingInteraction.expiresAt`
      builds automatically if `autoIndex` is on; otherwise run
      `PendingInteraction.syncIndexes()` once).

---

## 1. Reveal / Play-card expiry (core flow)

This is the main flow: web poll → reveal button (60s) → install/sign up → Play card.

### TC-1.1 — Reveal within 60s creates a Play card ✅
1. As Creator C, share the profile/poll link.
2. As Responder R (web), open the link and pick a type (Crush/Friend/Frenemy).
3. The "Reveal" button appears with a ~60s countdown.
4. Tap **Reveal** before the countdown ends; install/open the app; sign up as R.
5. **Expected:** R lands in the app; on C's phone the reaction shows as a **Play card**.

### TC-1.2 — Reveal after 60s: no Play card, app still installs ⛔card / ✅install
1. Repeat steps 1–3 above.
2. Wait until the countdown reaches 0 / link shows expired.
3. Tap **Reveal** (or open the deep link) after expiry; install/open the app; sign up.
4. **Expected:**
   - R can still **install and sign up** through the link.
   - An "expired" message is shown.
   - **No Play card** appears on C's phone.
   - Nothing new appears in C's inbox for this expired reaction.

### TC-1.3 — Expired reveal does NOT silently create an interaction (regression) ⛔
This is the exact bug that was fixed (share-code fallback firing after token expiry).
1. Trigger TC-1.2 (reveal after 60s).
2. **Expected:** after seeing "expired", confirm via C's Play tab AND inbox that
   **no** card/entry was created a few seconds later. (Previously a card appeared
   right after the expired message.)

### TC-1.4 — Reveal link used twice ⛔
1. Complete TC-1.1 successfully (link finalized once).
2. Re-open the same reveal deep link / tap reveal again.
3. **Expected:** "This reveal link has already been used." No duplicate Play card.

### TC-1.5 — Reveal of your own link ⛔
1. As Creator C, open your own reveal link and try to finalize as C.
2. **Expected:** "You can't reveal or respond to your own link." No card created.

### TC-1.6 — Pending lookup endpoint respects status/expiry
1. Create a pending (submit a web poll response).
2. `GET /api/v1/interactions/pending/:token` before 60s → ✅ returns target info.
3. After 60s (or after it is finalized) → ⛔ returns expired / already-used error,
   not the target's name/photo.

---

## 2. Matching logic

### TC-2.1 — Mutual same-type = match ✅
1. User A reacts to User B with `crush` (revealed in time).
2. User B reacts to User A with `crush`.
3. **Expected:** both see an "It's a Match!" result; match appears in matches list.

### TC-2.2 — Mismatched types = no match
1. A → B `crush`, B → A `friend`.
2. **Expected:** no match; both interactions still recorded.

### TC-2.3 — Matches list shows only last 24h (intended)
1. Create a match.
2. **Expected:** it appears in the matches list now.
3. (Known/intended) After 24h it drops off the matches list. This is by design.

### TC-2.4 — Duplicate interaction blocked ⛔
1. A reacts to B with `crush` and finalizes.
2. A tries to react to B again with `crush`.
3. **Expected:** "This interaction has already been sent." (HTTP 409), no crash.

### TC-2.5 — Finalize when sender already reacted to target (duplicate-key path) ✅ no 500
1. A already has a `crush` interaction to B.
2. A opens a (valid, in-time) reveal link for another `crush` reaction to B and finalizes.
3. **Expected:** no 500 error; the reveal link is not left permanently stuck; the
   flow resolves cleanly (existing interaction kept, redundant one dropped).

---

## 3. Interaction type cleanup (`frenemy` only, `ameny` removed)

### TC-3.1 — Frenemy end-to-end ✅
1. React with **Frenemy** via web and finalize.
2. **Expected:** stored/displayed as `frenemy`; Play card, match overlay, and share
   export all show Frenemy theming correctly.

### TC-3.2 — Legacy `ameny` tolerance ✅
1. (If any legacy client/data sends `ameny`) submit a reaction with type `ameny`.
2. **Expected:** backend normalizes it to `frenemy`; no validation error; app renders
   it as Frenemy.

### TC-3.3 — Invalid type ⛔
1. Send an interaction with `type` = something random (e.g., `lover`).
2. **Expected:** 400 "Invalid interaction type."

---

## 4. Anonymous-response spam / rate limiting

### TC-4.1 — Rate limit on anonymous responses ⛔
1. From one client/IP, hit `POST /api/v1/anonymous-response` more than 10 times in 1 minute.
2. **Expected:** after the limit, requests return 429 "Too many responses…".

### TC-4.2 — Duplicate anonymous response with same session ⛔
1. Submit an anonymous response with a `sessionId`.
2. Re-submit the same `sessionId` + type to the same target within the window.
3. **Expected:** "This interaction has already been sent." (409)

---

## 5. Pending interaction lifecycle / cleanup

### TC-5.1 — Pending auto-expires (TTL)
1. Create a pending (web poll response).
2. Wait > 60s (TTL background removal can lag up to ~60s).
3. **Expected:** the `pendinginteractions` document is removed automatically; no
   `setTimeout` log/crash; `backend/debug_expiry.log` is NOT recreated.

### TC-5.2 — No orphan reactions before reveal
1. Submit a web poll response but never reveal.
2. **Expected:** C sees no Play card and no inbox entry for that reaction
   (reaction is created only on successful finalize).

---

## 6. Auth & security (from first review — verify after secrets rotation)

### TC-6.1 — JWT secrets are real, not defaults ✅
1. Confirm deployed env has strong `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET`
   (NOT `change-me-...`).
2. A token signed with the old default secret must be rejected.

### TC-6.2 — Rotated DB / Cloudinary credentials ✅
1. Confirm the MongoDB and Cloudinary credentials committed earlier have been
   rotated and the old ones no longer work.

### TC-6.3 — Login / signup happy path ✅
1. Sign up, log out, log back in, restore session, fetch current user.
2. **Expected:** all succeed; tokens issued; refresh rotates correctly.

### TC-6.4 — Refresh token rotation ✅
1. Call refresh with a valid refresh token.
2. **Expected:** new tokens issued; the old refresh token no longer works.

### TC-6.5 — 500 errors don't leak internals
1. Trigger an unexpected server error (if reproducible).
2. **Expected:** generic message to client; details only in server logs.
   (Note: this hardening was recommended but confirm it's applied.)

### TC-6.6 — Public profile hides email ✅
1. `GET /api/v1/profiles/public/:shareCode`.
2. **Expected:** response contains name/username/instagram/shareCode/image, and
   does **not** include an email field.

---

## 7. Upload / media

### TC-7.1 — Profile image upload via Cloudinary ✅
1. Upload a profile image through the app.
2. **Expected:** returns a Cloudinary `secure_url`; image displays.

### TC-7.2 — Upload without Cloudinary configured ⛔
1. With Cloudinary env missing, attempt upload.
2. **Expected:** 500 "Cloudinary is not configured." (no local-disk write expected
   on serverless).

---

## 8. Deep links / install referrer

### TC-8.1 — `hamme://open?token=...&code=...&type=...` uses token only ✅
1. Open a deep link containing token + code + type.
2. **Expected:** only the reveal/finalize path runs; no separate share-code send.

### TC-8.2 — Raw profile link opens app, no auto-reaction ✅
1. Open `https://app.hamme.link/u/<code>` (no token).
2. **Expected:** app opens / installs; **no** interaction is auto-created.

### TC-8.3 — Android install referrer
1. Install via Play Store using a referrer carrying `hamme_token` (within 60s).
2. **Expected:** after sign up, finalize runs once; Play card created (if in time)
   or expired with no card (if late) — same as TC-1.1 / TC-1.2.

---

## Notes / Known-by-design
- Matches list intentionally shows only the last 24 hours (TC-2.3).
- After the up-front-reaction change, reactions exist only after a successful
  in-time reveal; un-revealed reactions never appear anywhere.
- Socket.IO match notifications are scaffolded and disabled on Vercel; not covered here.

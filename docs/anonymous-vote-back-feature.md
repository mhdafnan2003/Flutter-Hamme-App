# Anonymous Vote-Back Feature

## Overview

This feature controls how the app handles a poll vote from someone who has not installed Hamme or created a Hamme account.

The implementation supports two modes through one backend environment variable:

| Flag value | Behavior |
| --- | --- |
| `false` | The anonymous vote increases reaction counts only. It does not create a Play card, cannot be answered by the creator, and does not appear in the match list. |
| `true` | The creator receives a blurred anonymous Play card, can vote back, and sees a blurred anonymous match when both choices are the same. |

The safe default is `false`.

## Feature flag

```env
ANONYMOUS_VOTE_BACK_ENABLED=false
```

The flag is read by the backend. It is intentionally not a Flutter-only flag because the backend must prevent disabled clients or manually constructed API requests from creating anonymous vote-backs.

### Enable locally

Add this to `backend/.env` and restart the backend:

```env
ANONYMOUS_VOTE_BACK_ENABLED=true
```

### Enable in a hosted environment

Set `ANONYMOUS_VOTE_BACK_ENABLED=true` in the backend project's environment variables and redeploy the backend. No separate Flutter build is required if the app version containing this feature is already installed.

Set the value back to `false` and redeploy to return to count-only behavior.

## Behavior when disabled

1. The web voter selects Friend, Crush, or Frenemy.
2. The backend stores an `Interaction` with `fromUser: null` so the vote remains countable.
3. The received-interactions response marks anonymous vote-back as disabled.
4. Flutter excludes the interaction from the actionable Play queue.
5. The backend rejects direct anonymous vote-back requests with HTTP `403`.
6. Previously created anonymous matches are omitted from the match response.

Anonymous records are not deleted when the flag is disabled. This makes switching reversible.

## Behavior when enabled

1. The anonymous vote remains stored with `fromUser: null` and `metadata.anonymous: true`.
2. The backend adds `metadata.anonymousVoteBackEnabled: true` to the creator's received-interaction response.
3. Flutter includes the interaction in the Play queue.
4. The card renders a deliberately blurred placeholder avatar and username because a real profile does not exist yet.
5. The creator answers the card using the anonymous interaction ID rather than a user ID.
6. The backend stores the creator's choice in the interaction metadata.
7. If the choices match, the backend returns a synthetic anonymous match and the UI shows a blurred match-success view and match-list row.
8. Anonymous match rows have no Instagram or Snapchat action because there is no account to open.

## Match rules

An anonymous match occurs only when the creator chooses the same option as the anonymous voter:

```text
anonymous choice == creator choice -> blurred anonymous match
anonymous choice != creator choice -> not a match
```

The response update is atomic. Repeated or concurrent attempts cannot overwrite the creator's first answer.

Anonymous matches follow the existing 24-hour match visibility window.

## When the anonymous voter later creates an account

If the voter completes the existing Reveal/install flow before its pending token expires:

1. The anonymous interaction is attributed to the newly created user.
2. The creator's earlier anonymous vote-back is converted into a normal reciprocal interaction.
3. A same-choice anonymous match becomes a normal account-to-account match.
4. The synthetic anonymous match disappears because its interaction now has a real `fromUser`.

This prevents the creator from having to answer the same person twice.

If the Reveal token has expired, the vote remains permanently anonymous.

## Data stored on anonymous responses

The implementation uses the existing `Interaction.metadata` field rather than introducing a database migration.

Relevant fields include:

```json
{
  "anonymous": true,
  "creatorResponseType": "friend",
  "creatorRespondedAt": "2026-08-18T00:00:00.000Z",
  "anonymousMatched": true
}
```

`pendingToken` and browser `sessionId` values are removed from the creator-facing API response. They remain private to the voter flow.

## API behavior

The existing authenticated endpoint is used for both registered and anonymous responses:

```http
POST /api/v1/interactions/respond
```

Registered response body:

```json
{
  "targetUserId": "USER_OBJECT_ID",
  "type": "friend"
}
```

Anonymous response body:

```json
{
  "interactionId": "INTERACTION_OBJECT_ID",
  "type": "friend"
}
```

Exactly one of `targetUserId` or `interactionId` is required. Both IDs are validated as MongoDB object IDs.

## Main implementation files

### Backend

- `backend/src/config/env.js` — parses the feature flag.
- `backend/src/services/interactionService.js` — enforces the flag, records anonymous answers, creates synthetic matches, protects voter tokens, and upgrades anonymous interactions after registration.
- `backend/src/controllers/interactionController.js` — routes anonymous interaction-ID responses to the service.
- `backend/src/routes/interactionRoutes.js` — validates registered and anonymous response targets.
- `backend/.env.example` — documents the default environment value.

### Flutter

- `lib/providers/interaction_providers.dart` — includes anonymous interactions only when the server enables vote-back.
- `lib/features/play/presentation/screens/play_screen.dart` — submits answers by interaction ID and displays the blurred card.
- `lib/features/play/presentation/widgets/match_success_overlay.dart` — displays the blurred anonymous match result and removes social reply controls.
- `lib/features/matches/presentation/screens/matches_screen.dart` — displays blurred anonymous match rows without social links.
- `lib/models/match_record.dart` — identifies anonymous matches.
- `lib/features/interactions/` repository and data-source files — carry either a user ID or interaction ID to the API.

Generated Freezed and JSON serialization files were regenerated after the match model changed.

## Testing

Run the Flutter tests:

```powershell
flutter test
```

Run backend syntax checks:

```powershell
node --check backend/src/config/env.js
node --check backend/src/controllers/interactionController.js
node --check backend/src/routes/interactionRoutes.js
node --check backend/src/services/interactionService.js
```

The dedicated tests in `test/anonymous_vote_back_test.dart` verify:

- Disabled anonymous votes stay out of the Play queue.
- Enabled anonymous votes enter the Play queue.
- Answered anonymous votes leave the Play queue.
- Anonymous match metadata is decoded correctly.

## Manual verification checklist

### Flag disabled

- Submit a web vote without installing or registering.
- Confirm the reaction count increases.
- Confirm no anonymous Play card appears.
- Confirm the creator cannot answer the interaction through the API.
- Confirm no anonymous match row appears.

### Flag enabled

- Submit a web vote without installing or registering.
- Confirm a blurred Play card appears.
- Select a different option and confirm the not-a-match result.
- Submit another anonymous vote and select the same option.
- Confirm the blurred match-success screen appears.
- Confirm a blurred, non-clickable row appears in the match list.
- Disable the flag and confirm anonymous cards and matches disappear while counts remain.
- Re-enable the flag and confirm still-valid anonymous data is available again.

## Branch and commits

The feature was developed on:

```text
feature/anonymous-vote-back
```

Main implementation commit:

```text
bdc70fc feat: add flagged anonymous vote-back flow
```

## Rollback

The preferred operational rollback is:

```env
ANONYMOUS_VOTE_BACK_ENABLED=false
```

Then redeploy the backend. This blocks new anonymous vote-backs and hides anonymous cards and matches without deleting stored votes.

A source-code revert is unnecessary for ordinary on/off switching.

const Interaction = require('../models/Interaction');
const Match = require('../models/Match');
const User = require('../models/User');
const PendingInteraction = require('../models/PendingInteraction');
const ApiError = require('../utils/ApiError');
const { voteBlockedError } = require('../utils/safety');
const crypto = require('crypto');
const appConfigService = require('./appConfigService');
const blockService = require('./blockService');
const pushService = require('./pushService');
const env = require('../config/env');

const allowedTypes = new Set(['friend', 'crush', 'frenemy']);
const pendingTtlSecondsRaw = Number(process.env.PENDING_TTL_SECONDS || 180);
const pendingTtlSeconds = Number.isFinite(pendingTtlSecondsRaw)
  ? Math.max(30, pendingTtlSecondsRaw)
  : 60;
const PENDING_TTL_MS = pendingTtlSeconds * 1000;
const REVEAL_EXTEND_MS = 5 * 60 * 1000; // 5 min grace after user taps Reveal
const VISIBLE_MATCH_WINDOW_MS = 24 * 60 * 60 * 1000;
const INTERACTION_COOLDOWN_MS = 24 * 60 * 60 * 1000;
const MAX_CLIENT_CLOCK_SKEW_MS = 24 * 60 * 60 * 1000;
const PENDING_TOKEN_PATTERN = /^[a-f0-9]{32}$/;
// The web client hands the voter a reveal token before its create request
// finishes, so the app can ask about a token that is still being written.
const PENDING_LOOKUP_WAIT_MS = 6000;
const PENDING_LOOKUP_POLL_MS = 300;

async function assertInteractionCooldownElapsed(fromUserId, targetUserId) {
  const cutoff = new Date(Date.now() - INTERACTION_COOLDOWN_MS);
  const recentInteraction = await Interaction.findOne({
    fromUser: fromUserId,
    toUser: targetUserId,
    createdAt: { $gte: cutoff },
  })
    .sort({ createdAt: -1 })
    .select('createdAt');

  if (!recentInteraction) return;

  const retryAt = new Date(
    recentInteraction.createdAt.getTime() + INTERACTION_COOLDOWN_MS
  );
  throw new ApiError(
    409,
    'You can interact with this user again after 24 hours.',
    { retryAt }
  );
}

// A block works both ways for voting: neither user can vote for, respond to or
// match with the other. `targetUser` must include blockedUsers.
async function assertUsersCanInteract(fromUserId, targetUser) {
  const targetBlockedSender = (targetUser.blockedUsers || []).some(
    (blockedId) => blockedId.toString() === fromUserId.toString()
  );
  const senderBlockedTarget =
    targetBlockedSender ||
    (await User.exists({
      _id: fromUserId,
      blockedUsers: targetUser._id,
    }));
  if (targetBlockedSender || senderBlockedTarget) {
    throw voteBlockedError();
  }
}

function buildCanonicalPair(firstUserId, secondUserId) {
  const [userA, userB] = [firstUserId.toString(), secondUserId.toString()].sort();
  return { userA, userB };
}

// Query conditions for votes their recipient may see: not hidden (or reported)
// by them and not from a web session they blocked. `$nin` keeps votes that
// have no sessionId at all.
function visibleToRecipientFilter(blockedVoterSessions = []) {
  return {
    hiddenByRecipientAt: null,
    ...(blockedVoterSessions.length
      ? { 'metadata.sessionId': { $nin: blockedVoterSessions } }
      : {}),
  };
}

function normalizeType(type) {
  const normalized = (type || '').toString().trim().toLowerCase();
  // Legacy clients may still send 'ameny'; treat it as 'frenemy'.
  const canonical = normalized === 'ameny' ? 'frenemy' : normalized;
  if (!allowedTypes.has(canonical)) {
    throw new ApiError(400, 'Invalid interaction type.');
  }
  return canonical;
}

// Fields of the other person that a match needs (the app card and the push).
const MATCHED_USER_FIELDS = 'name username instagramId snapchatId profileImageUrl shareCode isPro';

// Only what the app renders. Never expose another user's email, device or
// billing fields (the full toJSON() used to be sent).
function serializeMatchedUser(user) {
  return {
    id: user._id.toString(),
    name: user.name,
    username: user.username || null,
    email: '',
    instagramId: user.instagramId || '',
    snapchatId: user.snapchatId || '',
    avatarUrl: user.profileImageUrl || null,
    shareCode: user.shareCode,
    isPro: Boolean(user.isPro),
  };
}

function serializeMatch(match, currentUserId) {
  const isUserA = match.userA._id.toString() === currentUserId.toString();
  const matchedUser = isUserA ? match.userB : match.userA;

  return {
    id: match._id.toString(),
    type: match.type,
    createdAt: match.lastMatchedAt || match.createdAt,
    matchedUser: serializeMatchedUser(matchedUser),
  };
}

// A web voter's reveal token and browser session id are theirs alone, even
// once the vote is attributed to their account. The session id is also what
// anonymous blocks and bans key on, so leaking it would let someone vote
// abusively "as" another person's browser.
function withoutVoterSecrets(metadata) {
  if (!metadata) return null;
  const { pendingToken, sessionId, ...rest } = metadata;
  return rest;
}

function serializeAnonymousInteraction(interaction) {
  const metadata = { ...(interaction.metadata || {}) };
  // Reveal tokens and browser session identifiers belong only to the voter.
  // They must never be exposed to the poll creator through the received feed.
  delete metadata.pendingToken;
  delete metadata.sessionId;

  return {
    id: interaction._id.toString(),
    fromUser: '',
    fromUserName: null,
    fromUserUsername: null,
    fromUserProfileImageUrl: null,
    fromUserShareCode: null,
    fromUserInstagramId: null,
    fromUserSnapchatId: null,
    toUser: interaction.toUser.toString(),
    type: interaction.type,
    metadata: {
      ...metadata,
      anonymous: true,
      anonymousVoteBackEnabled: env.anonymousVoteBackEnabled,
    },
    respondedByCurrentUser: Boolean(interaction.metadata?.creatorResponseType),
    matched: Boolean(interaction.metadata?.anonymousMatched),
    createdAt: interaction.createdAt,
  };
}

function serializeAnonymousMatch(interaction) {
  const respondedAt = interaction.metadata?.creatorRespondedAt;
  return {
    id: `anonymous:${interaction.id}`,
    type: interaction.type,
    anonymous: true,
    createdAt: respondedAt || interaction.createdAt,
    matchedUser: {
      id: `anonymous:${interaction.id}`,
      name: 'Anonymous',
      email: '',
      instagramId: '',
      avatarUrl: null,
      shareCode: '',
      isPro: false,
    },
  };
}

const pendingAnonymousPushTimers = new Map();

/** Pushes to the poll creator (`toUser`) whenever anyone votes. `fromUser` is null for anonymous votes. */
async function notifyVote({ toUserId, fromUser }) {
  try {
    const voterName = fromUser?.username || fromUser?.name || null;
    await pushService.sendToUser(toUserId, {
      title: 'New vote!',
      body: voterName ? `${voterName} voted on your poll` : 'Someone voted on your poll',
      imageUrl: fromUser?.profileImageUrl || null,
      data: { type: 'vote' },
    });
  } catch (error) {
    console.error('[Push] notifyVote failed', error);
  }
}

/**
 * Schedules the single "someone voted" push for an anonymous web vote, fired only
 * once the PENDING_TTL_SECONDS reveal window has fully elapsed. Whichever way the
 * voter's identity resolved by then decides the push: anonymous, or (if they
 * installed and created an account in time) their real name and photo.
 */
function scheduleAnonymousVoteNotification({ toUserId, pendingToken, delayMs = PENDING_TTL_MS }) {
  if (!pendingToken) return;

  cancelAnonymousVoteNotification(pendingToken);

  const timer = setTimeout(async () => {
    pendingAnonymousPushTimers.delete(pendingToken);
    try {
      const interaction = await Interaction.findOne({
        toUser: toUserId,
        'metadata.pendingToken': pendingToken,
      });
      if (!interaction) return;
      // No push for a vote the recipient hid or whose voter they blocked
      // during the reveal window.
      if (!(await blockService.recipientStillWantsVote(interaction))) return;
      if (interaction.fromUser) {
        const fromUser = await User.findById(interaction.fromUser).select(
          'username name profileImageUrl'
        );
        await notifyVote({ toUserId, fromUser });
      } else {
        await notifyVote({ toUserId, fromUser: null });
      }
    } catch (err) {
      console.error('[Push] Delayed anonymous vote notification failed:', err);
    }
  }, delayMs);

  pendingAnonymousPushTimers.set(pendingToken, timer);
}

function cancelAnonymousVoteNotification(pendingToken) {
  if (pendingToken && pendingAnonymousPushTimers.has(pendingToken)) {
    clearTimeout(pendingAnonymousPushTimers.get(pendingToken));
    pendingAnonymousPushTimers.delete(pendingToken);
  }
}

/**
 * Pushes "it's a match" to both sides of a newly created/updated Match doc
 * (userA/userB populated), except `skipUserId` — the user whose vote created
 * the match already sees the celebration in the app.
 */
async function notifyMatch(match, { skipUserId = null } = {}) {
  if (!match) return;
  try {
    const pairs = [
      [match.userA, match.userB],
      [match.userB, match.userA],
    ].filter(
      ([recipient]) =>
        !skipUserId || recipient.id.toString() !== skipUserId.toString()
    );
    await Promise.all(
      pairs.map(([recipient, other]) =>
        pushService.sendToUser(recipient.id, {
          title: "It's a match! 🎉",
          body: `You and ${other.username || other.name} matched!`,
          imageUrl: other.profileImageUrl || null,
          data: { type: 'match', matchId: match.id },
        })
      )
    );
  } catch (error) {
    console.error('[Push] notifyMatch failed', error);
  }
}

async function createInteraction({ fromUserId, shareCode, type }) {
  const normalizedType = normalizeType(type);
  const targetUser = await User.findOne({ shareCode }).select('+blockedUsers');
  if (!targetUser || targetUser.isBanned) {
    throw new ApiError(404, 'Target profile not found.');
  }

  if (targetUser.id.toString() === fromUserId.toString()) {
    throw new ApiError(400, 'You cannot interact with your own profile.');
  }
  await assertUsersCanInteract(fromUserId, targetUser);
  await assertInteractionCooldownElapsed(fromUserId, targetUser.id);

  const interaction = await Interaction.create({
    fromUser: fromUserId,
    toUser: targetUser.id,
    type: normalizedType,
  });

  const fromUser = await User.findById(fromUserId).select('username name profileImageUrl');
  await notifyVote({ toUserId: targetUser.id, fromUser });

  const reciprocal = await Interaction.findOne({
    fromUser: targetUser.id,
    toUser: fromUserId,
    type: normalizedType,
    createdAt: {
      $gte: new Date(interaction.createdAt.getTime() - INTERACTION_COOLDOWN_MS),
    },
  });

  let match = null;

  if (reciprocal) {
    const pair = buildCanonicalPair(fromUserId, targetUser.id);
    match = await Match.findOneAndUpdate(
      { userA: pair.userA, userB: pair.userB, type: normalizedType },
      {
        userA: pair.userA,
        userB: pair.userB,
        type: normalizedType,
        triggeredBy: fromUserId,
        lastMatchedAt: new Date(),
      },
      {
        upsert: true,
        new: true,
        setDefaultsOnInsert: true,
      }
    ).populate('userA userB', MATCHED_USER_FIELDS);

    await notifyMatch(match);
  }

  return {
    interaction: interaction.toJSON(),
    matched: Boolean(match),
    match: match ? serializeMatch(match, fromUserId) : null,
    notification: match ? { type: 'match', matchId: match.id } : null,
  };
}

async function getMatchesForUser(userId) {
  const visibleSince = new Date(Date.now() - VISIBLE_MATCH_WINDOW_MS);
  const currentUser = await User.findById(userId)
    .select('blockedUsers blockedVoterSessions')
    .lean();
  const blockedUserIds = currentUser?.blockedUsers || [];
  const blockedVoterSessions = currentUser?.blockedVoterSessions || [];
  // Matches with someone who blocked this user are deleted when the block is
  // made (blockService), so only this user's own block list is needed here.
  const matches = await Match.find({
    $and: [
      {
        $or: [
          { lastMatchedAt: { $gte: visibleSince } },
          { lastMatchedAt: { $exists: false }, createdAt: { $gte: visibleSince } },
        ],
      },
    ],
    $or: [{ userA: userId }, { userB: userId }],
    $nor: [
      { userA: { $in: blockedUserIds } },
      { userB: { $in: blockedUserIds } },
    ],
  })
    .sort({ createdAt: -1 })
    .populate('userA userB', MATCHED_USER_FIELDS)
    .lean();

  const serializedMatches = matches
    // A match whose other user no longer exists would crash serialization and
    // fail every request for this user.
    .filter((match) => match.userA && match.userB)
    .map((match) => serializeMatch(match, userId))
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

  if (!env.anonymousVoteBackEnabled) {
    return serializedMatches;
  }

  const anonymousMatches = await Interaction.find({
    toUser: userId,
    fromUser: null,
    'metadata.anonymous': true,
    'metadata.anonymousMatched': true,
    'metadata.creatorRespondedAt': { $gte: visibleSince },
    ...visibleToRecipientFilter(blockedVoterSessions),
  }).sort({ 'metadata.creatorRespondedAt': -1 });

  return [...serializedMatches, ...anonymousMatches.map(serializeAnonymousMatch)]
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
}

async function createAnonymousResponse({
  identifier,
  shareCode,
  type,
  source = 'web',
  timestamp,
  sessionId,
  fromUserId = null,
  pendingToken: clientPendingToken = null,
}) {
  const normalizedType = normalizeType(type);
  const rawIdentifier = (shareCode || identifier || '').trim();
  const normalized = rawIdentifier.toLowerCase();
  if (!normalized) {
    throw new ApiError(400, 'Share code is required.');
  }

  if (!timestamp || Number.isNaN(Number(timestamp))) {
    throw new ApiError(400, 'Timestamp is required.');
  }

  // `timestamp` is the voter's device clock at the moment of the tap, not a
  // link-share time, so it can't expire a link. Comparing it to a 3-minute TTL
  // only rejected every vote from devices whose clock runs a few minutes
  // slow; just discard values that are nowhere near real time.
  const now = Date.now();
  const sentAt = Number(timestamp);
  if (Math.abs(now - sentAt) > MAX_CLIENT_CLOCK_SKEW_MS) {
    throw new ApiError(400, 'Invalid timestamp.');
  }

  // shareCode is uniquely indexed; username has no index, so looking it up
  // first scanned the whole users collection on every web vote. Try the
  // indexed field first and only fall back to username when it misses.
  // Banned accounts have no public poll. Block lists are loaded for the checks below.
  const findTarget = (filter) =>
    User.findOne({ ...filter, isBanned: { $ne: true } }).select(
      '+blockedUsers +blockedVoterSessions'
    );
  const targetUser =
    (await findTarget({ shareCode: { $in: [normalized, rawIdentifier] } })) ||
    (await findTarget({ username: normalized }));
  if (!targetUser) {
    throw new ApiError(404, 'Target profile not found.');
  }

  // A logged-in voter is subject to account blocks in both directions.
  if (fromUserId) {
    await assertUsersCanInteract(fromUserId, targetUser);
  }

  if (sessionId) {
    // Check anonymous Interactions in the last 24 h (survives the 60 s PendingInteraction TTL).
    // The block check wins over the duplicate check: a blocked voter's earlier
    // vote is usually why they were blocked.
    const [existingInteraction] = await Promise.all([
      Interaction.findOne({
        toUser: targetUser.id,
        fromUser: null,
        'metadata.sessionId': sessionId,
        createdAt: { $gte: new Date(now - INTERACTION_COOLDOWN_MS) },
      }),
      blockService.assertVoterSessionAllowed(targetUser, sessionId),
    ]);
    if (existingInteraction) {
      throw new ApiError(409, 'This interaction has already been sent.');
    }
  }

  // The web client may generate the reveal token itself so its Reveal button
  // works before this request returns; otherwise generate one here. Knowing the
  // token and expiry up front lets both writes below run in parallel.
  const deepLinkToken =
    clientPendingToken && PENDING_TOKEN_PATTERN.test(clientPendingToken)
      ? clientPendingToken
      : crypto.randomBytes(16).toString('hex');
  const expiresAt = new Date(Date.now() + PENDING_TTL_MS);

  const [pendingResult, fromUserResult, interactionResult] = await Promise.allSettled([
    createPendingInteraction({
      targetUserId: targetUser.id,
      type: normalizedType,
      source,
      sessionId,
      shareCode: targetUser.shareCode,
      targetUser,
      deepLinkToken,
      expiresAt,
    }),
    fromUserId
      ? User.findById(fromUserId).select('username name profileImageUrl')
      : Promise.resolve(null),
    // Create an Interaction record so the play card shows and the poll counts.
    // It stays hidden from the creator's Play queue (see getReceivedInteractions)
    // until pendingRevealUntil passes, giving the voter the full reveal window to
    // install and create an account before the creator ever sees or is notified
    // about the vote.
    Interaction.create({
      fromUser: fromUserId || null,
      toUser: targetUser.id,
      type: normalizedType,
      metadata: {
        anonymous: !fromUserId,
        pendingReveal: !fromUserId,
        pendingToken: deepLinkToken,
        ...(fromUserId ? {} : { pendingRevealUntil: expiresAt }),
        source,
        sessionId: sessionId || null,
      },
    }),
  ]);

  const failed = [pendingResult, fromUserResult, interactionResult].find(
    (result) => result.status === 'rejected'
  );
  if (failed) {
    // Don't leave a vote behind whose reveal token was never stored.
    if (interactionResult.status === 'fulfilled') {
      await Interaction.deleteOne({ _id: interactionResult.value._id }).catch(() => {});
    }
    if (pendingResult.status === 'fulfilled') {
      await PendingInteraction.deleteOne({ deepLinkToken }).catch(() => {});
    }
    if (failed.reason?.code === 11000) {
      throw new ApiError(409, 'This interaction has already been sent.');
    }
    throw failed.reason;
  }
  const pending = pendingResult.value;
  const fromUser = fromUserResult.value;

  if (fromUser) {
    await notifyVote({ toUserId: targetUser.id, fromUser });
  } else {
    // Fires once the reveal window fully elapses. If the voter installs and
    // creates an account before then, finalizePendingInteraction attributes the
    // interaction to them and this same timer sends the real-name push instead.
    scheduleAnonymousVoteNotification({
      toUserId: targetUser.id,
      pendingToken: pending.pendingToken,
    });
  }

  console.info('[AnonymousResponse] pending created', {
    shareCode: targetUser.shareCode,
    type: normalizedType,
    pendingToken: pending.pendingToken,
  });

  return {
    success: true,
    isMatch: false,
    matched: false,
    pendingToken: pending.pendingToken,
    expiresAt: pending.expiresAt,
    shareCode: targetUser.shareCode,
    type: normalizedType,
  };
}

async function createInteractionByTargetId({
  fromUserId,
  targetUserId,
  type,
  enforceCardLimit = true,
}) {
  let limitStatus = null;
  if (enforceCardLimit) {
    limitStatus = await appConfigService.getCardLimitStatus(fromUserId);
    if (limitStatus.limited) {
      throw new ApiError(
        429,
        'Card limit reached. Please wait for the cooldown.',
        { cardLimitStatus: limitStatus }
      );
    }
  }

  const normalizedType = normalizeType(type);
  const targetUser = await User.findById(targetUserId).select('+blockedUsers');
  if (!targetUser || targetUser.isBanned) {
    throw new ApiError(404, 'Target profile not found.');
  }
  if (targetUser.id.toString() === fromUserId.toString()) {
    throw new ApiError(400, 'You cannot interact with your own profile.');
  }
  await assertUsersCanInteract(fromUserId, targetUser);
  await assertInteractionCooldownElapsed(fromUserId, targetUser.id);

  const interaction = await Interaction.create({
    fromUser: fromUserId,
    toUser: targetUser.id,
    type: normalizedType,
  });

  const fromUser = await User.findById(fromUserId).select('username name profileImageUrl');
  await notifyVote({ toUserId: targetUser.id, fromUser });

  const reciprocal = await Interaction.findOne({
    fromUser: targetUser.id,
    toUser: fromUserId,
    type: normalizedType,
    createdAt: {
      $gte: new Date(interaction.createdAt.getTime() - INTERACTION_COOLDOWN_MS),
    },
  });

  let match = null;
  if (reciprocal) {
    const pair = buildCanonicalPair(fromUserId, targetUser.id);
    match = await Match.findOneAndUpdate(
      { userA: pair.userA, userB: pair.userB, type: normalizedType },
      {
        userA: pair.userA,
        userB: pair.userB,
        type: normalizedType,
        triggeredBy: fromUserId,
        lastMatchedAt: new Date(),
      },
      {
        upsert: true,
        new: true,
        setDefaultsOnInsert: true,
      }
    ).populate('userA userB', MATCHED_USER_FIELDS);

    await notifyMatch(match, { skipUserId: fromUserId });
  }

  // Must await so the DB write completes before the response is sent.
  // On Vercel serverless, fire-and-forget work is frozen as soon as the
  // response is returned, so a non-awaited increment would never persist.
  const cardLimitStatus = await appConfigService
    .recordCardView(fromUserId, limitStatus)
    .catch((err) => {
      console.error('[CardSession] Failed to record card view:', err);
      return null;
    });

  return {
    interaction: interaction.toJSON(),
    matched: Boolean(match),
    match: match ? serializeMatch(match, fromUserId) : null,
    notification: match ? { type: 'match', matchId: match.id } : null,
    cardLimitStatus,
  };
}

async function respondToAnonymousInteraction({ currentUserId, interactionId, type }) {
  if (!env.anonymousVoteBackEnabled) {
    throw new ApiError(403, 'Anonymous vote-back is currently disabled.');
  }

  const limitStatus = await appConfigService.getCardLimitStatus(currentUserId);
  if (limitStatus.limited) {
    throw new ApiError(
      429,
      'Card limit reached. Please wait for the cooldown.',
      { cardLimitStatus: limitStatus }
    );
  }

  const normalizedType = normalizeType(type);
  // A hidden vote (hidden, reported or from a blocked session) can't be answered.
  const candidate = await Interaction.findOne({
    _id: interactionId,
    toUser: currentUserId,
    fromUser: null,
    'metadata.anonymous': true,
    hiddenByRecipientAt: null,
  });
  if (!candidate) {
    throw new ApiError(404, 'Anonymous interaction not found.');
  }
  if (candidate.metadata?.creatorResponseType) {
    throw new ApiError(409, 'You already responded to this interaction.');
  }

  const respondedAt = new Date();
  const matched = candidate.type === normalizedType;
  const interaction = await Interaction.findOneAndUpdate(
    {
      _id: candidate.id,
      toUser: currentUserId,
      fromUser: null,
      'metadata.anonymous': true,
      'metadata.creatorResponseType': { $exists: false },
      hiddenByRecipientAt: null,
    },
    {
      $set: {
        'metadata.creatorResponseType': normalizedType,
        'metadata.creatorRespondedAt': respondedAt,
        'metadata.anonymousMatched': matched,
      },
    },
    { new: true }
  );
  if (!interaction) {
    throw new ApiError(409, 'You already responded to this interaction.');
  }

  const cardLimitStatus = await appConfigService
    .recordCardView(currentUserId, limitStatus)
    .catch((err) => {
      console.error('[CardSession] Failed to record anonymous card view:', err);
      return null;
    });

  return {
    interaction: serializeAnonymousInteraction(interaction),
    matched,
    match: matched ? serializeAnonymousMatch(interaction) : null,
    notification: null,
    cardLimitStatus,
  };
}

async function createAnonymousInteraction({ targetUserId, type, source = 'web' }) {
  const normalizedType = normalizeType(type);
  const targetUser = await User.findById(targetUserId);
  if (!targetUser || targetUser.isBanned) {
    throw new ApiError(404, 'Target profile not found.');
  }

  const interaction = await Interaction.create({
    fromUser: null,
    toUser: targetUser.id,
    type: normalizedType,
    metadata: { source, anonymous: true },
  });

  await notifyVote({ toUserId: targetUser.id, fromUser: null });

  return {
    interaction: interaction.toJSON(),
    matched: false,
    match: null,
    notification: null,
  };
}

// Votes the Play queue shows: those still waiting for an answer (the app's
// isActionablePlayInteraction). Play and its tab badge refresh this often, so
// it is kept small instead of returning the whole history each time.
const PLAY_QUEUE_LIMIT = 100;
// Registered-voter candidates read before answered ones are dropped.
const PLAY_QUEUE_SCAN_LIMIT = 300;
// The full list (`scope=all`: Inbox counts and its hide/report/block list).
const RECEIVED_HISTORY_LIMIT = 500;
const RECEIVED_VOTER_FIELDS = 'name username instagramId snapchatId profileImageUrl shareCode';

function serializeRegisteredVote(vote, { respondedByCurrentUser, matched }) {
  const fromUser = vote.fromUser;
  return {
    id: vote._id.toString(),
    fromUser: fromUser._id.toString(),
    fromUserName: fromUser.name || null,
    fromUserUsername: fromUser.username || null,
    fromUserProfileImageUrl: fromUser.profileImageUrl || null,
    fromUserShareCode: fromUser.shareCode || null,
    fromUserInstagramId: fromUser.instagramId || null,
    fromUserSnapchatId: fromUser.snapchatId || null,
    toUser: vote.toUser.toString(),
    type: vote.type,
    metadata: withoutVoterSecrets(vote.metadata),
    respondedByCurrentUser,
    matched,
    createdAt: vote.createdAt,
  };
}

/** Times of the user's own votes per target, to tell answered cards apart. */
async function outgoingVoteTimes(userId, voterIds, since = null) {
  if (!voterIds.length) return new Map();
  const outgoing = await Interaction.find({
    fromUser: userId,
    toUser: { $in: voterIds },
    ...(since ? { createdAt: { $gte: since } } : {}),
  })
    .select('toUser createdAt')
    .lean();
  const byUserId = new Map();
  for (const interaction of outgoing) {
    const targetId = interaction.toUser.toString();
    const existing = byUserId.get(targetId) || [];
    existing.push(interaction.createdAt.getTime());
    byUserId.set(targetId, existing);
  }
  return byUserId;
}

function answeredWithinWindow(outgoingByUserId, voterId, voteTime) {
  return (outgoingByUserId.get(voterId) || []).some(
    (outgoingAt) => Math.abs(outgoingAt - voteTime) < INTERACTION_COOLDOWN_MS
  );
}

/**
 * Votes received by `userId`. By default only the Play queue (unanswered
 * cards, see PLAY_QUEUE_LIMIT); `scope: 'all'` returns the full newest-first
 * list for the Inbox.
 */
async function getReceivedInteractions(userId, { scope = null } = {}) {
  const now = new Date();
  const currentUser = await User.findById(userId)
    .select('blockedUsers blockedVoterSessions')
    .lean();
  const blockedUserIds = currentUser?.blockedUsers || [];
  const visibleVotes = {
    toUser: userId,
    // Votes this user hid, reported or blocked (by account or web session).
    ...visibleToRecipientFilter(currentUser?.blockedVoterSessions),
    // Hide an anonymous web vote until its reveal window fully elapses, whether
    // it ends up staying anonymous or gets attributed to a new account in the
    // meantime — see createAnonymousResponse / finalizePendingInteraction.
    $or: [
      { 'metadata.pendingRevealUntil': { $exists: false } },
      { 'metadata.pendingRevealUntil': { $lte: now } },
    ],
  };

  return scope === 'all'
    ? getReceivedHistory(userId, visibleVotes, blockedUserIds)
    : getPlayQueue(userId, visibleVotes, blockedUserIds, now);
}

async function getPlayQueue(userId, visibleVotes, blockedUserIds, now) {
  // Answering a card only counts within 24h of the vote (see
  // answeredWithinWindow), and an older vote can no longer produce a match, so
  // older registered-voter cards could never leave the queue.
  const answerWindowStart = new Date(now.getTime() - INTERACTION_COOLDOWN_MS);

  const [registeredVotes, anonymousVotes] = await Promise.all([
    Interaction.find({
      ...visibleVotes,
      fromUser: { $ne: null, $nin: blockedUserIds },
      createdAt: { $gte: answerWindowStart },
    })
      .sort({ createdAt: -1 })
      .limit(PLAY_QUEUE_SCAN_LIMIT)
      .populate('fromUser', RECEIVED_VOTER_FIELDS)
      .lean(),
    // Anonymous votes can only be answered when vote-back is enabled; they
    // track their own answer, so keep them until the creator responds.
    env.anonymousVoteBackEnabled
      ? Interaction.find({
          ...visibleVotes,
          fromUser: null,
          'metadata.creatorResponseType': { $exists: false },
        })
          .sort({ createdAt: -1 })
          .limit(PLAY_QUEUE_LIMIT)
          .lean()
      : [],
  ]);

  // Votes whose voter no longer exists can't be answered.
  const liveVotes = registeredVotes.filter((vote) => vote.fromUser);
  const voterIds = [...new Set(liveVotes.map((vote) => vote.fromUser._id.toString()))];
  const outgoingByUserId = await outgoingVoteTimes(
    userId,
    voterIds,
    new Date(answerWindowStart.getTime() - INTERACTION_COOLDOWN_MS)
  );

  const unanswered = liveVotes
    .filter(
      (vote) =>
        !answeredWithinWindow(
          outgoingByUserId,
          vote.fromUser._id.toString(),
          vote.createdAt.getTime()
        )
    )
    // A match needs an answer, so an unanswered vote is never matched.
    .map((vote) =>
      serializeRegisteredVote(vote, { respondedByCurrentUser: false, matched: false })
    );

  return [...unanswered, ...anonymousVotes.map(serializeAnonymousInteraction)]
    .sort((a, b) => b.createdAt - a.createdAt)
    .slice(0, PLAY_QUEUE_LIMIT);
}

async function getReceivedHistory(userId, visibleVotes, blockedUserIds) {
  const interactions = await Interaction.find({
    ...visibleVotes,
    fromUser: { $nin: blockedUserIds },
  })
    .sort({ createdAt: -1 })
    .limit(RECEIVED_HISTORY_LIMIT)
    .populate('fromUser', RECEIVED_VOTER_FIELDS)
    .lean();

  const voterIds = [
    ...new Set(
      interactions
        .map((interaction) => interaction.fromUser?._id?.toString())
        .filter(Boolean)
    ),
  ];

  const pairIds = voterIds.map((voterId) => buildCanonicalPair(userId, voterId));
  const [outgoingByUserId, matches] = await Promise.all([
    outgoingVoteTimes(userId, voterIds),
    pairIds.length
      ? Match.find({
          $or: pairIds.map((pair) => ({ userA: pair.userA, userB: pair.userB })),
        })
          .select('userA userB type createdAt lastMatchedAt')
          .lean()
      : [],
  ]);

  const matchesByKey = new Map(
    matches.map((match) => {
      const otherUserId =
        match.userA.toString() === userId.toString()
          ? match.userB.toString()
          : match.userA.toString();
      return [`${otherUserId}:${match.type}`, match.lastMatchedAt || match.createdAt];
    })
  );

  return interactions.map((interaction) => {
    const fromUserId = interaction.fromUser?._id?.toString() || null;
    if (!fromUserId) {
      return serializeAnonymousInteraction(interaction);
    }

    const interactionTime = interaction.createdAt.getTime();
    const matchedAt = matchesByKey.get(`${fromUserId}:${interaction.type}`);
    return serializeRegisteredVote(interaction, {
      respondedByCurrentUser: answeredWithinWindow(
        outgoingByUserId,
        fromUserId,
        interactionTime
      ),
      matched:
        Boolean(matchedAt) &&
        Math.abs(matchedAt.getTime() - interactionTime) < INTERACTION_COOLDOWN_MS,
    });
  });
}

async function createPendingInteraction({
  targetUserId,
  type,
  source = 'web',
  sessionId = null,
  shareCode = null,
  targetUser: resolvedTargetUser = null,
  deepLinkToken = crypto.randomBytes(16).toString('hex'),
  expiresAt = new Date(Date.now() + PENDING_TTL_MS),
}) {
  const normalizedType = normalizeType(type);
  // Callers that already loaded the user pass it in to skip a round trip.
  const targetUser = resolvedTargetUser || (await User.findById(targetUserId));
  if (!targetUser || targetUser.isBanned) {
    throw new ApiError(404, 'Target profile not found.');
  }

  const pending = await PendingInteraction.create({
    targetUserId: targetUser.id,
    type: normalizedType,
    source,
    sessionId,
    shareCode,
    deepLinkToken,
    expiresAt,
  });

  // Expiry is handled by the TTL index on `expiresAt` (see PendingInteraction model)
  // and by the expiry checks in finalize/get. No in-process timer is used because
  // serverless functions freeze after responding and would never fire it.

  return {
    pendingToken: pending.deepLinkToken,
    expiresAt: pending.expiresAt,
  };
}

/**
 * Finds a pending interaction by token, briefly waiting for it to appear if it
 * is not there yet (the web client's create request may still be in flight).
 */
async function findPendingByToken(token, populate = null) {
  const deadline = Date.now() + PENDING_LOOKUP_WAIT_MS;
  for (;;) {
    const query = PendingInteraction.findOne({ deepLinkToken: token });
    if (populate) query.populate(...populate);
    const pending = await query;
    if (pending || !PENDING_TOKEN_PATTERN.test(token || '') || Date.now() >= deadline) {
      return pending;
    }
    await new Promise((resolve) => setTimeout(resolve, PENDING_LOOKUP_POLL_MS));
  }
}

async function detectMatchAndBuildResult({ fromUserId, targetUserId, type, replay = false }) {
  const interaction = await Interaction.findOne({
    fromUser: fromUserId,
    toUser: targetUserId,
    type,
  }).sort({ createdAt: -1 });

  const reciprocal = await Interaction.findOne({
    fromUser: targetUserId,
    toUser: fromUserId,
    type,
    ...(interaction && {
      createdAt: {
        $gte: new Date(interaction.createdAt.getTime() - INTERACTION_COOLDOWN_MS),
      },
    }),
  }).sort({ createdAt: -1 });

  let match = null;
  if (reciprocal) {
    const pair = buildCanonicalPair(fromUserId, targetUserId);
    if (replay) {
      // A replayed reveal link (e.g. the Android install referrer on a later
      // launch) only reads the result: bumping lastMatchedAt put the match back
      // into both users' 24h lists and re-sent "It's a match!" every time.
      match = await Match.findOne({ userA: pair.userA, userB: pair.userB, type })
        .populate('userA userB', MATCHED_USER_FIELDS);
      if (match && (!match.userA || !match.userB)) match = null;
    } else {
      match = await Match.findOneAndUpdate(
        { userA: pair.userA, userB: pair.userB, type },
        {
          userA: pair.userA,
          userB: pair.userB,
          type,
          triggeredBy: fromUserId,
          lastMatchedAt: new Date(),
        },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      ).populate('userA userB', MATCHED_USER_FIELDS);

      await notifyMatch(match);
    }
  }

  return {
    interaction: interaction ? interaction.toJSON() : null,
    matched: Boolean(match),
    match: match ? serializeMatch(match, fromUserId) : null,
    notification: match ? { type: 'match', matchId: match.id } : null,
  };
}

async function finalizePendingInteraction({ token, currentUserId }) {
  // Deliberately does NOT cancel the scheduled push here — that same timer
  // (see scheduleAnonymousVoteNotification) fires once at the end of the reveal
  // window and reads the interaction's fromUser at that point, so attributing it
  // here just changes which version of the push it ends up sending.
  const pending = await findPendingByToken(token);
  if (!pending) {
    throw new ApiError(404, 'Invalid or expired reveal link.');
  }

  // Checked first, including for a replay of an already-used link: the target
  // may since have been banned or have blocked this voter, by account or by the
  // web session the vote came from.
  const targetUser = await User.findById(pending.targetUserId).select(
    '+blockedUsers +blockedVoterSessions'
  );
  if (!targetUser || targetUser.isBanned) {
    throw new ApiError(404, 'Target profile not found.');
  }
  if (targetUser.id.toString() !== currentUserId.toString()) {
    await assertUsersCanInteract(currentUserId, targetUser);
    await blockService.assertVoterSessionAllowed(targetUser, pending.sessionId);
  }

  if (pending.status === 'finalized') {
    // If the same user re-finalizes (e.g. Android install referrer replays the
    // old token after the user clears app data), return the existing result
    // silently instead of erroring — the interaction was already recorded.
    const alreadyAttributed = await Interaction.findOne({
      toUser: pending.targetUserId,
      type: pending.type,
      fromUser: currentUserId,
      'metadata.pendingToken': token,
    });
    if (alreadyAttributed) {
      return await detectMatchAndBuildResult({
        fromUserId: currentUserId,
        targetUserId: pending.targetUserId,
        type: pending.type,
        replay: true,
      });
    }
    throw new ApiError(400, 'This reveal link has already been used.');
  }

  if (pending.status === 'expired' || Date.now() > pending.expiresAt.getTime()) {
    // If it was somehow not caught yet, reject as expired.
    if (pending.status !== 'expired') {
      pending.status = 'expired';
      await pending.save();
    }
    throw new ApiError(400, 'This reveal link has expired. You missed it!');
  }

  if (pending.targetUserId.toString() === currentUserId.toString()) {
    throw new ApiError(400, 'You cannot reveal an interaction sent to yourself.');
  }

  // Attribute the interaction FIRST and only mark the pending finalized once that
  // succeeds. This prevents a failure (e.g. duplicate key) from permanently
  // stranding the reveal link in a "used" state with no interaction recorded.
  const existingAnonymous = await Interaction.findOne({
    toUser: pending.targetUserId,
    type: pending.type,
    fromUser: null,
    'metadata.pendingToken': token,
  }).sort({ createdAt: -1 });

  let result;
  if (existingAnonymous) {
    // If the creator already answered while this voter was anonymous, preserve
    // that answer as a normal reciprocal interaction during attribution. This
    // upgrades a synthetic anonymous match into an ordinary account-to-account
    // match without asking the creator to vote a second time.
    const creatorResponseType = existingAnonymous.metadata?.creatorResponseType;
    try {
      existingAnonymous.fromUser = currentUserId;
      existingAnonymous.metadata = {
        ...(existingAnonymous.metadata || {}),
        anonymous: false,
        pendingReveal: false,
        finalizedFromPending: true,
      };
      await existingAnonymous.save();
    } catch (error) {
      if (error && error.code === 11000) {
        // The current user already has a real interaction of this type to the
        // target. Drop the now-redundant anonymous record and continue with the
        // existing one rather than failing the reveal.
        await Interaction.deleteOne({ _id: existingAnonymous._id });
      } else {
        throw error;
      }
    }

    if (creatorResponseType) {
      await Interaction.updateOne(
        {
          fromUser: pending.targetUserId,
          toUser: currentUserId,
          type: creatorResponseType,
        },
        {
          $setOnInsert: {
            fromUser: pending.targetUserId,
            toUser: currentUserId,
            type: creatorResponseType,
            metadata: {
              source: 'anonymous-vote-back',
              finalizedFromPending: true,
            },
          },
        },
        { upsert: true }
      );
    }

    result = await detectMatchAndBuildResult({
      fromUserId: currentUserId,
      targetUserId: pending.targetUserId,
      type: pending.type,
      enforceCardLimit: false,
    });
    // No immediate "voted on your poll" push here: the creator can't have seen
    // this card yet (it's still hidden behind pendingRevealUntil), so the
    // scheduled timer from createAnonymousResponse will send it, with this
    // now-attributed fromUser, once the reveal window elapses.
  } else {
    // Backward compatibility for records created before pendingToken metadata existed.
    result = await createInteractionByTargetId({
      fromUserId: currentUserId,
      targetUserId: pending.targetUserId,
      type: pending.type,
    });
  }

  pending.status = 'finalized';
  await pending.save();

  return result;
}

async function touchPendingInteraction(token) {
  const pending = await findPendingByToken(token);
  if (!pending) {
    throw new ApiError(404, 'Interaction not found or expired.');
  }
  if (pending.status === 'finalized') {
    // Already done — nothing to extend, treat as success.
    return { expiresAt: pending.expiresAt };
  }
  if (pending.status === 'expired') {
    throw new ApiError(400, 'This reveal link has already expired.');
  }

  const extended = new Date(Date.now() + REVEAL_EXTEND_MS);
  // Only extend if it would push the deadline further out.
  if (extended > pending.expiresAt) {
    pending.expiresAt = extended;
    await pending.save();
  }

  return { expiresAt: pending.expiresAt };
}

async function getPendingInteraction(token) {
  const pending = await findPendingByToken(token, ['targetUserId', 'name profileImageUrl']);
  if (!pending) {
    throw new ApiError(404, 'Interaction not found or expired.');
  }
  if (pending.status === 'finalized') {
    throw new ApiError(400, 'This reveal link has already been used.');
  }
  if (pending.status === 'expired' || Date.now() > pending.expiresAt.getTime()) {
    throw new ApiError(400, 'This reveal link has expired.');
  }
  return pending;
}

module.exports = {
  createInteraction,
  createAnonymousResponse,
  createInteractionByTargetId,
  respondToAnonymousInteraction,
  createAnonymousInteraction,
  getMatchesForUser,
  getReceivedInteractions,
  createPendingInteraction,
  touchPendingInteraction,
  finalizePendingInteraction,
  getPendingInteraction,
};

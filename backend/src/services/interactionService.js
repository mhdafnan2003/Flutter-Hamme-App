const Interaction = require('../models/Interaction');
const Match = require('../models/Match');
const User = require('../models/User');
const PendingInteraction = require('../models/PendingInteraction');
const ApiError = require('../utils/ApiError');
const crypto = require('crypto');
const { emitMatchFound } = require('../socket');

const allowedTypes = new Set(['friend', 'crush', 'frenemy']);
const pendingTtlSecondsRaw = Number(process.env.PENDING_TTL_SECONDS || 60);
const pendingTtlSeconds = Number.isFinite(pendingTtlSecondsRaw)
  ? Math.max(30, pendingTtlSecondsRaw)
  : 60;
const PENDING_TTL_MS = pendingTtlSeconds * 1000;
const VISIBLE_MATCH_WINDOW_MS = 24 * 60 * 60 * 1000;

function buildCanonicalPair(firstUserId, secondUserId) {
  const [userA, userB] = [firstUserId.toString(), secondUserId.toString()].sort();
  return { userA, userB };
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

function serializeMatch(match, currentUserId) {
  const isUserA = match.userA.id.toString() === currentUserId.toString();
  const matchedUser = isUserA ? match.userB : match.userA;

  return {
    id: match.id,
    type: match.type,
    createdAt: match.createdAt,
    matchedUser: matchedUser.toJSON(),
  };
}

async function createInteraction({ fromUserId, shareCode, type }) {
  const normalizedType = normalizeType(type);
  const targetUser = await User.findOne({ shareCode });
  if (!targetUser) {
    throw new ApiError(404, 'Target profile not found.');
  }

  if (targetUser.id.toString() === fromUserId.toString()) {
    throw new ApiError(400, 'You cannot interact with your own profile.');
  }

  let interaction;
  try {
    interaction = await Interaction.create({
      fromUser: fromUserId,
      toUser: targetUser.id,
      type: normalizedType,
    });
  } catch (error) {
    if (error && error.code === 11000) {
      throw new ApiError(409, 'This interaction has already been sent.');
    }
    throw error;
  }

  const reciprocal = await Interaction.findOne({
    fromUser: targetUser.id,
    toUser: fromUserId,
    type: normalizedType,
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
      },
      {
        upsert: true,
        new: true,
        setDefaultsOnInsert: true,
      }
    ).populate('userA userB');

    const payload = serializeMatch(match, fromUserId);
    emitMatchFound([fromUserId, targetUser.id], payload);
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
  const matches = await Match.find({
    createdAt: { $gte: visibleSince },
    $or: [{ userA: userId }, { userB: userId }],
  })
    .sort({ createdAt: -1 })
    .populate('userA userB');

  return matches.map((match) => serializeMatch(match, userId));
}

async function createAnonymousResponse({
  identifier,
  shareCode,
  type,
  source = 'web',
  timestamp,
  sessionId,
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

  const now = Date.now();
  const sentAt = Number(timestamp);
  if (now - sentAt > PENDING_TTL_MS) {
    console.info('[AnonymousResponse] expired', { shareCode: normalized, sentAt, now });
    throw new ApiError(400, 'This link has expired.');
  }

  const targetUser =
    (await User.findOne({ username: normalized })) ||
    (await User.findOne({ shareCode: normalized })) ||
    (await User.findOne({ shareCode: rawIdentifier }));
  if (!targetUser) {
    throw new ApiError(404, 'Target profile not found.');
  }

  if (sessionId) {
    const duplicate = await PendingInteraction.findOne({
      targetUserId: targetUser.id,
      sessionId,
      type: normalizedType,
      status: { $in: ['pending', 'finalized'] },
      createdAt: { $gte: new Date(now - PENDING_TTL_MS) },
    });
    if (duplicate) {
      throw new ApiError(409, 'This interaction has already been sent.');
    }
  }

  const pending = await createPendingInteraction({
    targetUserId: targetUser.id,
    type: normalizedType,
    source,
    sessionId,
    shareCode: targetUser.shareCode,
  });

  // NOTE: we intentionally do NOT create an Interaction here. The reaction only
  // becomes a real (play-visible) Interaction when the sender reveals/finalizes
  // within the 60s window. If the reveal link expires, finalize is blocked and
  // no Interaction is ever created, so no play card appears for the creator.

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

async function createInteractionByTargetId({ fromUserId, targetUserId, type }) {
  const normalizedType = normalizeType(type);
  const targetUser = await User.findById(targetUserId);
  if (!targetUser) {
    throw new ApiError(404, 'Target profile not found.');
  }
  if (targetUser.id.toString() === fromUserId.toString()) {
    throw new ApiError(400, 'You cannot interact with your own profile.');
  }

  let interaction;
  try {
    interaction = await Interaction.create({
      fromUser: fromUserId,
      toUser: targetUser.id,
      type: normalizedType,
    });
  } catch (error) {
    if (error && error.code === 11000) {
      throw new ApiError(409, 'This interaction has already been sent.');
    }
    throw error;
  }

  const reciprocal = await Interaction.findOne({
    fromUser: targetUser.id,
    toUser: fromUserId,
    type: normalizedType,
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
      },
      {
        upsert: true,
        new: true,
        setDefaultsOnInsert: true,
      }
    ).populate('userA userB');

    const payload = serializeMatch(match, fromUserId);
    emitMatchFound([fromUserId, targetUser.id], payload);
  }

  return {
    interaction: interaction.toJSON(),
    matched: Boolean(match),
    match: match ? serializeMatch(match, fromUserId) : null,
    notification: match ? { type: 'match', matchId: match.id } : null,
  };
}

async function createAnonymousInteraction({ targetUserId, type, source = 'web' }) {
  const normalizedType = normalizeType(type);
  const targetUser = await User.findById(targetUserId);
  if (!targetUser) {
    throw new ApiError(404, 'Target profile not found.');
  }

  const interaction = await Interaction.create({
    fromUser: null,
    toUser: targetUser.id,
    type: normalizedType,
    metadata: { source, anonymous: true },
  });

  return {
    interaction: interaction.toJSON(),
    matched: false,
    match: null,
    notification: null,
  };
}

async function getReceivedInteractions(userId) {
  const interactions = await Interaction.find({ toUser: userId })
    .sort({ createdAt: -1 })
    .populate('fromUser', 'name username instagramId snapchatId profileImageUrl shareCode');

  const voterIds = [
    ...new Set(
      interactions
        .map((interaction) => interaction.fromUser?._id?.toString())
        .filter(Boolean)
    ),
  ];

  const outgoing = voterIds.length
    ? await Interaction.find({
        fromUser: userId,
        toUser: { $in: voterIds },
      }).select('toUser type')
    : [];

  const outgoingUserIds = new Set(
    outgoing.map((interaction) => interaction.toUser.toString())
  );

  const pairIds = voterIds.map((voterId) => buildCanonicalPair(userId, voterId));
  const matches = pairIds.length
    ? await Match.find({
        $or: pairIds.map((pair) => ({ userA: pair.userA, userB: pair.userB })),
      }).select('userA userB type')
    : [];

  const matchKeys = new Set(
    matches.map((match) => {
      const otherUserId =
        match.userA.toString() === userId.toString()
          ? match.userB.toString()
          : match.userA.toString();
      return `${otherUserId}:${match.type}`;
    })
  );

  return interactions.map((interaction) => {
    const fromUser = interaction.fromUser;
    const fromUserId = fromUser?._id?.toString() || null;
    const respondedByCurrentUser = Boolean(fromUserId) && outgoingUserIds.has(fromUserId);
    const matched =
      Boolean(fromUserId) && matchKeys.has(`${fromUserId}:${interaction.type}`);

    return {
      id: interaction.id,
      fromUser: fromUserId || '',
      fromUserName: fromUser?.name || null,
      fromUserUsername: fromUser?.username || null,
      fromUserProfileImageUrl: fromUser?.profileImageUrl || null,
      fromUserShareCode: fromUser?.shareCode || null,
      fromUserInstagramId: fromUser?.instagramId || null,
      fromUserSnapchatId: fromUser?.snapchatId || null,
      toUser: interaction.toUser.toString(),
      type: interaction.type,
      metadata: interaction.metadata || null,
      respondedByCurrentUser,
      matched,
      createdAt: interaction.createdAt,
    };
  });
}

async function createPendingInteraction({
  targetUserId,
  type,
  source = 'web',
  sessionId = null,
  shareCode = null,
}) {
  const normalizedType = normalizeType(type);
  const targetUser = await User.findById(targetUserId);
  if (!targetUser) {
    throw new ApiError(404, 'Target profile not found.');
  }

  const deepLinkToken = crypto.randomBytes(16).toString('hex');
  const expiresAt = new Date(Date.now() + PENDING_TTL_MS);

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

async function detectMatchAndBuildResult({ fromUserId, targetUserId, type }) {
  const interaction = await Interaction.findOne({
    fromUser: fromUserId,
    toUser: targetUserId,
    type,
  });

  const reciprocal = await Interaction.findOne({
    fromUser: targetUserId,
    toUser: fromUserId,
    type,
  });

  let match = null;
  if (reciprocal) {
    const pair = buildCanonicalPair(fromUserId, targetUserId);
    match = await Match.findOneAndUpdate(
      { userA: pair.userA, userB: pair.userB, type },
      { userA: pair.userA, userB: pair.userB, type, triggeredBy: fromUserId },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    ).populate('userA userB');

    const payload = serializeMatch(match, fromUserId);
    emitMatchFound([fromUserId, targetUserId], payload);
  }

  return {
    interaction: interaction ? interaction.toJSON() : null,
    matched: Boolean(match),
    match: match ? serializeMatch(match, fromUserId) : null,
    notification: match ? { type: 'match', matchId: match.id } : null,
  };
}

async function finalizePendingInteraction({ token, currentUserId }) {
  const pending = await PendingInteraction.findOne({ deepLinkToken: token });
  if (!pending) {
    throw new ApiError(404, 'Invalid or expired reveal link.');
  }

  if (pending.status === 'finalized') {
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

    result = await detectMatchAndBuildResult({
      fromUserId: currentUserId,
      targetUserId: pending.targetUserId,
      type: pending.type,
    });
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

async function getPendingInteraction(token) {
  const pending = await PendingInteraction.findOne({ deepLinkToken: token }).populate('targetUserId', 'name profileImageUrl');
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
  createAnonymousInteraction,
  getMatchesForUser,
  getReceivedInteractions,
  createPendingInteraction,
  finalizePendingInteraction,
  getPendingInteraction,
};

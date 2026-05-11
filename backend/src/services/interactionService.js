const Interaction = require('../models/Interaction');
const Match = require('../models/Match');
const User = require('../models/User');
const PendingInteraction = require('../models/PendingInteraction');
const ApiError = require('../utils/ApiError');
const crypto = require('crypto');
const { emitMatchFound } = require('../socket');

const allowedTypes = new Set(['friend', 'crush', 'frenemy', 'ameny']);

function buildCanonicalPair(firstUserId, secondUserId) {
  const [userA, userB] = [firstUserId.toString(), secondUserId.toString()].sort();
  return { userA, userB };
}

function normalizeType(type) {
  const normalized = (type || '').toString().trim().toLowerCase();
  if (!allowedTypes.has(normalized)) {
    throw new ApiError(400, 'Invalid interaction type.');
  }
  return normalized === 'ameny' ? 'frenemy' : normalized;
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
  const matches = await Match.find({
    $or: [{ userA: userId }, { userB: userId }],
  })
    .sort({ createdAt: -1 })
    .populate('userA userB');

  return matches.map((match) => serializeMatch(match, userId));
}

async function createAnonymousResponse({ identifier, type, source = 'web' }) {
  const normalized = (identifier || '').trim().toLowerCase();
  const normalizedType = normalizeType(type);
  if (!normalized) {
    throw new ApiError(400, 'Profile identifier is required.');
  }

  const targetUser =
    (await User.findOne({ username: normalized })) ||
    (await User.findOne({ shareCode: normalized }));
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
    interactionId: interaction.id,
    targetUserId: targetUser.id,
    shareCode: targetUser.shareCode,
    username: targetUser.username || null,
    next: 'install_or_open_app',
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
    .sort({ createdAt: -1 });

  return interactions.map((interaction) => {
    const payload = interaction.toJSON();
    return { ...payload, fromUser: payload.fromUser || '' };
  });
}

async function createPendingInteraction({ targetUserId, type, source = 'web' }) {
  const normalizedType = normalizeType(type);
  const targetUser = await User.findById(targetUserId);
  if (!targetUser) {
    throw new ApiError(404, 'Target profile not found.');
  }

  const deepLinkToken = crypto.randomBytes(16).toString('hex');
  const expiresAt = new Date(Date.now() + 60 * 1000); // 60 seconds

  const pending = await PendingInteraction.create({
    targetUserId: targetUser.id,
    type: normalizedType,
    source,
    deepLinkToken,
    expiresAt,
  });

  // Auto-expire and convert to anonymous after 60s
  setTimeout(async () => {
    const fs = require('fs');
    const logFile = require('path').join(process.cwd(), 'debug_expiry.log');
    const log = (msg) => fs.appendFileSync(logFile, `${new Date().toISOString()} ${msg}\n`);
    
    log(`Checking expiry for token: ${deepLinkToken}`);
    try {
      const p = await PendingInteraction.findById(pending.id);
      if (p && p.status === 'pending') {
        log(`Token ${deepLinkToken} expired. Converting to anonymous.`);
        p.status = 'expired';
        await p.save();
        
        const created = await Interaction.create({
          fromUser: null,
          toUser: targetUser.id,
          type: normalizedType,
          metadata: { source, anonymous: true, expiredPending: true },
        });
        log(`Anonymous interaction created: ${created.id} for user ${targetUser.id}`);
      } else {
        log(`Token ${deepLinkToken} already ${p ? p.status : 'not found'}.`);
      }
    } catch (e) {
      log(`Expiry failed: ${e.message}\n${e.stack}`);
      console.error('[PendingInteraction] Expiry failed:', e);
    }
  }, 60000);

  return {
    pendingToken: pending.deepLinkToken,
    expiresAt: pending.expiresAt,
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
    // If it was somehow not caught by setTimeout or already expired
    if (pending.status !== 'expired') {
      pending.status = 'expired';
      await pending.save();
    }
    throw new ApiError(400, 'This reveal link has expired. You missed it!');
  }

  if (pending.targetUserId.toString() === currentUserId.toString()) {
    throw new ApiError(400, 'You cannot reveal an interaction sent to yourself.');
  }

  // Mark finalized
  pending.status = 'finalized';
  await pending.save();

  // Convert to actual interaction
  const result = await createInteractionByTargetId({
    fromUserId: currentUserId,
    targetUserId: pending.targetUserId,
    type: pending.type,
  });

  return result;
}

async function getPendingInteraction(token) {
  const pending = await PendingInteraction.findOne({ deepLinkToken: token }).populate('targetUserId', 'name profileImageUrl');
  if (!pending) {
    throw new ApiError(404, 'Interaction not found or expired.');
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

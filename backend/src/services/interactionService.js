const Interaction = require('../models/Interaction');
const Match = require('../models/Match');
const User = require('../models/User');
const ApiError = require('../utils/ApiError');
const { emitMatchFound } = require('../socket');

function buildCanonicalPair(firstUserId, secondUserId) {
  const [userA, userB] = [firstUserId.toString(), secondUserId.toString()].sort();
  return { userA, userB };
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
      type,
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
    type,
  });

  let match = null;

  if (reciprocal) {
    const pair = buildCanonicalPair(fromUserId, targetUser.id);
    match = await Match.findOneAndUpdate(
      { userA: pair.userA, userB: pair.userB, type },
      {
        userA: pair.userA,
        userB: pair.userB,
        type,
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
  const validTypes = new Set(['friend', 'crush', 'frenemy']);
  if (!normalized) {
    throw new ApiError(400, 'Profile identifier is required.');
  }
  if (!validTypes.has(type)) {
    throw new ApiError(400, 'Invalid interaction type.');
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
    type,
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

module.exports = {
  createInteraction,
  createAnonymousResponse,
  getMatchesForUser,
};

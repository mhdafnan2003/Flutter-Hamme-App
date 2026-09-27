const BannedVoterSession = require('../models/BannedVoterSession');
const Interaction = require('../models/Interaction');
const Match = require('../models/Match');
const User = require('../models/User');
const ApiError = require('../utils/ApiError');
const { voteBlockedError } = require('../utils/safety');

// Blocking and hiding, as used by the app's report / block / hide actions.
//
// Feed queries only read the viewer's own block lists (blockedUsers,
// blockedVoterSessions) and hiddenByRecipientAt. The "blocked by the other
// person" direction is enforced when votes are cast (interactionService), and
// a block deletes any match between the two users and hides the blocker's
// votes from the blocked user here, so no read ever has to look up who
// blocked the viewer.

function eitherDirection(userId, otherUserId) {
  return {
    $or: [
      { userA: userId, userB: otherUserId },
      { userA: otherUserId, userB: userId },
    ],
  };
}

/** Adds the block without validation; callers have already loaded both users. */
async function applyUserBlock(userId, targetUserId) {
  await Promise.all([
    User.updateOne({ _id: userId }, { $addToSet: { blockedUsers: targetUserId } }),
    // A match would keep showing each person the other's social handles.
    Match.deleteMany(eitherDirection(userId, targetUserId)),
    // The blocker's own votes would otherwise stay in the blocked user's Play
    // queue as cards that can never be answered (voting back is refused).
    Interaction.updateMany(
      { fromUser: userId, toUser: targetUserId, hiddenByRecipientAt: null },
      { $set: { hiddenByRecipientAt: new Date() } }
    ),
  ]);
}

async function blockUser(userId, targetUserId) {
  if (String(userId) === String(targetUserId)) {
    throw new ApiError(400, "You can't block yourself.");
  }
  if (!(await User.exists({ _id: targetUserId }))) {
    throw new ApiError(404, 'Profile not found.');
  }
  await applyUserBlock(userId, targetUserId);
}

async function unblockUser(userId, targetUserId) {
  await User.updateOne({ _id: userId }, { $pull: { blockedUsers: targetUserId } });
}

/**
 * Blocks an anonymous web voter by browser session: their other votes to this
 * user are hidden now, and new votes from the session are refused.
 */
async function blockVoterSession(userId, sessionId) {
  await Promise.all([
    User.updateOne({ _id: userId }, { $addToSet: { blockedVoterSessions: sessionId } }),
    Interaction.updateMany(
      { toUser: userId, 'metadata.sessionId': sessionId, hiddenByRecipientAt: null },
      { $set: { hiddenByRecipientAt: new Date() } }
    ),
  ]);
}

/** Unblocks every anonymous voter. Hidden votes stay hidden. Returns the count. */
async function clearAnonymousBlocks(userId) {
  const previous = await User.findOneAndUpdate(
    { _id: userId },
    { $set: { blockedVoterSessions: [] } },
    { new: false }
  )
    .select('blockedVoterSessions')
    .lean();
  return previous?.blockedVoterSessions?.length || 0;
}

async function listBlocked(userId) {
  const user = await User.findById(userId).select('blockedUsers blockedVoterSessions').lean();
  if (!user) {
    throw new ApiError(404, 'User not found.');
  }

  const blockedIds = user.blockedUsers || [];
  const blockedUsers = blockedIds.length
    ? await User.find({ _id: { $in: blockedIds } })
        .select('name username profileImageUrl')
        .lean()
    : [];
  const byId = new Map(blockedUsers.map((blocked) => [blocked._id.toString(), blocked]));

  return {
    // Most recently blocked first; accounts deleted since are skipped.
    users: [...blockedIds]
      .reverse()
      .map((id) => byId.get(id.toString()))
      .filter(Boolean)
      .map((blocked) => ({
        id: blocked._id.toString(),
        name: blocked.name,
        username: blocked.username || null,
        avatarUrl: blocked.profileImageUrl || null,
      })),
    anonymousBlockedCount: (user.blockedVoterSessions || []).length,
  };
}

/** Removes a vote from its recipient's feed and matches without reporting it. */
async function hideInteraction(userId, interactionId) {
  const result = await Interaction.updateOne(
    { _id: interactionId, toUser: userId },
    { $set: { hiddenByRecipientAt: new Date() } }
  );
  if (!result.matchedCount) {
    throw new ApiError(404, 'Reaction not found.');
  }
}

/**
 * Blocks whoever sent a vote the user received, without filing a report: a
 * named sender by account, an anonymous web voter by browser session. The vote
 * is hidden either way. Returns false when there was nobody to block (an old
 * anonymous vote with no session).
 */
async function blockInteractionSender(userId, interactionId) {
  const interaction = await Interaction.findOne({ _id: interactionId, toUser: userId })
    .select('fromUser metadata.sessionId')
    .lean();
  if (!interaction) {
    throw new ApiError(404, 'Reaction not found.');
  }

  const voterId = interaction.fromUser || null;
  const sessionId = voterId ? null : interaction.metadata?.sessionId || null;
  await Promise.all([
    hideInteraction(userId, interaction._id),
    voterId ? applyUserBlock(userId, voterId) : null,
    sessionId ? blockVoterSession(userId, sessionId) : null,
  ]);
  return Boolean(voterId || sessionId);
}

/**
 * Refuses a web vote from a browser session the recipient blocked or a
 * moderator banned. `targetUser` must include blockedVoterSessions.
 */
async function assertVoterSessionAllowed(targetUser, sessionId) {
  if (!sessionId) return;
  if ((targetUser.blockedVoterSessions || []).includes(sessionId)) {
    throw voteBlockedError();
  }
  if (await BannedVoterSession.exists({ sessionId })) {
    throw voteBlockedError();
  }
}

/**
 * For a push sent after a delay: false once the recipient has hidden the vote
 * or blocked whoever cast it (account or web session), or has been banned.
 */
async function recipientStillWantsVote(interaction) {
  if (interaction.hiddenByRecipientAt) return false;
  const recipient = await User.findById(interaction.toUser)
    .select('isBanned blockedUsers blockedVoterSessions')
    .lean();
  if (!recipient || recipient.isBanned) return false;

  if (interaction.fromUser) {
    const voterId = interaction.fromUser.toString();
    return !(recipient.blockedUsers || []).some((id) => id.toString() === voterId);
  }
  const sessionId = interaction.metadata?.sessionId;
  return !(sessionId && (recipient.blockedVoterSessions || []).includes(sessionId));
}

module.exports = {
  applyUserBlock,
  blockUser,
  unblockUser,
  blockVoterSession,
  clearAnonymousBlocks,
  listBlocked,
  hideInteraction,
  blockInteractionSender,
  assertVoterSessionAllowed,
  recipientStillWantsVote,
};

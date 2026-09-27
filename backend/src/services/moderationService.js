const BannedVoterSession = require('../models/BannedVoterSession');
const Interaction = require('../models/Interaction');
const Match = require('../models/Match');
const PendingInteraction = require('../models/PendingInteraction');
const User = require('../models/User');
const UserReport = require('../models/UserReport');
const ApiError = require('../utils/ApiError');
const logger = require('../utils/logger');
const { REPORT_REASON_LABELS } = require('../utils/safety');
const { forgetAccountStatus } = require('./accountStatusService');
const { serializeReports } = require('./reportService');
const { deleteProfileImage } = require('./userService');

// Moderator actions from the admin panel: act on reports and eject users.

/** Closes the open reports matching `filter` as actioned. */
function resolveOpenReports(filter, resolution) {
  return UserReport.updateMany(
    { ...filter, status: 'open' },
    { $set: { status: 'actioned', resolution, resolvedAt: new Date() } }
  );
}

/**
 * Bans an account: it can no longer sign in or use the API (enforced by the
 * auth middleware and auth service), and its sessions, push tokens, votes,
 * matches, pending reveals and profile photo are removed. Open reports
 * against it are closed. Votes it received are kept in case of an unban.
 */
async function banUser(userId, { reason = null, resolution = 'user_banned' } = {}) {
  const existing = await User.findById(userId).select('profileImageUrl bannedAt').lean();
  if (!existing) {
    throw new ApiError(404, 'User not found.');
  }

  const user = await User.findByIdAndUpdate(
    userId,
    {
      $set: {
        isBanned: true,
        bannedAt: existing.bannedAt || new Date(),
        banReason: reason ? String(reason).slice(0, 500) : null,
        profileImageUrl: null,
        refreshTokens: [],
        deviceTokens: [],
      },
    },
    { new: true }
  );
  forgetAccountStatus(userId);

  await Promise.all([
    Interaction.deleteMany({ fromUser: user._id }),
    Match.deleteMany({ $or: [{ userA: user._id }, { userB: user._id }] }),
    PendingInteraction.deleteMany({ targetUserId: user._id }),
    resolveOpenReports({ reportedUser: user._id }, resolution),
  ]);
  await deleteProfileImage(existing.profileImageUrl, user._id);

  logger.info('User banned.', { userId: user.id, reason: user.banReason });
  return user;
}

/** Lifts a ban. Content removed by the ban is not restored. */
async function unbanUser(userId) {
  const user = await User.findByIdAndUpdate(
    userId,
    { $set: { isBanned: false, bannedAt: null, banReason: null } },
    { new: true }
  );
  if (!user) {
    throw new ApiError(404, 'User not found.');
  }
  forgetAccountStatus(userId);
  logger.info('User unbanned.', { userId: user.id });
  return user;
}

/**
 * Bans an anonymous web voter by browser session: its anonymous votes and
 * pending reveals are deleted and new votes from it are refused
 * (POST /anonymous-response answers 403 VOTE_BLOCKED).
 */
async function banVoterSession(sessionId, { reason = null, reportId = null, resolution = 'session_banned' } = {}) {
  try {
    await BannedVoterSession.updateOne(
      { sessionId },
      { $setOnInsert: { sessionId, reason, report: reportId } },
      { upsert: true }
    );
  } catch (error) {
    // A concurrent ban of the same session already inserted it.
    if (error?.code !== 11000) throw error;
  }

  await Promise.all([
    Interaction.deleteMany({ fromUser: null, 'metadata.sessionId': sessionId }),
    PendingInteraction.deleteMany({ sessionId }),
    resolveOpenReports({ anonymousSessionId: sessionId }, resolution),
  ]);
  logger.info('Anonymous voter session banned.', { reportId: reportId && String(reportId) });
}

/** Removes a reported profile's photo (profile shows the default avatar). */
async function removeProfilePhoto(userId) {
  const user = await User.findById(userId).select('profileImageUrl').lean();
  if (!user) return;
  await User.updateOne({ _id: userId }, { $set: { profileImageUrl: null } });
  await deleteProfileImage(user.profileImageUrl, userId);
}

/**
 * Applies a moderator's decision to a report:
 *  - remove_content: delete the reported vote, or the reported profile's photo;
 *  - remove_and_ban: remove the content and ban the offender (account, or web
 *    session for an anonymous vote), closing their other open reports too;
 *  - dismiss: close the report without action.
 */
async function actOnReport(reportId, { action, note = null }) {
  const report = await UserReport.findById(reportId);
  if (!report) {
    throw new ApiError(404, 'Report not found.');
  }

  if (action !== 'dismiss') {
    const targetType = report.targetType || 'interaction';
    if (targetType === 'interaction' && report.interaction) {
      await Interaction.deleteOne({ _id: report.interaction });
    } else if (targetType === 'profile' && report.reportedUser && action === 'remove_content') {
      // remove_and_ban removes the photo as part of the ban.
      await removeProfilePhoto(report.reportedUser);
    }

    if (action === 'remove_and_ban') {
      const reason = `Report ${report.id}: ${REPORT_REASON_LABELS[report.reason] || 'objectionable content'}`;
      if (report.reportedUser) {
        try {
          await banUser(report.reportedUser, { reason, resolution: 'remove_and_ban' });
        } catch (error) {
          // The account was deleted since: nothing left to ban.
          if (error?.statusCode !== 404) throw error;
        }
      } else if (report.anonymousSessionId) {
        await banVoterSession(report.anonymousSessionId, {
          reason,
          reportId: report._id,
          resolution: 'remove_and_ban',
        });
      }
    }
  }

  report.status = action === 'dismiss' ? 'dismissed' : 'actioned';
  report.resolution = action;
  report.resolvedAt = new Date();
  report.adminNote = note ? String(note).trim().slice(0, 1000) || null : null;
  await report.save();

  const [serialized] = await serializeReports([report]);
  return serialized;
}

module.exports = {
  banUser,
  unbanUser,
  banVoterSession,
  actOnReport,
};

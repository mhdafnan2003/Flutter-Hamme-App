const BannedVoterSession = require('../models/BannedVoterSession');
const Interaction = require('../models/Interaction');
const User = require('../models/User');
const UserReport = require('../models/UserReport');
const ApiError = require('../utils/ApiError');
const logger = require('../utils/logger');
const { normalizeReportReason, normalizeReportDetails } = require('../utils/safety');
const blockService = require('./blockService');
const { notifyNewReport } = require('./moderationAlertService');

// Reports must be acted on within 24 hours (App Store Guideline 1.2).
const OVERDUE_AFTER_MS = 24 * 60 * 60 * 1000;
const SNAPSHOT_FIELDS = 'name username email shareCode profileImageUrl';

function snapshotUser(user) {
  return {
    name: user.name || '',
    username: user.username || '',
    email: user.email || '',
    shareCode: user.shareCode || '',
    avatarUrl: user.profileImageUrl || null,
  };
}

/**
 * Saves a report, or returns the reporter's open report on the same target (a
 * double tap or retry) instead of creating a duplicate.
 */
async function saveReport(fields, sameTarget) {
  const existing = await UserReport.findOne({
    ...sameTarget,
    reporter: fields.reporter,
    status: 'open',
  });
  if (existing) return { report: existing, created: false };

  try {
    return { report: await UserReport.create(fields), created: true };
  } catch (error) {
    if (error?.code !== 11000) throw error;
  }

  // The only unique index a report can hit is the legacy one-report-per-user
  // index. It is dropped after connecting, but an older deployment starting up
  // can recreate it: drop it again and retry once.
  await UserReport.dropLegacyIndexes().catch((error) => {
    logger.error(`Could not drop the legacy UserReport index: ${error.message}`);
  });
  try {
    return { report: await UserReport.create(fields), created: true };
  } catch (error) {
    if (error?.code !== 11000) throw error;
    // Still blocked. The hide/block has been applied, so point the user at the
    // report holding the slot rather than failing their report.
    const holder = await UserReport.findOne({
      reporter: fields.reporter,
      reportedUser: fields.reportedUser || null,
    });
    if (!holder) throw error;
    logger.error('New report collided with the legacy UserReport index.', {
      reporter: String(fields.reporter),
      existingReport: holder.id,
    });
    return { report: holder, created: false };
  }
}

/**
 * Reports a vote the reporter received, named or anonymous. The vote is always
 * hidden from the reporter at once. With `block`, its sender is blocked: a
 * named sender by account, an anonymous web voter by browser session (which
 * also hides that session's other votes). The result never identifies the voter.
 */
async function reportInteraction({ reporterId, interactionId, reason, details, block = true }) {
  const interaction = await Interaction.findOne({ _id: interactionId, toUser: reporterId }).lean();
  if (!interaction) {
    throw new ApiError(404, 'Reaction not found.');
  }

  const voterId = interaction.fromUser || null;
  const sessionId = voterId ? null : interaction.metadata?.sessionId || null;
  const [reporter, voter] = await Promise.all([
    User.findById(reporterId).select(SNAPSHOT_FIELDS).lean(),
    voterId ? User.findById(voterId).select(SNAPSHOT_FIELDS).lean() : null,
  ]);
  if (!reporter) {
    throw new ApiError(404, 'User not found.');
  }

  const safetyActions = [blockService.hideInteraction(reporter._id, interaction._id)];
  let blocked = false;
  if (block && voterId) {
    safetyActions.push(blockService.applyUserBlock(reporter._id, voterId));
    blocked = true;
  } else if (block && sessionId) {
    safetyActions.push(blockService.blockVoterSession(reporter._id, sessionId));
    blocked = true;
  }

  const [saved] = await Promise.all([
    saveReport(
      {
        reporter: reporter._id,
        reportedUser: voterId,
        targetType: 'interaction',
        interaction: interaction._id,
        interactionType: interaction.type,
        reason: normalizeReportReason(reason),
        details: normalizeReportDetails(details),
        anonymous: !voterId,
        anonymousSessionId: sessionId,
        reporterSnapshot: snapshotUser(reporter),
        reportedUserSnapshot: voter ? snapshotUser(voter) : null,
      },
      { interaction: interaction._id }
    ),
    ...safetyActions,
  ]);

  if (saved.created) {
    await notifyNewReport(saved.report);
  }
  return { reportId: saved.report.id, blocked };
}

/** Reports another user's profile (name, photo or social handles). */
async function reportProfile({ reporterId, reportedUserId, reason, details, block = true }) {
  if (String(reporterId) === String(reportedUserId)) {
    throw new ApiError(400, "You can't report yourself.");
  }

  const [reporter, reported] = await Promise.all([
    User.findById(reporterId).select(SNAPSHOT_FIELDS).lean(),
    User.findById(reportedUserId).select(SNAPSHOT_FIELDS).lean(),
  ]);
  if (!reporter) {
    throw new ApiError(404, 'User not found.');
  }
  if (!reported) {
    throw new ApiError(404, 'Profile not found.');
  }

  const [saved] = await Promise.all([
    saveReport(
      {
        reporter: reporter._id,
        reportedUser: reported._id,
        targetType: 'profile',
        reason: normalizeReportReason(reason),
        details: normalizeReportDetails(details),
        reporterSnapshot: snapshotUser(reporter),
        reportedUserSnapshot: snapshotUser(reported),
      },
      { targetType: 'profile', reportedUser: reported._id }
    ),
    block ? blockService.applyUserBlock(reporter._id, reported._id) : null,
  ]);

  if (saved.created) {
    await notifyNewReport(saved.report);
  }
  return { reportId: saved.report.id, blocked: Boolean(block) };
}

function snapshotOrEmpty(snapshot) {
  return {
    name: snapshot?.name || '',
    username: snapshot?.username || '',
    email: snapshot?.email || '',
    shareCode: snapshot?.shareCode || '',
    avatarUrl: snapshot?.avatarUrl || null,
  };
}

/**
 * Admin view of reports (documents or lean objects). Reports created before
 * moderation actions existed lack reason/targetType/etc. and get defaults.
 */
async function serializeReports(reports) {
  const plain = reports.map((report) =>
    typeof report.toObject === 'function' ? report.toObject() : report
  );
  const userIds = [...new Set(plain.map((report) => report.reportedUser?.toString()).filter(Boolean))];
  const sessionIds = [...new Set(plain.map((report) => report.anonymousSessionId).filter(Boolean))];
  const [bannedUsers, bannedSessions] = await Promise.all([
    userIds.length
      ? User.find({ _id: { $in: userIds }, isBanned: true }).select('_id').lean()
      : [],
    sessionIds.length
      ? BannedVoterSession.find({ sessionId: { $in: sessionIds } }).select('sessionId').lean()
      : [],
  ]);
  const bannedUserIds = new Set(bannedUsers.map((user) => user._id.toString()));
  const bannedSessionIds = new Set(bannedSessions.map((session) => session.sessionId));
  const now = Date.now();

  return plain.map((report) => {
    const reportedUserId = report.reportedUser ? report.reportedUser.toString() : null;
    const status = report.status || 'open';
    return {
      id: report._id.toString(),
      status,
      reason: report.reason || 'other',
      details: report.details || '',
      targetType: report.targetType || 'interaction',
      anonymous: Boolean(report.anonymous),
      anonymousSessionId: report.anonymousSessionId || null,
      reporterId: report.reporter.toString(),
      reportedUserId,
      interactionId: report.interaction ? report.interaction.toString() : null,
      interactionType: report.interactionType || null,
      reporter: snapshotOrEmpty(report.reporterSnapshot),
      reportedUser: report.reportedUserSnapshot ? snapshotOrEmpty(report.reportedUserSnapshot) : null,
      // For an anonymous report: whether the voter's web session is banned.
      reportedUserBanned: reportedUserId
        ? bannedUserIds.has(reportedUserId)
        : bannedSessionIds.has(report.anonymousSessionId),
      createdAt: report.createdAt,
      resolvedAt: report.resolvedAt || null,
      resolution: report.resolution || null,
      adminNote: report.adminNote || null,
      overdue: status === 'open' && now - new Date(report.createdAt).getTime() > OVERDUE_AFTER_MS,
    };
  });
}

const STATUS_FILTERS = {
  open: { status: 'open' },
  // `reviewed` is the pre-moderation equivalent of actioned.
  actioned: { status: { $in: ['actioned', 'reviewed'] } },
  dismissed: { status: 'dismissed' },
  all: {},
};

async function listReports({ status = 'open', page = 1, limit = 25 } = {}) {
  const statusKey = STATUS_FILTERS[status] ? status : 'open';
  const filter = STATUS_FILTERS[statusKey];
  const safeLimit = Math.min(Math.max(Number(limit) || 25, 1), 100);
  const safePage = Math.max(Number(page) || 1, 1);
  const skip = (safePage - 1) * safeLimit;
  // The open queue is oldest first, so reports nearest to (or past) the
  // 24-hour deadline are always on the first page.
  const sort = statusKey === 'open' ? { createdAt: 1 } : { createdAt: -1 };
  const overdueBefore = new Date(Date.now() - OVERDUE_AFTER_MS);

  const [reports, total, openCount, overdueCount] = await Promise.all([
    UserReport.find(filter).sort(sort).skip(skip).limit(safeLimit).lean(),
    UserReport.countDocuments(filter),
    UserReport.countDocuments({ status: 'open' }),
    UserReport.countDocuments({ status: 'open', createdAt: { $lt: overdueBefore } }),
  ]);

  return {
    reports: await serializeReports(reports),
    total,
    page: safePage,
    limit: safeLimit,
    pages: Math.ceil(total / safeLimit) || 1,
    openCount,
    overdueCount,
  };
}

module.exports = {
  reportInteraction,
  reportProfile,
  listReports,
  serializeReports,
};

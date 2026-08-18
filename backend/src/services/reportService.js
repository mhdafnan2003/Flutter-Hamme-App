const Interaction = require('../models/Interaction');
const User = require('../models/User');
const UserReport = require('../models/UserReport');
const ApiError = require('../utils/ApiError');

function snapshotUser(user) {
  return {
    name: user.name || '',
    username: user.username || '',
    email: user.email || '',
    shareCode: user.shareCode || '',
    avatarUrl: user.profileImageUrl || null,
  };
}

async function createReport({ reporterId, interactionId }) {
  const interaction = await Interaction.findById(interactionId);
  if (!interaction || interaction.toUser.toString() !== reporterId.toString()) {
    throw new ApiError(404, 'Reaction not found.');
  }
  if (!interaction.fromUser) {
    throw new ApiError(400, 'Anonymous reactions cannot be linked to a user report.');
  }

  const [reporter, reportedUser] = await Promise.all([
    User.findById(reporterId).select('+profileImageUrl'),
    User.findById(interaction.fromUser).select('+profileImageUrl'),
  ]);
  if (!reporter || !reportedUser) {
    throw new ApiError(404, 'User not found.');
  }

  await User.updateOne(
    { _id: reporter._id },
    { $addToSet: { blockedUsers: reportedUser._id } }
  );

  try {
    const report = await UserReport.create({
      reporter: reporter._id,
      reportedUser: reportedUser._id,
      interaction: interaction._id,
      interactionType: interaction.type,
      reporterSnapshot: snapshotUser(reporter),
      reportedUserSnapshot: snapshotUser(reportedUser),
    });
    return report;
  } catch (error) {
    if (error?.code === 11000) {
      return UserReport.findOne({
        reporter: reporter._id,
        reportedUser: reportedUser._id,
      });
    }
    throw error;
  }
}

async function listReports({ page = 1, limit = 25 } = {}) {
  const safeLimit = Math.min(Math.max(Number(limit) || 25, 1), 100);
  const safePage = Math.max(Number(page) || 1, 1);
  const skip = (safePage - 1) * safeLimit;
  const [reports, total] = await Promise.all([
    UserReport.find().sort({ createdAt: -1 }).skip(skip).limit(safeLimit).lean(),
    UserReport.countDocuments(),
  ]);

  return {
    reports: reports.map((report) => ({
      id: report._id.toString(),
      reporterId: report.reporter.toString(),
      reportedUserId: report.reportedUser.toString(),
      interactionId: report.interaction.toString(),
      interactionType: report.interactionType,
      reporter: report.reporterSnapshot,
      reportedUser: report.reportedUserSnapshot,
      status: report.status,
      createdAt: report.createdAt,
    })),
    total,
    page: safePage,
    limit: safeLimit,
    pages: Math.ceil(total / safeLimit) || 1,
  };
}

module.exports = { createReport, listReports };

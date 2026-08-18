const mongoose = require('mongoose');

const userSnapshotSchema = new mongoose.Schema(
  {
    name: { type: String, default: '' },
    username: { type: String, default: '' },
    email: { type: String, default: '' },
    shareCode: { type: String, default: '' },
    avatarUrl: { type: String, default: null },
  },
  { _id: false }
);

const userReportSchema = new mongoose.Schema(
  {
    reporter: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    reportedUser: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    interaction: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Interaction',
      required: true,
    },
    interactionType: {
      type: String,
      enum: ['crush', 'friend', 'frenemy'],
      required: true,
    },
    reporterSnapshot: { type: userSnapshotSchema, required: true },
    reportedUserSnapshot: { type: userSnapshotSchema, required: true },
    status: {
      type: String,
      enum: ['open', 'reviewed', 'dismissed'],
      default: 'open',
      index: true,
    },
  },
  { timestamps: true }
);

// A user only needs one active moderation report against another account.
userReportSchema.index({ reporter: 1, reportedUser: 1 }, { unique: true });
userReportSchema.index({ createdAt: -1 });

module.exports = mongoose.model('UserReport', userReportSchema);

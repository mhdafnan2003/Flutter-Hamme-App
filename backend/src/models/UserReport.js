const mongoose = require('mongoose');

const { REPORT_REASONS, REPORT_DETAILS_MAX_LENGTH } = require('../utils/safety');

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

// Reports used to be unique per (reporter, reportedUser). Anonymous reports have
// no reportedUser, so that index rejects a second anonymous report by the same
// person. Removed from the schema and dropped in production by dropLegacyIndexes.
const LEGACY_UNIQUE_INDEX = 'reporter_1_reportedUser_1';

const userReportSchema = new mongoose.Schema(
  {
    reporter: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    // Account behind the reported content; null for an anonymous web vote.
    reportedUser: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
      index: true,
    },
    // Reports created before profile reports existed have no targetType and
    // are interaction reports.
    targetType: {
      type: String,
      enum: ['interaction', 'profile'],
      default: 'interaction',
    },
    interaction: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Interaction',
      default: null,
    },
    interactionType: {
      type: String,
      enum: ['crush', 'friend', 'frenemy', null],
      default: null,
    },
    reason: {
      type: String,
      enum: REPORT_REASONS,
      default: 'other',
    },
    details: {
      type: String,
      default: '',
      trim: true,
      maxlength: REPORT_DETAILS_MAX_LENGTH,
    },
    // An anonymous web voter is only known by their browser session id.
    anonymous: {
      type: Boolean,
      default: false,
    },
    anonymousSessionId: {
      type: String,
      default: null,
    },
    reporterSnapshot: { type: userSnapshotSchema, required: true },
    reportedUserSnapshot: { type: userSnapshotSchema, default: null },
    // `reviewed` only appears on reports created before moderation actions.
    status: {
      type: String,
      enum: ['open', 'actioned', 'dismissed', 'reviewed'],
      default: 'open',
      index: true,
    },
    resolvedAt: {
      type: Date,
      default: null,
    },
    // remove_and_ban | remove_content | dismiss, or user_banned /
    // session_banned / account_deleted when closed as a side effect.
    resolution: {
      type: String,
      default: null,
    },
    adminNote: {
      type: String,
      default: null,
      trim: true,
      maxlength: 1000,
    },
  },
  { timestamps: true }
);

userReportSchema.index({ createdAt: -1 });
userReportSchema.index({ status: 1, createdAt: -1 });

/**
 * Drops the legacy (reporter, reportedUser) unique index. Runs in the
 * background after connecting, and again on demand if an insert still hits it
 * (an older deployment starting up can recreate it). Resolves true if dropped.
 */
userReportSchema.statics.dropLegacyIndexes = async function dropLegacyIndexes() {
  try {
    await this.collection.dropIndex(LEGACY_UNIQUE_INDEX);
    return true;
  } catch (error) {
    // IndexNotFound (27) / NamespaceNotFound (26): nothing to drop.
    if ([26, 27].includes(error?.code) || ['IndexNotFound', 'NamespaceNotFound'].includes(error?.codeName)) {
      return false;
    }
    throw error;
  }
};

module.exports = mongoose.model('UserReport', userReportSchema);

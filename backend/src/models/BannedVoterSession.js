const mongoose = require('mongoose');

// A web voter's browser session (the `sessionId` the vote page keeps in
// localStorage) banned by a moderator. Votes from it are refused.
const bannedVoterSessionSchema = new mongoose.Schema(
  {
    sessionId: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    reason: {
      type: String,
      default: null,
      trim: true,
      maxlength: 500,
    },
    report: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'UserReport',
      default: null,
    },
  },
  { timestamps: { createdAt: 'bannedAt', updatedAt: false } }
);

module.exports = mongoose.model('BannedVoterSession', bannedVoterSessionSchema);

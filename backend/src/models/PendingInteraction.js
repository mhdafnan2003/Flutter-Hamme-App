const mongoose = require('mongoose');

const pendingInteractionSchema = new mongoose.Schema(
  {
    targetUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    type: {
      type: String,
      enum: ['friend', 'crush', 'frenemy'],
      required: true,
    },
    source: {
      type: String,
      default: 'web_local',
    },
    sessionId: {
      type: String,
      default: null,
      index: true,
    },
    shareCode: {
      type: String,
      default: null,
      index: true,
    },
    status: {
      type: String,
      enum: ['pending', 'finalized', 'expired'],
      default: 'pending',
    },
    deepLinkToken: {
      type: String,
      required: true,
      unique: true,
    },
    expiresAt: {
      type: Date,
      required: true,
    },
  },
  {
    timestamps: true,
    toJSON: {
      virtuals: true,
      transform: function (_, ret) {
        ret.id = ret._id;
        delete ret._id;
        delete ret.__v;
      },
    },
  }
);

pendingInteractionSchema.index({ targetUserId: 1, sessionId: 1, type: 1, status: 1 });
// TTL index: MongoDB removes pending docs once `expiresAt` passes. This replaces
// the unreliable in-process setTimeout and stops the collection growing unbounded.
pendingInteractionSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model('PendingInteraction', pendingInteractionSchema);

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
      enum: ['friend', 'crush', 'frenemy', 'ameny'],
      required: true,
    },
    source: {
      type: String,
      default: 'web_local',
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

module.exports = mongoose.model('PendingInteraction', pendingInteractionSchema);

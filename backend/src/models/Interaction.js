const mongoose = require('mongoose');

const interactionSchema = new mongoose.Schema(
  {
    fromUser: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: false,
      default: null,
      index: true,
    },
    toUser: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    type: {
      type: String,
      enum: ['crush', 'friend', 'frenemy'],
      required: true,
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
    // Set when the recipient hides, reports or blocks this vote. Hidden votes
    // never reach the recipient's feed or matches. Absent (not null) otherwise,
    // so `{ hiddenByRecipientAt: null }` matches every visible vote.
    hiddenByRecipientAt: {
      type: Date,
    },
  },
  {
    timestamps: { createdAt: true, updatedAt: false },
    toJSON: {
      versionKey: false,
      transform: (_, ret) => {
        ret.id = ret._id.toString();
        ret.fromUser = ret.fromUser ? ret.fromUser.toString() : null;
        ret.toUser = ret.toUser.toString();
        delete ret._id;
        // The voter must not learn that the recipient hid their vote.
        delete ret.hiddenByRecipientAt;
        return ret;
      },
    },
  }
);

interactionSchema.index(
  { fromUser: 1, toUser: 1, createdAt: -1 },
  { partialFilterExpression: { fromUser: { $type: 'objectId' } } }
);
interactionSchema.index({ toUser: 1, type: 1, createdAt: -1 });
interactionSchema.index({ fromUser: 1, createdAt: -1 });
interactionSchema.index({ 'metadata.sessionId': 1, toUser: 1, createdAt: -1 }, { sparse: true });

module.exports = mongoose.model('Interaction', interactionSchema);

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
        return ret;
      },
    },
  }
);

interactionSchema.index(
  { fromUser: 1, toUser: 1, type: 1 },
  { unique: true, partialFilterExpression: { fromUser: { $type: 'objectId' } } }
);
interactionSchema.index({ toUser: 1, type: 1, createdAt: -1 });
interactionSchema.index({ fromUser: 1, createdAt: -1 });

module.exports = mongoose.model('Interaction', interactionSchema);

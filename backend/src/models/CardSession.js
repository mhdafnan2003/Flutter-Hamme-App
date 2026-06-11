const mongoose = require('mongoose');

const cardSessionSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
    },
    count: { type: Number, default: 0, min: 0 },
    windowStartedAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

module.exports = mongoose.model('CardSession', cardSessionSchema);

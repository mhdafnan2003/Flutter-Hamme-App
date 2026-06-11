const mongoose = require('mongoose');

const appConfigSchema = new mongoose.Schema(
  {
    freeUserCardLimit: { type: Number, default: 10, min: 1, max: 1000 },
    cardCooldownMinutes: { type: Number, default: 5, min: 1, max: 1440 },
  },
  { timestamps: true }
);

module.exports = mongoose.model('AppConfig', appConfigSchema);

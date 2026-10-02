const mongoose = require('mongoose');

// A stable record serializes claims and transfers of each store subscription.
// Store tokens are private and never returned to the client.
const schema = new mongoose.Schema({
  _id: { type: String },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  revision: { type: Number, default: 0 },
}, { timestamps: true });

module.exports = mongoose.model('BillingOwnership', schema);

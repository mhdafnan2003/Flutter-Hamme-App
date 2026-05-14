const mongoose = require('mongoose');

const billingEntitlementSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    platform: {
      type: String,
      required: true,
      enum: ['android'],
      index: true,
    },
    productId: {
      type: String,
      required: true,
      trim: true,
    },
    purchaseToken: {
      type: String,
      required: true,
      trim: true,
      unique: true,
      index: true,
    },
    orderId: {
      type: String,
      default: null,
      trim: true,
    },
    status: {
      type: String,
      required: true,
      default: 'inactive',
      enum: ['active', 'grace', 'hold', 'paused', 'canceled', 'expired', 'inactive'],
      index: true,
    },
    isAutoRenewing: {
      type: Boolean,
      default: false,
    },
    expiryTime: {
      type: Date,
      default: null,
      index: true,
    },
    lastVerifiedAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
    verificationPayload: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
    source: {
      type: String,
      required: true,
      default: 'google_play',
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

billingEntitlementSchema.index({ userId: 1, platform: 1, status: 1 });

module.exports = mongoose.model('BillingEntitlement', billingEntitlementSchema);

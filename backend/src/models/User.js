const mongoose = require('mongoose');

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const usernamePattern = /^[a-z0-9._]+$/;

const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
      minlength: 2,
      maxlength: 80,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      match: emailPattern,
    },
    instagramId: {
      type: String,
      required: false,
      default: '',
      trim: true,
      maxlength: 100,
    },
    snapchatId: {
      type: String,
      required: false,
      default: '',
      trim: true,
      maxlength: 100,
    },
    username: {
      type: String,
      sparse: true,
      trim: true,
      lowercase: true,
      minlength: 2,
      maxlength: 32,
      match: usernamePattern,
    },
    passwordHash: {
      type: String,
      required: true,
      select: false,
    },
    profileImageUrl: {
      type: String,
      default: null,
      trim: true,
    },
    isPro: {
      type: Boolean,
      default: false,
      index: true,
    },
    // Pro can come from a complimentary admin grant, an active store
    // subscription, or both. `isPro` remains the denormalized effective value
    // returned to older app versions.
    adminPro: {
      type: Boolean,
      default: false,
    },
    storeProActive: {
      type: Boolean,
      default: false,
      index: true,
    },
    proProductId: {
      type: String,
      default: null,
    },
    proPlatform: {
      type: String,
      default: null,
    },
    proPurchaseToken: {
      type: String,
      default: null,
      select: false,
    },
    proSubscriptionState: {
      type: String,
      default: null,
    },
    proExpiryAt: {
      type: Date,
      default: null,
    },
    proAutoRenewing: {
      type: Boolean,
      default: null,
    },
    proLastVerifiedAt: {
      type: Date,
      default: null,
    },
    proUpdatedAt: {
      type: Date,
      default: null,
    },
    birthday: {
      type: Date,
      default: null,
    },
    deviceId: {
      type: String,
      default: null,
      trim: true,
      index: true,
    },
    isGuestUser: {
      type: Boolean,
      default: false,
      index: true,
    },
    shareCode: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    refreshTokens: {
      type: [String],
      default: [],
      select: false,
    },
    blockedUsers: {
      type: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
      default: [],
      select: false,
      index: true,
    },
    deviceTokens: {
      type: [
        {
          _id: false,
          token: { type: String, required: true },
          platform: { type: String, enum: ['ios', 'android'], required: true },
          updatedAt: { type: Date, default: Date.now },
        },
      ],
      default: [],
      select: false,
    },
    // Terms of Use / community guidelines acceptance. The app treats terms as
    // accepted when termsVersion >= its current version.
    termsAcceptedAt: {
      type: Date,
      default: null,
    },
    termsVersion: {
      type: Number,
      default: null,
    },
    // Moderation ban. A banned account cannot sign in or call the API and its
    // public profile is hidden (see moderationService.banUser).
    isBanned: {
      type: Boolean,
      default: false,
      index: true,
    },
    bannedAt: {
      type: Date,
      default: null,
    },
    banReason: {
      type: String,
      default: null,
      trim: true,
      maxlength: 500,
    },
    // Web voter session ids (from the vote page's localStorage) whose anonymous
    // votes this user blocked. Votes from these sessions are refused.
    blockedVoterSessions: {
      type: [String],
      default: [],
      select: false,
    },
    // Push notifications the user wants (Settings → Notifications); checked
    // by pushService before sending. `messages` covers new votes on their
    // poll (Inbox activity).
    notificationPrefs: {
      matches: { type: Boolean, default: true },
      messages: { type: Boolean, default: true },
      reminders: { type: Boolean, default: true },
    },
  },
  {
    timestamps: true,
    toJSON: {
      versionKey: false,
      transform: (_, ret) => {
        ret.id = ret._id.toString();
        // Present pre-split admin grants correctly until each legacy record is
        // next updated and migrated into `adminPro`.
        if (!ret.adminPro && ret.isPro && ret.proPlatform === 'admin') {
          ret.adminPro = true;
        }
        // Expose the profile image as `avatarUrl` (single canonical field).
        ret.avatarUrl = ret.profileImageUrl ?? null;
        delete ret._id;
        delete ret.passwordHash;
        delete ret.refreshTokens;
        delete ret.blockedUsers;
        delete ret.blockedVoterSessions;
        delete ret.profileImageUrl;
        delete ret.proPurchaseToken;
        // Served by GET /profiles/me/notifications instead.
        delete ret.notificationPrefs;
        return ret;
      },
    },
  }
);

// A Google purchase token may belong to only one Hamme account. The partial
// index avoids indexing the many users whose token is null.
userSchema.index(
  { proPurchaseToken: 1 },
  {
    unique: true,
    partialFilterExpression: { proPurchaseToken: { $type: 'string' } },
  }
);

// registerDeviceToken moves a push token off any other account by querying
// this field; without an index that scanned the whole users collection.
userSchema.index({ 'deviceTokens.token': 1 });

module.exports = mongoose.model('User', userSchema);

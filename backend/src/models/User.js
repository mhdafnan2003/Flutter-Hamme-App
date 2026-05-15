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
  },
  {
    timestamps: true,
    toJSON: {
      versionKey: false,
      transform: (_, ret) => {
        ret.id = ret._id.toString();
        delete ret._id;
        delete ret.passwordHash;
        delete ret.refreshTokens;
        return ret;
      },
    },
  }
);

module.exports = mongoose.model('User', userSchema);

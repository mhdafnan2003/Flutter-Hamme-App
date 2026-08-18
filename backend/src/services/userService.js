const User = require('../models/User');
const Interaction = require('../models/Interaction');
const Match = require('../models/Match');
const PendingInteraction = require('../models/PendingInteraction');
const CardSession = require('../models/CardSession');
const ApiError = require('../utils/ApiError');
const buildDefaultAvatarUrl = require('../utils/defaultAvatar');
const logger = require('../utils/logger');
const { v2: cloudinary } = require('cloudinary');
const env = require('../config/env');

const cloudinaryEnabled =
  Boolean(env.cloudinaryCloudName) &&
  Boolean(env.cloudinaryApiKey) &&
  Boolean(env.cloudinaryApiSecret);

if (cloudinaryEnabled) {
  cloudinary.config({
    cloud_name: env.cloudinaryCloudName,
    api_key: env.cloudinaryApiKey,
    api_secret: env.cloudinaryApiSecret,
  });
}

function cloudinaryPublicId(imageUrl) {
  if (!imageUrl || !imageUrl.includes('res.cloudinary.com')) return null;
  const match = imageUrl.match(/\/image\/upload\/(?:v\d+\/)?(.+?)(?:\.[a-z0-9]+)?(?:\?.*)?$/i);
  return match ? decodeURIComponent(match[1]) : null;
}

async function deleteProfileImage(imageUrl, userId) {
  const publicId = cloudinaryPublicId(imageUrl);
  if (!cloudinaryEnabled || !publicId) return;
  try {
    await cloudinary.uploader.destroy(publicId, { resource_type: 'image' });
  } catch (error) {
    // Deletion of the user record must never fail because an already-public
    // image has disappeared. Keep a server-side audit trail for retry.
    logger.error('Could not delete profile image during account deletion', {
      userId: userId.toString(),
      message: error.message,
    });
  }
}

async function getMe(userId) {
  const user = await User.findById(userId);
  if (!user) {
    throw new ApiError(404, 'User not found.');
  }

  return user;
}

async function updateMe(userId, updates) {
  const normalizedUsername =
    typeof updates.username === 'string'
      ? updates.username.trim().toLowerCase().replace(/^@+/, '')
      : undefined;
  if (
    normalizedUsername !== undefined &&
    normalizedUsername.length > 0 &&
    !/^[a-z0-9._]+$/.test(normalizedUsername)
  ) {
    throw new ApiError(
      400,
      'Username can only contain lowercase letters, numbers, dot and underscore.'
    );
  }

  const allowedUpdates = {
    name: updates.name,
    instagramId: updates.instagramId,
    snapchatId: updates.snapchatId,
    profileImageUrl: updates.avatarUrl ?? updates.profileImageUrl,
    username: normalizedUsername || updates.username,
  };

  // Drop undefined keys so we never overwrite existing values with `undefined`.
  Object.keys(allowedUpdates).forEach((key) => {
    if (allowedUpdates[key] === undefined) delete allowedUpdates[key];
  });

  const user = await User.findByIdAndUpdate(userId, allowedUpdates, {
    new: true,
    runValidators: true,
  });

  if (!user) {
    throw new ApiError(404, 'User not found.');
  }

  return user;
}

/** Permanently removes a user and all app data that references that user. */
async function deleteMe(userId) {
  const user = await User.findById(userId).select('+profileImageUrl');
  if (!user) {
    throw new ApiError(404, 'Account not found.');
  }

  await Promise.all([
    Interaction.deleteMany({ $or: [{ fromUser: user._id }, { toUser: user._id }] }),
    Match.deleteMany({ $or: [{ userA: user._id }, { userB: user._id }, { triggeredBy: user._id }] }),
    PendingInteraction.deleteMany({ targetUserId: user._id }),
    CardSession.deleteMany({ userId: user._id }),
    User.updateMany(
      { blockedUsers: user._id },
      { $pull: { blockedUsers: user._id } }
    ),
  ]);
  await User.deleteOne({ _id: user._id });
  await deleteProfileImage(user.profileImageUrl, user._id);
}

async function getPublicProfile(identifier) {  const rawValue = (identifier || '').trim();
  const normalizedValue = rawValue.toLowerCase();
  if (!rawValue) {
    throw new ApiError(404, 'Profile not found.');
  }

  const user = await User.findOne({ shareCode: { $in: [rawValue, normalizedValue] } });
  if (user) {
    if (!user.profileImageUrl) {
      user.profileImageUrl = buildDefaultAvatarUrl(user.name);
      await user.save();
    }
    return { user, matchedBy: 'shareCode' };
  }

  throw new ApiError(404, 'Profile not found.');
}

async function listUsers({ search = '', page = 1, limit = 25 } = {}) {
  const safeLimit = Math.min(Math.max(Number(limit) || 25, 1), 100);
  const safePage = Math.max(Number(page) || 1, 1);
  const skip = (safePage - 1) * safeLimit;

  const filter = {};
  const term = (search || '').trim();
  if (term) {
    const escaped = term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp(escaped, 'i');
    filter.$or = [
      { name: regex },
      { username: regex },
      { email: regex },
      { shareCode: regex },
    ];
  }

  const [users, total] = await Promise.all([
    User.find(filter).sort({ createdAt: -1 }).skip(skip).limit(safeLimit),
    User.countDocuments(filter),
  ]);

  return {
    users: users.map((user) => user.toJSON()),
    total,
    page: safePage,
    limit: safeLimit,
    pages: Math.ceil(total / safeLimit) || 1,
  };
}

async function setProStatus(userId, isPro) {
  const user = await User.findById(userId);
  if (!user) {
    throw new ApiError(404, 'User not found.');
  }

  user.adminPro = Boolean(isPro);
  // Preserve a paid subscription when an admin grant is removed.
  user.isPro = user.adminPro || user.storeProActive;
  user.proUpdatedAt = new Date();
  await user.save();

  return user;
}

module.exports = {
  getMe,
  updateMe,
  deleteMe,
  getPublicProfile,
  listUsers,
  setProStatus,
};

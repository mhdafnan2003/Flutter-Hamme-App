const User = require('../models/User');
const ApiError = require('../utils/ApiError');
const buildDefaultAvatarUrl = require('../utils/defaultAvatar');

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
  const update = {
    isPro: Boolean(isPro),
    proUpdatedAt: new Date(),
  };
  if (!isPro) {
    update.proProductId = null;
    update.proPlatform = null;
    update.proPurchaseToken = null;
  } else {
    update.proProductId = 'admin_grant';
    update.proPlatform = 'admin';
  }

  const user = await User.findByIdAndUpdate(userId, update, { new: true });
  if (!user) {
    throw new ApiError(404, 'User not found.');
  }
  return user;
}

module.exports = {
  getMe,
  updateMe,
  getPublicProfile,
  listUsers,
  setProStatus,
};

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
    profileImageUrl: updates.profileImageUrl,
    username: normalizedUsername || updates.username,
  };

  const user = await User.findByIdAndUpdate(userId, allowedUpdates, {
    new: true,
    runValidators: true,
  });

  if (!user) {
    throw new ApiError(404, 'User not found.');
  }

  return user;
}

async function getPublicProfile(identifier) {
  const rawValue = (identifier || '').trim();
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

module.exports = {
  getMe,
  updateMe,
  getPublicProfile,
};

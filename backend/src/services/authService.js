const bcrypt = require('bcryptjs');

const User = require('../models/User');
const ApiError = require('../utils/ApiError');
const generateShareCode = require('../utils/generateShareCode');
const buildDefaultAvatarUrl = require('../utils/defaultAvatar');
const { assertCleanFields } = require('../utils/contentFilter');
const { accountBannedError } = require('../utils/safety');
const {
  createAccessToken,
  createRefreshToken,
  verifyRefreshToken,
} = require('./tokenService');

// Each login adds a refresh token; keep only the newest sessions so the array
// on the user document can't grow forever.
const MAX_REFRESH_TOKENS = 10;

function pushRefreshToken(refreshToken) {
  return {
    $push: { refreshTokens: { $each: [refreshToken], $slice: -MAX_REFRESH_TOKENS } },
  };
}

function normalizeUsername(value) {
  if (!value) return null;
  const cleaned = value.trim().toLowerCase().replace(/^@+/, '');
  if (!cleaned) return null;
  if (!/^[a-z0-9._]+$/.test(cleaned)) {
    throw new ApiError(400, 'Username can only contain lowercase letters, numbers, dot and underscore.');
  }
  return cleaned;
}

async function createUniqueShareCode(name) {
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const shareCode = generateShareCode(name);
    const conflict = await User.exists({
      $or: [{ shareCode }, { username: shareCode }],
    });
    if (!conflict) {
      return shareCode;
    }
  }

  throw new ApiError(500, 'Unable to allocate a share code.');
}

function buildAuthResponse(user) {
  const accessToken = createAccessToken(user);
  const refreshToken = createRefreshToken(user);
  return { accessToken, refreshToken, user: user.toJSON() };
}

function randomGuestEmail() {
  const rand = Math.random().toString(36).slice(2, 12);
  return `${rand}@guest.hamme.local`;
}

function randomGuestPassword() {
  return `${Math.random().toString(36).slice(2)}${Date.now()}!Aa1`;
}

/**
 * Terms fields to store when the client reports that the user just agreed to
 * the Terms of Use. Older app builds don't send a version: store nothing.
 */
function termsAcceptance(acceptedTermsVersion) {
  const version = Number(acceptedTermsVersion);
  if (!Number.isInteger(version) || version < 1) return {};
  return { termsAcceptedAt: new Date(), termsVersion: version };
}

async function signup({
  name,
  email,
  password,
  instagramId,
  avatarUrl,
  profileImageUrl,
  username,
  acceptedTermsVersion,
}) {
  assertCleanFields({ name, username, instagramId });

  const existingUser = await User.findOne({ email: email.toLowerCase() });
  if (existingUser) {
    throw new ApiError(409, 'An account with this email already exists.');
  }

  const shareCode = await createUniqueShareCode(name);
  const normalizedUsername = normalizeUsername(username || instagramId);
  const passwordHash = await bcrypt.hash(password, 12);
  const resolvedAvatar = avatarUrl || profileImageUrl;

  const user = await User.create({
    name,
    email,
    instagramId,
    username: normalizedUsername,
    passwordHash,
    profileImageUrl: resolvedAvatar || buildDefaultAvatarUrl(name),
    shareCode,
    ...termsAcceptance(acceptedTermsVersion),
  });

  const tokens = buildAuthResponse(user);
  await User.findByIdAndUpdate(user.id, pushRefreshToken(tokens.refreshToken));

  return tokens;
}

async function login({ email, password }) {
  const user = await User.findOne({ email: email.toLowerCase() }).select(
    '+passwordHash +refreshTokens'
  );

  if (!user) {
    throw new ApiError(401, 'Invalid email or password.');
  }

  const isMatch = await bcrypt.compare(password, user.passwordHash);
  if (!isMatch) {
    throw new ApiError(401, 'Invalid email or password.');
  }
  // Checked after the password so the response can't reveal a ban to others.
  if (user.isBanned) {
    throw accountBannedError();
  }

  // toJSON() strips passwordHash/refreshTokens, so the loaded user can be
  // returned as is (no second read).
  const tokens = buildAuthResponse(user);
  await User.findByIdAndUpdate(user.id, pushRefreshToken(tokens.refreshToken));

  return tokens;
}

async function refresh(refreshToken) {
  if (!refreshToken) {
    throw new ApiError(400, 'Refresh token is required.');
  }

  let payload;
  try {
    payload = verifyRefreshToken(refreshToken);
  } catch (error) {
    throw new ApiError(401, 'Refresh token is invalid or expired.');
  }

  const user = await User.findById(payload.sub).select('+refreshTokens');
  // A ban clears refresh tokens; report the ban rather than a generic 401.
  if (user?.isBanned) {
    throw accountBannedError();
  }
  if (!user || !user.refreshTokens.includes(refreshToken)) {
    throw new ApiError(401, 'Refresh token is no longer valid.');
  }

  const tokens = buildAuthResponse(user);
  // Rotate: drop the used token and keep only the newest sessions.
  user.refreshTokens = [
    ...user.refreshTokens.filter((item) => item !== refreshToken),
    tokens.refreshToken,
  ].slice(-MAX_REFRESH_TOKENS);
  await user.save();

  return tokens;
}

async function logout(userId, refreshToken) {
  const update = refreshToken
    ? { $pull: { refreshTokens: refreshToken } }
    : { $set: { refreshTokens: [] } };

  await User.findByIdAndUpdate(userId, update);
}

async function getCurrentUser(userId) {
  const user = await User.findById(userId);
  if (!user) {
    throw new ApiError(404, 'User not found.');
  }

  return user;
}

async function guestRegister({
  age,
  displayName,
  username,
  instagramId,
  snapchatId,
  avatarUrl,
  deviceId,
  acceptedTermsVersion,
}) {
  if (!displayName || displayName.trim().length < 2) {
    throw new ApiError(400, 'Display name is required.');
  }

  const normalizedUsername = normalizeUsername(username || instagramId || snapchatId);
  if (!normalizedUsername) {
    throw new ApiError(400, 'A valid username is required.');
  }
  assertCleanFields({ displayName, username, instagramId, snapchatId });

  const terms = termsAcceptance(acceptedTermsVersion);

  if (deviceId) {
    const existingByDevice = await User.findOne({ deviceId: deviceId.trim() });
    if (existingByDevice) {
      // A banned user reinstalling the app gets the same account back: refuse it.
      if (existingByDevice.isBanned) {
        throw accountBannedError();
      }
      // They just agreed to the terms again on the signup screen.
      const acceptsNewerTerms =
        terms.termsVersion && !(existingByDevice.termsVersion >= terms.termsVersion);
      if (acceptsNewerTerms) {
        existingByDevice.set(terms);
      }
      const tokens = buildAuthResponse(existingByDevice);
      await User.findByIdAndUpdate(existingByDevice.id, {
        ...pushRefreshToken(tokens.refreshToken),
        ...(acceptsNewerTerms ? { $set: terms } : {}),
      });
      return tokens;
    }
  }

  const shareCode = await createUniqueShareCode(displayName);
  const guestPasswordHash = await bcrypt.hash(randomGuestPassword(), 12);
  const resolvedAvatarUrl = avatarUrl || buildDefaultAvatarUrl(displayName);
  const user = await User.create({
    name: displayName.trim(),
    email: randomGuestEmail(),
    passwordHash: guestPasswordHash,
    instagramId: (instagramId || '').trim(),
    snapchatId: (snapchatId || '').trim(),
    username: normalizedUsername,
    profileImageUrl: resolvedAvatarUrl,
    shareCode,
    isGuestUser: true,
    deviceId: deviceId?.trim() || null,
    birthday: age ? new Date(new Date().getFullYear() - Number(age), 0, 1) : null,
    ...terms,
  });

  const tokens = buildAuthResponse(user);
  await User.findByIdAndUpdate(user.id, pushRefreshToken(tokens.refreshToken));
  return tokens;
}

module.exports = {
  signup,
  guestRegister,
  login,
  refresh,
  logout,
  getCurrentUser,
};

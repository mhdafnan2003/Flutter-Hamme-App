const AppConfig = require('../models/AppConfig');
const CardSession = require('../models/CardSession');
const User = require('../models/User');

const DEFAULTS = { freeUserCardLimit: 10, cardCooldownMinutes: 5 };
// The config changes only from the admin panel, but was read on every card
// view and every limit-status request. A short cache removes that query.
const CONFIG_CACHE_MS = 60 * 1000;

let cachedConfig = null;
let cachedConfigAt = 0;

function toConfig(doc) {
  if (!doc) return { ...DEFAULTS };
  return {
    freeUserCardLimit: doc.freeUserCardLimit,
    cardCooldownMinutes: doc.cardCooldownMinutes,
  };
}

async function getConfig() {
  if (!cachedConfig || Date.now() - cachedConfigAt > CONFIG_CACHE_MS) {
    cachedConfig = toConfig(await AppConfig.findOne({}).lean());
    cachedConfigAt = Date.now();
  }
  return { ...cachedConfig };
}

async function updateConfig({ freeUserCardLimit, cardCooldownMinutes }) {
  const update = {};
  if (freeUserCardLimit != null) update.freeUserCardLimit = Number(freeUserCardLimit);
  if (cardCooldownMinutes != null) update.cardCooldownMinutes = Number(cardCooldownMinutes);

  const config = await AppConfig.findOneAndUpdate(
    {},
    { $set: update },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
  cachedConfig = toConfig(config);
  cachedConfigAt = Date.now();
  return config;
}

const PRO_STATUS = {
  limited: false,
  viewsLeft: null,
  resetAt: null,
  maxCards: null,
  cooldownMinutes: null,
  isPro: true,
};

/** Limit status for a free user, given their card session (or none). */
function freeStatus(session, { freeUserCardLimit, cardCooldownMinutes }) {
  const base = {
    maxCards: freeUserCardLimit,
    cooldownMinutes: cardCooldownMinutes,
    isPro: false,
  };
  const windowEndMs = session
    ? session.windowStartedAt.getTime() + cardCooldownMinutes * 60 * 1000
    : 0;

  // No session, or its window has elapsed: the next card starts a new window.
  if (!session || Date.now() >= windowEndMs) {
    return { limited: false, viewsLeft: freeUserCardLimit, resetAt: null, ...base };
  }
  if (session.count >= freeUserCardLimit) {
    return {
      limited: true,
      viewsLeft: 0,
      resetAt: new Date(windowEndMs).toISOString(),
      ...base,
    };
  }
  return {
    limited: false,
    viewsLeft: freeUserCardLimit - session.count,
    resetAt: null,
    ...base,
  };
}

async function getCardLimitStatus(userId) {
  const user = await User.findById(userId)
    .select(
      'isPro adminPro storeProActive proPlatform proExpiryAt proSubscriptionState proAutoRenewing'
    )
    .lean();
  const adminEntitled =
    user?.adminPro || (user?.proPlatform === 'admin' && user?.isPro);
  const storeEntitled = Boolean(
    user?.storeProActive &&
      user?.proExpiryAt &&
      user.proExpiryAt.getTime() > Date.now()
  );
  const effectivePro = Boolean(adminEntitled || storeEntitled);

  // Enforce the stored paid expiry even if an RTDN is delayed. Keep the
  // denormalized compatibility flag consistent for subsequent reads.
  if (user && user.isPro !== effectivePro) {
    const update = { isPro: effectivePro };
    if (user.storeProActive && !storeEntitled) {
      update.storeProActive = false;
      update.proSubscriptionState = 'SUBSCRIPTION_STATE_EXPIRED';
      update.proAutoRenewing = false;
    }
    await User.updateOne({ _id: user._id }, { $set: update });
  }

  if (effectivePro) {
    return { ...PRO_STATUS };
  }

  const [config, session] = await Promise.all([
    getConfig(),
    CardSession.findOne({ userId }).lean(),
  ]);
  return freeStatus(session, config);
}

/**
 * Counts one card view and returns the resulting limit status, so callers
 * don't need to read the status again. `currentStatus` is the status the
 * caller already loaded before the view (pro users are not counted).
 */
async function recordCardView(userId, currentStatus = null) {
  const status = currentStatus || (await getCardLimitStatus(userId));
  if (status.isPro) return status;

  const config = await getConfig();
  const now = new Date();
  const windowOpenSince = new Date(
    now.getTime() - config.cardCooldownMinutes * 60 * 1000
  );

  // Count the view in the current window if it is still open...
  let session = await CardSession.findOneAndUpdate(
    { userId, windowStartedAt: { $gt: windowOpenSince } },
    { $inc: { count: 1 } },
    { new: true, lean: true }
  );
  if (!session) {
    // ...otherwise start a new window (the upsert covers the first view ever).
    session = await CardSession.findOneAndUpdate(
      { userId },
      { $set: { count: 1, windowStartedAt: now } },
      { new: true, upsert: true, setDefaultsOnInsert: true, lean: true }
    );
  }
  return freeStatus(session, config);
}

module.exports = { getConfig, updateConfig, getCardLimitStatus, recordCardView };

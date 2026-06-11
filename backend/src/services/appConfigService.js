const AppConfig = require('../models/AppConfig');
const CardSession = require('../models/CardSession');
const User = require('../models/User');

const DEFAULTS = { freeUserCardLimit: 10, cardCooldownMinutes: 5 };

async function getConfig() {
  const config = await AppConfig.findOne({});
  if (!config) return { ...DEFAULTS };
  return {
    freeUserCardLimit: config.freeUserCardLimit,
    cardCooldownMinutes: config.cardCooldownMinutes,
  };
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
  return config;
}

async function getCardLimitStatus(userId) {
  const user = await User.findById(userId).select('isPro');
  if (user?.isPro) {
    return { limited: false, viewsLeft: null, resetAt: null, maxCards: null, cooldownMinutes: null, isPro: true };
  }

  const config = await getConfig();
  const { freeUserCardLimit, cardCooldownMinutes } = config;

  const session = await CardSession.findOne({ userId });
  if (!session) {
    return { limited: false, viewsLeft: freeUserCardLimit, resetAt: null, maxCards: freeUserCardLimit, cooldownMinutes, isPro: false };
  }

  const windowEndMs = session.windowStartedAt.getTime() + cardCooldownMinutes * 60 * 1000;
  const now = Date.now();

  if (now >= windowEndMs) {
    await CardSession.findOneAndUpdate({ userId }, { count: 0, windowStartedAt: new Date() });
    return { limited: false, viewsLeft: freeUserCardLimit, resetAt: null, maxCards: freeUserCardLimit, cooldownMinutes, isPro: false };
  }

  if (session.count >= freeUserCardLimit) {
    return {
      limited: true,
      viewsLeft: 0,
      resetAt: new Date(windowEndMs).toISOString(),
      maxCards: freeUserCardLimit,
      cooldownMinutes,
      isPro: false,
    };
  }

  return {
    limited: false,
    viewsLeft: freeUserCardLimit - session.count,
    resetAt: null,
    maxCards: freeUserCardLimit,
    cooldownMinutes,
    isPro: false,
  };
}

async function incrementCardView(userId) {
  const config = await getConfig();

  const session = await CardSession.findOne({ userId });
  if (!session) {
    await CardSession.create({ userId, count: 1, windowStartedAt: new Date() });
    return;
  }

  const windowEndMs = session.windowStartedAt.getTime() + config.cardCooldownMinutes * 60 * 1000;
  if (Date.now() >= windowEndMs) {
    await CardSession.findOneAndUpdate({ userId }, { count: 1, windowStartedAt: new Date() });
  } else {
    await CardSession.findOneAndUpdate({ userId }, { $inc: { count: 1 } });
  }
}

module.exports = { getConfig, updateConfig, getCardLimitStatus, incrementCardView };

const User = require('../models/User');

// Whether an access token's account still exists and is not banned. The app
// polls several authenticated endpoints every 15 seconds, so the answer is
// cached per user instead of adding a query to every request. A ban therefore
// reaches other server instances within CACHE_TTL_MS; on the instance that
// performs the ban or unban the entry is dropped immediately (forget()).
const CACHE_TTL_MS = 60 * 1000;
const CACHE_MAX_ENTRIES = 10000;

const cache = new Map(); // userId -> { status, expiresAt }
const inFlight = new Map(); // userId -> Promise<status>

function remember(key, status) {
  if (cache.size >= CACHE_MAX_ENTRIES) {
    // Maps iterate in insertion order: drop the oldest entry.
    cache.delete(cache.keys().next().value);
  }
  cache.delete(key);
  cache.set(key, { status, expiresAt: Date.now() + CACHE_TTL_MS });
}

/** Resolves 'active', 'banned' or 'missing' (account deleted). */
function getAccountStatus(userId) {
  const key = String(userId);
  const cached = cache.get(key);
  if (cached && cached.expiresAt > Date.now()) {
    return Promise.resolve(cached.status);
  }
  if (inFlight.has(key)) {
    return inFlight.get(key);
  }

  const lookup = User.findById(key)
    .select('isBanned')
    .lean()
    .then((user) => {
      const status = !user ? 'missing' : user.isBanned ? 'banned' : 'active';
      // Skip caching if forget() ran while this lookup was in flight.
      if (inFlight.get(key) === lookup) remember(key, status);
      return status;
    })
    .finally(() => {
      if (inFlight.get(key) === lookup) inFlight.delete(key);
    });
  inFlight.set(key, lookup);
  return lookup;
}

/** Drops the cached status, e.g. right after a ban, unban or deletion. */
function forgetAccountStatus(userId) {
  const key = String(userId);
  cache.delete(key);
  inFlight.delete(key);
}

module.exports = { getAccountStatus, forgetAccountStatus };

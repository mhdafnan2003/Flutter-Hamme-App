const crypto = require('crypto');

const env = require('../config/env');
const ApiError = require('../utils/ApiError');

function keysMatch(provided, expected) {
  const a = Buffer.from(provided);
  const b = Buffer.from(expected);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

/**
 * Protects admin endpoints with a shared secret.
 * The key must be sent in the `x-admin-key` header. A query parameter is not
 * accepted because request URLs are written to the access logs.
 * If no ADMIN_API_KEY is configured the admin API is disabled entirely.
 */
module.exports = function adminMiddleware(req, res, next) {
  if (!env.adminApiKey) {
    return next(new ApiError(503, 'Admin API is not configured.'));
  }

  const provided = req.headers['x-admin-key'];
  if (typeof provided !== 'string' || !keysMatch(provided, env.adminApiKey)) {
    return next(new ApiError(401, 'Invalid admin key.'));
  }

  return next();
};

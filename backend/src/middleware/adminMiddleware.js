const env = require('../config/env');
const ApiError = require('../utils/ApiError');

/**
 * Protects admin endpoints with a shared secret.
 * The key must be sent in the `x-admin-key` header (or `adminKey` query param).
 * If no ADMIN_API_KEY is configured the admin API is disabled entirely.
 */
module.exports = function adminMiddleware(req, res, next) {
  if (!env.adminApiKey) {
    return next(new ApiError(503, 'Admin API is not configured.'));
  }

  const provided = req.headers['x-admin-key'] || req.query.adminKey;
  if (!provided || provided !== env.adminApiKey) {
    return next(new ApiError(401, 'Invalid admin key.'));
  }

  return next();
};

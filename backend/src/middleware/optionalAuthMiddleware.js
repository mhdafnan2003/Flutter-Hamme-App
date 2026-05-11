const { verifyAccessToken } = require('../services/tokenService');

function optionalAuthMiddleware(req, res, next) {
  const authorization = req.headers.authorization;
  if (!authorization || !authorization.startsWith('Bearer ')) {
    return next();
  }

  const token = authorization.replace('Bearer ', '');
  try {
    const payload = verifyAccessToken(token);
    req.auth = { userId: payload.sub, email: payload.email };
  } catch (_) {
    // Ignore invalid tokens for optional auth.
  }

  return next();
}

module.exports = optionalAuthMiddleware;

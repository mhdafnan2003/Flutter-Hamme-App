const { verifyAccessToken } = require('../services/tokenService');
const { getAccountStatus } = require('../services/accountStatusService');
const { accountBannedError } = require('../utils/safety');

async function optionalAuthMiddleware(req, res, next) {
  const authorization = req.headers.authorization;
  if (!authorization || !authorization.startsWith('Bearer ')) {
    return next();
  }

  const token = authorization.replace('Bearer ', '');
  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch (_) {
    // Ignore invalid tokens for optional auth.
    return next();
  }

  // Same cached ban check as authMiddleware. A deleted account's token is
  // ignored like an invalid one; a banned account is refused outright.
  try {
    const status = await getAccountStatus(payload.sub);
    if (status === 'banned') {
      return next(accountBannedError());
    }
    if (status === 'active') {
      req.auth = { userId: payload.sub, email: payload.email };
    }
  } catch (error) {
    return next(error);
  }

  return next();
}

module.exports = optionalAuthMiddleware;

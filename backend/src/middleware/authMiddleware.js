const ApiError = require('../utils/ApiError');
const { verifyAccessToken } = require('../services/tokenService');
const { getAccountStatus } = require('../services/accountStatusService');
const { accountBannedError } = require('../utils/safety');

// Rejections are logged once by errorHandler; logging here too doubled every
// 401 (one per expired token every 15 minutes per device).
async function authMiddleware(req, res, next) {
  const authorization = req.headers.authorization || '';
  const [scheme, rawToken] = authorization.split(' ');
  const isBearer = scheme?.toLowerCase() === 'bearer';
  const token = isBearer ? rawToken?.trim() : '';

  if (!token) {
    return next(new ApiError(401, 'Authorization token is required.'));
  }

  let payload;
  try {
    payload = verifyAccessToken(token, { clockTolerance: 5 });
  } catch (error) {
    if (error?.name === 'TokenExpiredError') {
      return next(new ApiError(401, 'Authorization token is expired.'));
    }
    return next(new ApiError(401, 'Authorization token is invalid.'));
  }

  // A still-valid token must not outlive a ban or an account deletion.
  // Cached for up to a minute, so this is not a query per request.
  try {
    const status = await getAccountStatus(payload.sub);
    if (status === 'banned') {
      return next(accountBannedError());
    }
    if (status === 'missing') {
      return next(new ApiError(401, 'This account no longer exists.'));
    }
  } catch (error) {
    return next(error);
  }

  req.auth = { userId: payload.sub, email: payload.email };
  return next();
}

module.exports = authMiddleware;
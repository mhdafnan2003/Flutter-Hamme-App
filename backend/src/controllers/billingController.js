const billingService = require('../services/billingService');

async function verify(req, res) {
  const user = await billingService.verifyPurchase(req.auth.userId, req.body);
  return res.status(200).json({ isPro: user.isPro, user: user.toJSON() });
}

async function status(req, res) {
  const user = await billingService.syncUserSubscription(req.auth.userId);
  return res.status(200).json({ isPro: user.isPro, user: user.toJSON() });
}

async function rtdn(req, res) {
  await billingService.verifyRtdnAuthorization(req.headers.authorization);
  await billingService.processRtdn(req.body);
  // Any 2xx acknowledges the Pub/Sub push. Errors are passed through so Pub/Sub
  // retries transient failures instead of silently losing entitlement updates.
  return res.status(204).send();
}

module.exports = {
  rtdn,
  status,
  verify,
};

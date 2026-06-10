const billingService = require('../services/billingService');

async function verify(req, res) {
  const user = await billingService.verifyPurchase(req.auth.userId, req.body);
  return res.status(200).json({ isPro: user.isPro, user: user.toJSON() });
}

module.exports = {
  verify,
};

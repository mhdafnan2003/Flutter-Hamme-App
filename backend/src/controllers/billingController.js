const billingService = require('../services/billingService');

async function verifyAndroidPurchase(req, res) {
  const result = await billingService.verifyAndroidPurchase({
    userId: req.auth.userId,
    purchaseToken: req.body.purchaseToken,
  });
  return res.status(200).json(result);
}

async function restoreAndroidPurchases(req, res) {
  const result = await billingService.restoreAndroidPurchases({
    userId: req.auth.userId,
    purchaseTokens: req.body.purchaseTokens,
  });
  return res.status(200).json(result);
}

async function getEntitlement(req, res) {
  const result = await billingService.getCurrentEntitlement({
    userId: req.auth.userId,
  });
  return res.status(200).json(result);
}

module.exports = {
  verifyAndroidPurchase,
  restoreAndroidPurchases,
  getEntitlement,
};

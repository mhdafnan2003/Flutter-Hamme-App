const express = require('express');
const { body } = require('express-validator');

const authMiddleware = require('../middleware/authMiddleware');
const validateRequest = require('../middleware/validateRequest');
const billingController = require('../controllers/billingController');

const router = express.Router();

router.use(authMiddleware);

router.get('/entitlement', billingController.getEntitlement);

router.post(
  '/verify/android',
  [body('purchaseToken').trim().isLength({ min: 8, max: 4096 })],
  validateRequest,
  billingController.verifyAndroidPurchase
);

router.post(
  '/restore/android',
  [
    body('purchaseTokens').isArray({ min: 1, max: 20 }),
    body('purchaseTokens.*').trim().isLength({ min: 8, max: 4096 }),
  ],
  validateRequest,
  billingController.restoreAndroidPurchases
);

module.exports = router;

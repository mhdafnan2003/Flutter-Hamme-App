const express = require('express');
const { body } = require('express-validator');

const billingController = require('../controllers/billingController');
const authMiddleware = require('../middleware/authMiddleware');
const validateRequest = require('../middleware/validateRequest');

const router = express.Router();

// Google Cloud Pub/Sub push endpoint. Authentication is performed with the
// Google-signed OIDC bearer token, not a Hamme user token.
router.post('/google-play/rtdn', billingController.rtdn);

router.get('/status', authMiddleware, billingController.status);

router.post(
  '/verify',
  authMiddleware,
  [
    body('platform').optional({ values: 'falsy' }).isIn(['android', 'ios']),
    body('productId').trim().notEmpty(),
    body('purchaseToken').trim().notEmpty(),
    body('packageName').optional({ values: 'falsy' }).trim(),
  ],
  validateRequest,
  billingController.verify
);

module.exports = router;

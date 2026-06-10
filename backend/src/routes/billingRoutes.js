const express = require('express');
const { body } = require('express-validator');

const billingController = require('../controllers/billingController');
const authMiddleware = require('../middleware/authMiddleware');
const validateRequest = require('../middleware/validateRequest');

const router = express.Router();

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

const express = require('express');
const { body } = require('express-validator');
const isURL = require('validator/lib/isURL');

const authController = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');
const validateRequest = require('../middleware/validateRequest');

const router = express.Router();

const avatarUrlOptions = {
  require_protocol: true,
  protocols: ['http', 'https'],
  require_tld: false,
};

function isAllowedAvatarUrl(value) {
  if (!value) return true;
  if (value.startsWith('/uploads/')) return true;
  return isURL(value, avatarUrlOptions);
}

router.post(
  '/signup',
  [
    body('name').trim().isLength({ min: 2, max: 80 }),
    body('email').isEmail().normalizeEmail(),
    body('password').isLength({ min: 6, max: 64 }),
    body('instagramId').trim().notEmpty(),
    body('username').optional({ values: 'falsy' }).trim().toLowerCase().matches(/^[a-z0-9._]+$/),
    body('avatarUrl')
      .optional({ values: 'falsy' })
      .custom(isAllowedAvatarUrl),
  ],
  validateRequest,
  authController.signup
);

router.post(
  '/guest-register',
  [
    body('age')
      .optional({ values: 'falsy' })
      .isInt({ min: 13, max: 100 })
      .withMessage('Age must be between 13 and 100.'),
    body('displayName')
      .trim()
      .isLength({ min: 2, max: 80 })
      .withMessage('Display name must be 2 to 80 characters long.'),
    body('username')
      .trim()
      .toLowerCase()
      .matches(/^[a-z0-9._]+$/)
      .withMessage('Username can only contain lowercase letters, numbers, dots, and underscores.'),
    body('instagramId').optional({ values: 'falsy' }).trim(),
    body('snapchatId').optional({ values: 'falsy' }).trim(),
    body('avatarUrl')
      .optional({ values: 'falsy' })
      .custom(isAllowedAvatarUrl),
    body('deviceId').optional({ values: 'falsy' }).trim(),
  ],
  validateRequest,
  authController.guestRegister
);

router.post(
  '/login',
  [body('email').isEmail().normalizeEmail(), body('password').isLength({ min: 6 })],
  validateRequest,
  authController.login
);

router.post(
  '/refresh',
  [body('refreshToken').trim().notEmpty()],
  validateRequest,
  authController.refresh
);

router.post('/logout', authMiddleware, authController.logout);
router.get('/me', authMiddleware, authController.me);

module.exports = router;

const express = require('express');
const { body, param } = require('express-validator');

const profileController = require('../controllers/profileController');
const authMiddleware = require('../middleware/authMiddleware');
const validateRequest = require('../middleware/validateRequest');

const router = express.Router();

router.get(
  '/public/:shareCode',
  [param('shareCode').trim().notEmpty()],
  validateRequest,
  profileController.getPublicProfile
);

router.get('/me', authMiddleware, profileController.getMe);

router.patch(
  '/me',
  authMiddleware,
  [
    body('name').optional().trim().isLength({ min: 2, max: 80 }),
    body('instagramId').optional().trim().notEmpty(),
    body('snapchatId').optional().trim().notEmpty(),
    body('username').optional({ values: 'falsy' }).trim().toLowerCase().matches(/^[a-z0-9._]+$/),
    body('avatarUrl').optional({ values: 'null' }).isURL(),
  ],
  validateRequest,
  profileController.updateMe
);

// Account deletion is deliberately initiated from the signed-in app, not by
// email or support, so users can permanently remove their data themselves.
router.delete('/me', authMiddleware, profileController.deleteMe);

router.put(
  '/device-token',
  authMiddleware,
  [
    body('token').trim().notEmpty(),
    body('platform').isIn(['ios', 'android']),
  ],
  validateRequest,
  profileController.registerDeviceToken
);

router.delete(
  '/device-token',
  authMiddleware,
  [body('token').trim().notEmpty()],
  validateRequest,
  profileController.unregisterDeviceToken
);

// Terms of Use acceptance, and the safety actions behind report / block /
// "Blocked users". The /me/... routes come before /:userId/... so "me" is
// never taken for a user id.
router.post(
  '/me/terms',
  authMiddleware,
  [body('version').optional({ values: 'null' }).isInt({ min: 1, max: 1000 }).toInt()],
  validateRequest,
  profileController.acceptTerms
);

router.get('/me/blocked', authMiddleware, profileController.listBlocked);

router.delete('/me/blocked-anonymous', authMiddleware, profileController.clearAnonymousBlocks);

router.delete(
  '/me/blocked/:userId',
  authMiddleware,
  [param('userId').isMongoId()],
  validateRequest,
  profileController.unblockUser
);

router.post(
  '/:userId/report',
  authMiddleware,
  [
    param('userId').isMongoId(),
    // An unknown reason is stored as `other` rather than rejected.
    body('reason').optional({ values: 'null' }).isString(),
    body('details').optional({ values: 'null' }).isString(),
    body('block').optional({ values: 'null' }).isBoolean().toBoolean(),
  ],
  validateRequest,
  profileController.reportProfile
);

router.post(
  '/:userId/block',
  authMiddleware,
  [param('userId').isMongoId()],
  validateRequest,
  profileController.blockUser
);

module.exports = router;

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

module.exports = router;

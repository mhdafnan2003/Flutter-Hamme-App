const express = require('express');
const { body, param, query } = require('express-validator');

const adminController = require('../controllers/adminController');
const adminMiddleware = require('../middleware/adminMiddleware');
const validateRequest = require('../middleware/validateRequest');
const adminPanelHtml = require('../views/adminPanel');

const router = express.Router();

// Self-contained admin UI. The page itself is public; every data/action request
// it makes is authenticated with the admin key entered in the UI.
router.get('/', (req, res) => {
  // Relax CSP for this self-contained page (inline script/style + remote avatars).
  res.set(
    'Content-Security-Policy',
    "default-src 'self'; img-src * data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; connect-src 'self'"
  );
  res.set('Content-Type', 'text/html; charset=utf-8');
  res.send(adminPanelHtml);
});

router.get('/users', adminMiddleware, adminController.listUsers);

// Moderation queue. Reports must be acted on within 24 hours (Guideline 1.2).
router.get(
  '/reports',
  adminMiddleware,
  [
    query('status').optional().isIn(['open', 'actioned', 'dismissed', 'all']),
    query('page').optional().isInt({ min: 1 }),
    query('limit').optional().isInt({ min: 1, max: 100 }),
  ],
  validateRequest,
  adminController.listReports
);

router.post(
  '/reports/:id/action',
  adminMiddleware,
  [
    param('id').isMongoId(),
    body('action').isIn(['remove_and_ban', 'remove_content', 'dismiss']),
    body('note').optional({ values: 'null' }).isString().isLength({ max: 1000 }),
  ],
  validateRequest,
  adminController.actOnReport
);

router.patch(
  '/users/:id/plan',
  adminMiddleware,
  [param('id').isMongoId(), body('isPro').isBoolean()],
  validateRequest,
  adminController.setPlan
);

router.post(
  '/users/:id/ban',
  adminMiddleware,
  [
    param('id').isMongoId(),
    body('reason').optional({ values: 'null' }).isString().isLength({ max: 500 }),
  ],
  validateRequest,
  adminController.banUser
);

router.post(
  '/users/:id/unban',
  adminMiddleware,
  [param('id').isMongoId()],
  validateRequest,
  adminController.unbanUser
);

router.get('/config', adminMiddleware, adminController.getConfig);

router.patch(
  '/config',
  adminMiddleware,
  [
    body('freeUserCardLimit').optional().isInt({ min: 1, max: 1000 }),
    body('cardCooldownMinutes').optional().isInt({ min: 1, max: 1440 }),
  ],
  validateRequest,
  adminController.updateConfig
);

module.exports = router;

const express = require('express');
const { body, param } = require('express-validator');

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

router.patch(
  '/users/:id/plan',
  adminMiddleware,
  [param('id').isMongoId(), body('isPro').isBoolean()],
  validateRequest,
  adminController.setPlan
);

module.exports = router;

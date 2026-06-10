const express = require('express');
const { body } = require('express-validator');

const interactionController = require('../controllers/interactionController');
const authMiddleware = require('../middleware/authMiddleware');
const optionalAuthMiddleware = require('../middleware/optionalAuthMiddleware');
const validateRequest = require('../middleware/validateRequest');

const router = express.Router();

router.post(
  '/respond',
  authMiddleware,
  [
    body('targetUserId').trim().notEmpty(),
    body('type').isIn(['crush', 'friend', 'frenemy']),
    body('senderUserId').optional({ values: 'falsy' }).trim(),
    body('source').optional({ values: 'falsy' }).trim(),
  ],
  validateRequest,
  interactionController.respondInteraction
);

router.post(
  '/pending',
  optionalAuthMiddleware,
  [
    body('targetUserId').trim().notEmpty(),
    body('type').isIn(['crush', 'friend', 'frenemy']),
  ],
  validateRequest,
  interactionController.createPendingInteraction
);

router.get('/pending/:token', interactionController.getPendingInteraction);

router.use(authMiddleware);

router.post(
  '/',
  [
    body('shareCode').trim().notEmpty(),
    body('type').isIn(['crush', 'friend', 'frenemy']),
  ],
  validateRequest,
  interactionController.createInteraction
);

router.get('/matches', interactionController.getMatches);
router.get('/received', interactionController.getReceivedInteractions);
router.post(
  '/finalize',
  [body('token').trim().notEmpty()],
  validateRequest,
  interactionController.finalizePendingInteraction
);

module.exports = router;

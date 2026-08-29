const express = require('express');
const { body, param } = require('express-validator');
const rateLimit = require('express-rate-limit');

const publicController = require('../controllers/publicController');
const validateRequest = require('../middleware/validateRequest');

const optionalAuthMiddleware = require('../middleware/optionalAuthMiddleware');

const router = express.Router();

// Anonymous responses are unauthenticated by default, but accept optional bearer auth
// so that logged-in users who vote on web or funnel can be properly identified.
const anonymousResponseLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many responses. Please slow down and try again shortly.' },
  validate: {
    xForwardedForHeader: false,
    forwardedHeader: false,
  },
});

router.get(
  '/public-profile/:identifier',
  [param('identifier').trim().notEmpty()],
  validateRequest,
  publicController.getPublicProfile
);

router.post(
  '/anonymous-response',
  optionalAuthMiddleware,
  anonymousResponseLimiter,
  [
    body('shareCode').optional({ values: 'falsy' }).trim(),
    body('identifier').optional({ values: 'falsy' }).trim(),
    body('type').isIn(['friend', 'crush', 'frenemy']),
    body('timestamp').isNumeric(),
    body('sessionId').optional({ values: 'falsy' }).trim(),
    body('source').optional({ values: 'falsy' }).trim(),
  ],
  validateRequest,
  publicController.createAnonymousResponse
);

module.exports = router;


const express = require('express');
const { body, param } = require('express-validator');

const publicController = require('../controllers/publicController');
const validateRequest = require('../middleware/validateRequest');

const router = express.Router();

router.get(
  '/public-profile/:identifier',
  [param('identifier').trim().notEmpty()],
  validateRequest,
  publicController.getPublicProfile
);

router.post(
  '/anonymous-response',
  [
    body('identifier').trim().notEmpty(),
    body('type').isIn(['friend', 'crush', 'frenemy']),
    body('source').optional({ values: 'falsy' }).trim(),
  ],
  validateRequest,
  publicController.createAnonymousResponse
);

module.exports = router;


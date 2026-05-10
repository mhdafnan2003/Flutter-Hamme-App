const express = require('express');

const authRoutes = require('./authRoutes');
const profileRoutes = require('./profileRoutes');
const interactionRoutes = require('./interactionRoutes');
const publicRoutes = require('./publicRoutes');
const uploadRoutes = require('./uploadRoutes');

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/profiles', profileRoutes);
router.use('/interactions', interactionRoutes);
router.use('/upload', uploadRoutes);
router.use('/', publicRoutes);

module.exports = router;

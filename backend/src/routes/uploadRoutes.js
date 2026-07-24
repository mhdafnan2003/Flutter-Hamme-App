const express = require('express');
const multer = require('multer');
const path = require('path');

const ApiError = require('../utils/ApiError');
const uploadController = require('../controllers/uploadController');
const logger = require('../utils/logger');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

const allowedTypes = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
]);
const allowedExtensions = new Set(['.jpeg', '.jpg', '.png', '.webp']);

function isAllowedImage(file) {
  const mimetype = (file.mimetype || '').toLowerCase();
  const extension = path.extname(file.originalname || '').toLowerCase();
  const mimeOk = allowedTypes.has(mimetype);
  const extOk = allowedExtensions.has(extension);
  return { mimeOk, extOk, mimetype, extension };
}

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const { mimeOk, extOk, mimetype, extension } = isAllowedImage(file);
    logger.info('Upload file received', {
      name: file.originalname,
      mimetype,
      extension,
    });
    if (mimeOk && extOk) {
      cb(null, true);
    } else {
      cb(new ApiError(400, 'Only JPG, PNG, and WEBP images are allowed.'));
    }
  },
});

router.post('/profile-image', authMiddleware, (req, res, next) => {
  upload.single('image')(req, res, (err) => {
    if (err) {
      if (err.code === 'LIMIT_FILE_SIZE') {
        return next(new ApiError(413, 'Image must be smaller than 10 MB.'));
      }
      return next(err);
    }
    return next();
  });
}, uploadController.uploadProfileImage);

module.exports = router;

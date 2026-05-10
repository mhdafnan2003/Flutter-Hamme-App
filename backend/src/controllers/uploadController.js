const crypto = require('crypto');
const fs = require('fs/promises');
const path = require('path');
const sharp = require('sharp');

const env = require('../config/env');
const ApiError = require('../utils/ApiError');

const uploadRoot = path.join(__dirname, '..', '..', 'uploads');
const profileUploadDir = path.join(uploadRoot, 'profile');

function buildPublicUrl(req, relativePath) {
  const baseUrl = (env.publicBaseUrl || '').trim();
  if (baseUrl) {
    return `${baseUrl.replace(/\/$/, '')}${relativePath}`;
  }

  const forwardedHost = req.get('x-forwarded-host');
  const forwardedProto = req.get('x-forwarded-proto');
  const host = forwardedHost || req.get('host');
  const protocol = forwardedProto || req.protocol;
  return `${protocol}://${host}${relativePath}`;
}

async function uploadProfileImage(req, res) {
  if (!req.file) {
    throw new ApiError(400, 'Profile image file is required.');
  }

  await fs.mkdir(profileUploadDir, { recursive: true });

  const uniqueId =
    typeof crypto.randomUUID === 'function'
      ? crypto.randomUUID()
      : crypto.randomBytes(16).toString('hex');
  const fileName = `profile-${Date.now()}-${uniqueId}.jpg`;
  const targetPath = path.join(profileUploadDir, fileName);

  await sharp(req.file.buffer)
    .rotate()
    .resize({ width: 1024, height: 1024, fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: 80 })
    .toFile(targetPath);

  const imageUrl = buildPublicUrl(req, `/uploads/profile/${fileName}`);
  return res.status(201).json({ imageUrl });
}

module.exports = {
  uploadProfileImage,
};

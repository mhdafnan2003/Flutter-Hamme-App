const sharp = require('sharp');
const { v2: cloudinary } = require('cloudinary');

const env = require('../config/env');
const ApiError = require('../utils/ApiError');

const cloudinaryEnabled =
  Boolean(env.cloudinaryCloudName) &&
  Boolean(env.cloudinaryApiKey) &&
  Boolean(env.cloudinaryApiSecret);

if (cloudinaryEnabled) {
  cloudinary.config({
    cloud_name: env.cloudinaryCloudName,
    api_key: env.cloudinaryApiKey,
    api_secret: env.cloudinaryApiSecret,
  });
}

function uploadToCloudinary(buffer) {
  return new Promise((resolve, reject) => {
    const uploadStream = cloudinary.uploader.upload_stream(
      {
        folder: env.cloudinaryFolder,
        resource_type: 'image',
        format: 'jpg',
      },
      (error, result) => {
        if (error) {
          reject(error);
          return;
        }
        resolve(result);
      }
    );

    uploadStream.end(buffer);
  });
}

async function uploadProfileImage(req, res) {
  if (!req.file) {
    throw new ApiError(400, 'Profile image file is required.');
  }

  if (!cloudinaryEnabled) {
    throw new ApiError(500, 'Cloudinary is not configured.');
  }

  const processedBuffer = await sharp(req.file.buffer)
    .rotate()
    .resize({ width: 1024, height: 1024, fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: 80 })
    .toBuffer();

  const uploadResult = await uploadToCloudinary(processedBuffer);
  return res.status(201).json({ imageUrl: uploadResult.secure_url });
}

module.exports = {
  uploadProfileImage,
};

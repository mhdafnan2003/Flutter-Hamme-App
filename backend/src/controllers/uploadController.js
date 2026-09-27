const sharp = require('sharp');
const { v2: cloudinary } = require('cloudinary');

const env = require('../config/env');
const ApiError = require('../utils/ApiError');
const { objectionableContentError } = require('../utils/safety');

// Uploads are rare and small (the app resizes to 1024px first). libvips'
// operation cache and one worker thread per CPU only keep extra native memory
// resident after each upload, so turn both down.
sharp.cache(false);
sharp.concurrency(1);
// Reject decompression bombs: the app sends at most 1024x1024.
const MAX_INPUT_PIXELS = 25 * 1000 * 1000;

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
        // Optional moderation add-on, e.g. "aws_rek" (CLOUDINARY_MODERATION).
        ...(env.cloudinaryModeration ? { moderation: env.cloudinaryModeration } : {}),
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

  const processedBuffer = await sharp(req.file.buffer, {
    limitInputPixels: MAX_INPUT_PIXELS,
  })
    .rotate()
    .resize({ width: 1024, height: 1024, fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: 80 })
    .toBuffer();

  const uploadResult = await uploadToCloudinary(processedBuffer);

  // With a moderation add-on, Cloudinary reports unsafe photos as rejected in
  // the upload result. Asynchronous kinds (status "pending") are not waited for.
  const rejected = (uploadResult.moderation || []).some((entry) => entry?.status === 'rejected');
  if (rejected) {
    await cloudinary.uploader
      .destroy(uploadResult.public_id, { resource_type: 'image' })
      .catch(() => {});
    throw objectionableContentError('photo', 'photo');
  }

  return res.status(201).json({ imageUrl: uploadResult.secure_url });
}

module.exports = {
  uploadProfileImage,
};

const dotenv = require('dotenv');

dotenv.config();

const rawClientOrigin = process.env.CLIENT_ORIGIN || '*';
const clientOrigin =
  rawClientOrigin === '*'
    ? '*'
    : rawClientOrigin
        .split(',')
        .map((origin) => origin.trim())
        .filter(Boolean);

module.exports = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 3000),
  mongoUri: process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/hamme',
  clientOrigin,
  publicBaseUrl: process.env.PUBLIC_BASE_URL || '',
  cloudinaryCloudName: process.env.CLOUDINARY_CLOUD_NAME || '',
  cloudinaryApiKey: process.env.CLOUDINARY_API_KEY || '',
  cloudinaryApiSecret: process.env.CLOUDINARY_API_SECRET || '',
  cloudinaryFolder: process.env.CLOUDINARY_FOLDER || 'hamme/profile',
  jwtAccessSecret: process.env.JWT_ACCESS_SECRET || 'change-me-access-secret',
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET || 'change-me-refresh-secret',
  jwtAccessTtl: process.env.JWT_ACCESS_TTL || '15m',
  jwtRefreshTtl: process.env.JWT_REFRESH_TTL || '30d',
  enableSockets:
    process.env.ENABLE_SOCKETS === 'true' && !process.env.VERCEL,
  adminApiKey: process.env.ADMIN_API_KEY || '',
};

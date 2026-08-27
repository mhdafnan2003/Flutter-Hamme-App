const admin = require('firebase-admin');

const User = require('../models/User');
const env = require('../config/env');
const logger = require('../utils/logger');

let app = null;
let initAttempted = false;

/** Returns the initialized firebase-admin app, or null if push is not configured. */
function getApp() {
  if (initAttempted) return app;
  initAttempted = true;

  if (!env.firebaseServiceAccountJson) {
    logger.info('[Push] FIREBASE_SERVICE_ACCOUNT_JSON not set — push notifications disabled.');
    return null;
  }

  try {
    const serviceAccount = JSON.parse(env.firebaseServiceAccountJson);
    app = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  } catch (error) {
    logger.error('[Push] Failed to initialize firebase-admin', { message: error.message });
    app = null;
  }

  return app;
}

const UNREGISTERED_ERROR_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

async function pruneTokens(userId, tokens) {
  if (!tokens.length) return;
  await User.updateOne(
    { _id: userId },
    { $pull: { deviceTokens: { token: { $in: tokens } } } }
  ).catch((error) => {
    logger.error('[Push] Failed to prune invalid device tokens', {
      userId: userId.toString(),
      message: error.message,
    });
  });
}

/**
 * Sends a push notification to every device registered to a user.
 * Never throws — a push failure must not affect the caller's request.
 */
async function sendToUser(userId, { title, body, data = {}, imageUrl = null }) {
  try {
    const firebaseApp = getApp();
    if (!firebaseApp) return;

    const user = await User.findById(userId).select('+deviceTokens');
    const tokens = (user?.deviceTokens || []).map((entry) => entry.token);
    if (!tokens.length) return;

    const stringifiedData = Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, String(value)])
    );

    const message = {
      tokens,
      notification: {
        title,
        body,
        ...(imageUrl ? { imageUrl } : {}),
      },
      data: stringifiedData,
      android: {
        notification: {
          channelId: 'hamme_default',
        },
      },
      apns: {
        payload: {
          aps: {
            'mutable-content': 1,
            sound: 'default',
          },
        },
        ...(imageUrl ? { fcmOptions: { imageUrl } } : {}),
      },
    };

    const response = await admin.messaging(firebaseApp).sendEachForMulticast(message);

    const staleTokens = [];
    response.responses.forEach((result, index) => {
      if (!result.success && UNREGISTERED_ERROR_CODES.has(result.error?.code)) {
        staleTokens.push(tokens[index]);
      }
    });
    await pruneTokens(userId, staleTokens);
  } catch (error) {
    logger.error('[Push] sendToUser failed', {
      userId: userId?.toString?.(),
      message: error.message,
    });
  }
}

module.exports = {
  sendToUser,
};

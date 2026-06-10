const User = require('../models/User');
const ApiError = require('../utils/ApiError');

// Product IDs that grant Pro. Override with PRO_PRODUCT_IDS (comma separated).
const PRO_PRODUCT_IDS = (process.env.PRO_PRODUCT_IDS || 'hamme_pro_weekly')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);

// Subscription states (Play Developer API v2) that count as an active entitlement.
const ACTIVE_SUBSCRIPTION_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
]);

let androidPublisherPromise = null;

/**
 * Lazily build an authenticated Google Play Android Publisher client.
 * Returns null when no service-account credentials are configured so callers
 * can decide how to handle an unconfigured environment.
 */
async function getAndroidPublisher() {
  if (androidPublisherPromise) return androidPublisherPromise;

  const credentialsJson = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
  const credentialsFile = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_FILE;
  if (!credentialsJson && !credentialsFile) {
    return null;
  }

  androidPublisherPromise = (async () => {
    // Lazy require so the backend still boots if googleapis isn't installed yet.
    // eslint-disable-next-line global-require
    const { google } = require('googleapis');
    const authOptions = {
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    };
    if (credentialsJson) {
      authOptions.credentials = JSON.parse(credentialsJson);
    } else {
      authOptions.keyFile = credentialsFile;
    }
    const auth = new google.auth.GoogleAuth(authOptions);
    const authClient = await auth.getClient();
    return google.androidpublisher({ version: 'v3', auth: authClient });
  })();

  return androidPublisherPromise;
}

/**
 * Verifies an Android subscription purchase token with Google Play.
 * @returns {{configured: boolean, valid: boolean, raw?: object}}
 */
async function verifyAndroidSubscription({ packageName, productId, purchaseToken }) {
  const publisher = await getAndroidPublisher();
  if (!publisher) {
    return { configured: false, valid: false };
  }
  if (!packageName) {
    throw new ApiError(500, 'ANDROID_PACKAGE_NAME is not configured.');
  }

  // Prefer the v2 endpoint; fall back to v1 if it isn't available.
  try {
    const response = await publisher.purchases.subscriptionsv2.get({
      packageName,
      token: purchaseToken,
    });
    const state = response.data.subscriptionState;
    return {
      configured: true,
      valid: ACTIVE_SUBSCRIPTION_STATES.has(state),
      raw: response.data,
    };
  } catch (error) {
    const response = await publisher.purchases.subscriptions.get({
      packageName,
      subscriptionId: productId,
      token: purchaseToken,
    });
    const expiry = Number(response.data.expiryTimeMillis || 0);
    return {
      configured: true,
      valid: expiry > Date.now(),
      raw: response.data,
    };
  }
}

/**
 * Verifies a purchase and, when valid, grants the Pro entitlement to the user.
 */
async function verifyPurchase(userId, payload) {
  const { platform = 'android', productId, purchaseToken } = payload || {};

  if (!productId || !purchaseToken) {
    throw new ApiError(400, 'productId and purchaseToken are required.');
  }
  if (!PRO_PRODUCT_IDS.includes(productId)) {
    throw new ApiError(400, 'Unknown product id.');
  }

  const allowUnverified = process.env.ALLOW_UNVERIFIED_IAP === 'true';
  let granted = false;

  if (platform === 'android') {
    const packageName = payload.packageName || process.env.ANDROID_PACKAGE_NAME;
    const result = await verifyAndroidSubscription({
      packageName,
      productId,
      purchaseToken,
    });

    if (!result.configured) {
      if (allowUnverified) {
        console.warn(
          '[Billing] Google Play verification not configured; granting because ALLOW_UNVERIFIED_IAP=true'
        );
        granted = true;
      } else {
        throw new ApiError(
          503,
          'Purchase verification is not configured on the server.'
        );
      }
    } else {
      granted = result.valid;
    }
  } else {
    // iOS App Store verification is not implemented yet.
    if (allowUnverified) {
      granted = true;
    } else {
      throw new ApiError(503, 'iOS purchase verification is not configured.');
    }
  }

  if (!granted) {
    throw new ApiError(402, 'Purchase could not be verified.');
  }

  const user = await User.findByIdAndUpdate(
    userId,
    {
      isPro: true,
      proProductId: productId,
      proPlatform: platform,
      proPurchaseToken: purchaseToken,
      proUpdatedAt: new Date(),
    },
    { new: true }
  );

  if (!user) {
    throw new ApiError(404, 'User not found.');
  }

  return user;
}

module.exports = {
  verifyPurchase,
  PRO_PRODUCT_IDS,
};

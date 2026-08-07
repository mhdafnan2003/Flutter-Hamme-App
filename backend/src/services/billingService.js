const { google } = require('googleapis');
const mongoose = require('mongoose');
const {
  AppStoreServerAPIClient,
  Environment,
  ReceiptUtility,
  Status,
} = require('@apple/app-store-server-library');

const User = require('../models/User');
const ApiError = require('../utils/ApiError');
const logger = require('../utils/logger');
const env = require('../config/env');
const {
  createAccessToken,
  createRefreshToken,
} = require('./tokenService');

// Product IDs that grant Pro. Override with PRO_PRODUCT_IDS (comma separated).
const PRO_PRODUCT_IDS = (process.env.PRO_PRODUCT_IDS || 'hamme_pro_weekly')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);

const ACTIVE_SUBSCRIPTION_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
]);

let androidPublisherPromise = null;
let oidcVerifier = null;
const appleClients = new Map();

function getConfiguredPackageName() {
  return (process.env.ANDROID_PACKAGE_NAME || '').trim();
}

function ensurePackageName(packageName) {
  const configured = getConfiguredPackageName();
  if (!configured) {
    throw new ApiError(503, 'ANDROID_PACKAGE_NAME is not configured.');
  }
  if (packageName && packageName !== configured) {
    throw new ApiError(400, 'Purchase package name does not match this app.');
  }
  return configured;
}

async function getAndroidPublisher() {
  if (androidPublisherPromise) return androidPublisherPromise;

  const credentialsJson = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
  const credentialsFile = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_FILE;
  if (!credentialsJson && !credentialsFile) return null;

  androidPublisherPromise = (async () => {
    const authOptions = {
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    };
    if (credentialsJson) {
      try {
        authOptions.credentials = JSON.parse(credentialsJson);
      } catch (_) {
        throw new ApiError(
          500,
          'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON contains invalid JSON.'
        );
      }
    } else {
      authOptions.keyFile = credentialsFile;
    }

    const auth = new google.auth.GoogleAuth(authOptions);
    const authClient = await auth.getClient();
    return google.androidpublisher({ version: 'v3', auth: authClient });
  })();

  try {
    return await androidPublisherPromise;
  } catch (error) {
    androidPublisherPromise = null;
    throw error;
  }
}

function approvedLineItems(subscription) {
  return (subscription.lineItems || []).filter(
    (item) => item.productId && PRO_PRODUCT_IDS.includes(item.productId)
  );
}

function latestExpiry(lineItems) {
  let latest = null;
  for (const item of lineItems) {
    const parsed = item.expiryTime ? new Date(item.expiryTime) : null;
    if (parsed && !Number.isNaN(parsed.getTime())) {
      if (!latest || parsed > latest) latest = parsed;
    }
  }
  return latest;
}

function isEntitled(subscription, expiryAt) {
  const paidPeriodRemaining = Boolean(
    expiryAt && expiryAt.getTime() > Date.now()
  );
  if (ACTIVE_SUBSCRIPTION_STATES.has(subscription.subscriptionState)) {
    return paidPeriodRemaining;
  }

  // A user who cancels keeps access through the already-paid billing period.
  return (
    subscription.subscriptionState === 'SUBSCRIPTION_STATE_CANCELED' &&
    paidPeriodRemaining
  );
}

function subscriptionSnapshot(raw) {
  const lineItems = approvedLineItems(raw);
  if (lineItems.length === 0) {
    throw new ApiError(
      402,
      'The Google Play purchase does not contain an approved Pro product.'
    );
  }

  const expiryAt = latestExpiry(lineItems);
  return {
    raw,
    productIds: [...new Set(lineItems.map((item) => item.productId))],
    productId: lineItems[0].productId,
    state: raw.subscriptionState || 'SUBSCRIPTION_STATE_UNSPECIFIED',
    expiryAt,
    active: isEntitled(raw, expiryAt),
    autoRenewing: lineItems.some(
      (item) => item.autoRenewingPlan?.autoRenewEnabled === true
    ),
    linkedPurchaseToken: raw.linkedPurchaseToken || null,
    acknowledgementPending:
      raw.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING',
  };
}

async function fetchSubscription(purchaseToken, packageName) {
  const publisher = await getAndroidPublisher();
  if (!publisher) {
    throw new ApiError(
      503,
      'Google Play purchase verification is not configured on the server.'
    );
  }

  const resolvedPackageName = ensurePackageName(packageName);
  try {
    const response = await publisher.purchases.subscriptionsv2.get({
      packageName: resolvedPackageName,
      token: purchaseToken,
    });
    return subscriptionSnapshot(response.data);
  } catch (error) {
    if (error instanceof ApiError) throw error;
    const status = Number(error?.code || error?.response?.status);
    if ([400, 404, 410].includes(status)) {
      throw new ApiError(402, 'Google Play could not find an active purchase.');
    }
    if ([401, 403].includes(status)) {
      throw new ApiError(
        503,
        'Google Play verification credentials are not authorized.'
      );
    }
    throw new ApiError(503, 'Google Play verification is temporarily unavailable.');
  }
}

function applePrivateKey() {
  const encoded = env.appleIapPrivateKeyBase64.trim();
  if (!encoded || !env.appleIapIssuerId || !env.appleIapKeyId || !env.appleIapBundleId) {
    throw new ApiError(
      503,
      'Apple purchase verification is not configured on the server.'
    );
  }

  let privateKey;
  try {
    privateKey = Buffer.from(encoded, 'base64').toString('utf8');
  } catch (_) {
    throw new ApiError(500, 'APPLE_IAP_PRIVATE_KEY_BASE64 is invalid.');
  }
  if (!privateKey.includes('BEGIN PRIVATE KEY')) {
    throw new ApiError(500, 'APPLE_IAP_PRIVATE_KEY_BASE64 is invalid.');
  }
  return privateKey;
}

function getAppleClient(environment) {
  const existing = appleClients.get(environment);
  if (existing) return existing;

  const client = new AppStoreServerAPIClient(
    applePrivateKey(),
    env.appleIapKeyId,
    env.appleIapIssuerId,
    env.appleIapBundleId,
    environment
  );
  appleClients.set(environment, client);
  return client;
}

function decodeAppleJwsPayload(jws) {
  const parts = typeof jws === 'string' ? jws.split('.') : [];
  if (parts.length !== 3) {
    throw new ApiError(502, 'Apple returned invalid subscription data.');
  }
  try {
    const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(Buffer.from(base64, 'base64').toString('utf8'));
  } catch (_) {
    throw new ApiError(502, 'Apple returned invalid subscription data.');
  }
}

function extractAppleTransactionId(receiptOrJws) {
  if (typeof receiptOrJws !== 'string' || !receiptOrJws.trim()) {
    throw new ApiError(400, 'Apple purchase receipt is required.');
  }

  // StoreKit 2 sends a transaction JWS, while the default Flutter StoreKit
  // implementation sends a base64 app receipt. Both are supported.
  if (receiptOrJws.split('.').length === 3) {
    const transactionId = decodeAppleJwsPayload(receiptOrJws).transactionId;
    if (transactionId) return transactionId.toString();
  }

  try {
    const transactionId = new ReceiptUtility().extractTransactionIdFromAppReceipt(
      receiptOrJws
    );
    if (transactionId) return transactionId;
  } catch (_) {
    // The client-visible error below intentionally avoids receipt details.
  }
  throw new ApiError(402, 'Apple could not read this purchase receipt.');
}

function appleStatusIsActive(status, expiresAt, revoked) {
  if (revoked || !expiresAt || expiresAt.getTime() <= Date.now()) return false;
  return status === Status.ACTIVE || status === Status.BILLING_GRACE_PERIOD;
}

function appleSubscriptionSnapshot(statusResponse) {
  if (statusResponse.bundleId !== env.appleIapBundleId) {
    throw new ApiError(402, 'Apple purchase does not belong to this app.');
  }
  if (
    statusResponse.environment === Environment.PRODUCTION &&
    env.appleIapAppId &&
    String(statusResponse.appAppleId || '') !== env.appleIapAppId.trim()
  ) {
    throw new ApiError(402, 'Apple purchase does not belong to this app.');
  }

  const candidates = [];
  for (const group of statusResponse.data || []) {
    for (const transaction of group.lastTransactions || []) {
      if (!transaction.signedTransactionInfo) continue;
      const decoded = decodeAppleJwsPayload(transaction.signedTransactionInfo);
      if (!PRO_PRODUCT_IDS.includes(decoded.productId)) continue;
      const expiryAt = decoded.expiresDate ? new Date(decoded.expiresDate) : null;
      if (expiryAt && Number.isNaN(expiryAt.getTime())) continue;
      const renewal = transaction.signedRenewalInfo
        ? decodeAppleJwsPayload(transaction.signedRenewalInfo)
        : null;
      candidates.push({ transaction, decoded, expiryAt, renewal });
    }
  }

  if (candidates.length === 0) {
    throw new ApiError(402, 'The Apple purchase does not contain an approved Pro product.');
  }
  candidates.sort(
    (a, b) => (b.expiryAt?.getTime() || 0) - (a.expiryAt?.getTime() || 0)
  );
  const latest = candidates[0];
  const originalTransactionId =
    latest.transaction.originalTransactionId || latest.decoded.originalTransactionId;
  if (!originalTransactionId) {
    throw new ApiError(502, 'Apple returned incomplete subscription data.');
  }

  return {
    raw: latest.decoded,
    productIds: [latest.decoded.productId],
    productId: latest.decoded.productId,
    state: `APPLE_${latest.transaction.status || 'UNKNOWN'}`,
    expiryAt: latest.expiryAt,
    active: appleStatusIsActive(
      latest.transaction.status,
      latest.expiryAt,
      Boolean(latest.decoded.revocationDate)
    ),
    autoRenewing: latest.renewal?.autoRenewStatus === 1,
    linkedPurchaseToken: null,
    acknowledgementPending: false,
    originalTransactionId: originalTransactionId.toString(),
  };
}

async function fetchAppleSubscription(receiptOrJws) {
  const transactionId = extractAppleTransactionId(receiptOrJws);
  let lastError;
  // App Review and TestFlight use Sandbox; production customers use Production.
  // Querying both lets the receipt determine its environment without trusting
  // a client-supplied environment field.
  for (const environment of [Environment.PRODUCTION, Environment.SANDBOX]) {
    try {
      const statusResponse = await getAppleClient(environment)
        .getAllSubscriptionStatuses(transactionId);
      return appleSubscriptionSnapshot(statusResponse);
    } catch (error) {
      if (error instanceof ApiError) throw error;
      lastError = error;
    }
  }

  logger.error('Apple subscription lookup failed', {
    message: lastError?.message,
    status: lastError?.httpStatusCode,
  });
  throw new ApiError(402, 'Apple could not find an active purchase.');
}

function hasLegacyAdminGrant(user) {
  return user.adminPro || (user.proPlatform === 'admin' && user.isPro);
}

async function saveSubscriptionSnapshot(
  user,
  purchaseToken,
  snapshot,
  platform = 'android'
) {
  // Migrate an old admin grant into its dedicated field before overwriting
  // legacy proPlatform data with the store platform.
  user.adminPro = hasLegacyAdminGrant(user);
  user.storeProActive = snapshot.active;
  user.isPro = user.adminPro || user.storeProActive;
  user.proProductId = snapshot.productId;
  user.proPlatform = platform;
  user.proPurchaseToken = purchaseToken;
  user.proSubscriptionState = snapshot.state;
  user.proExpiryAt = snapshot.expiryAt;
  user.proAutoRenewing = snapshot.autoRenewing;
  user.proLastVerifiedAt = new Date();
  user.proUpdatedAt = new Date();

  try {
    await user.save();
  } catch (error) {
    if (error?.code === 11000) {
      throw new ApiError(
        409,
        'This Google Play purchase is already linked to another Hamme account.'
      );
    }
    throw error;
  }
  return user;
}

async function markStoreSubscriptionInactive(user, state) {
  user.adminPro = hasLegacyAdminGrant(user);
  user.storeProActive = false;
  user.isPro = user.adminPro;
  user.proSubscriptionState = state;
  user.proAutoRenewing = false;
  user.proLastVerifiedAt = new Date();
  user.proUpdatedAt = new Date();
  await user.save();
  return user;
}

async function assertTokenOwnership(userId, purchaseToken, linkedPurchaseToken) {
  const tokenOwner = await User.findOne({ proPurchaseToken: purchaseToken })
    .select('+proPurchaseToken')
    .lean();
  if (tokenOwner && tokenOwner._id.toString() !== userId.toString()) {
    throw new ApiError(
      409,
      'This Google Play purchase is already linked to another Hamme account.'
    );
  }

  if (linkedPurchaseToken) {
    const linkedOwner = await User.findOne({
      proPurchaseToken: linkedPurchaseToken,
    })
      .select('+proPurchaseToken')
      .lean();
    if (linkedOwner && linkedOwner._id.toString() !== userId.toString()) {
      throw new ApiError(
        409,
        'The previous subscription is linked to another Hamme account.'
      );
    }
  }
}

async function acknowledgeSubscription(purchaseToken, productId, packageName) {
  const publisher = await getAndroidPublisher();
  if (!publisher) return;

  try {
    await publisher.purchases.subscriptions.acknowledge({
      packageName: ensurePackageName(packageName),
      subscriptionId: productId,
      token: purchaseToken,
      requestBody: {},
    });
  } catch (error) {
    // A concurrent client/server acknowledgement is harmless.
    if (Number(error?.code) === 409) return;
    throw error;
  }
}

/**
 * Verifies a purchase against Google, binds its globally unique token to one
 * Hamme account, grants/revokes the paid entitlement, and acknowledges the
 * initial purchase.
 */
async function verifyPurchase(userId, payload) {
  const { platform = 'android', productId, purchaseToken } = payload || {};
  if (!productId || !purchaseToken) {
    throw new ApiError(400, 'productId and purchaseToken are required.');
  }
  if (!PRO_PRODUCT_IDS.includes(productId)) {
    throw new ApiError(400, 'Unknown product id.');
  }

  const isIos = platform === 'ios';
  const snapshot = isIos
    ? await fetchAppleSubscription(purchaseToken)
    : await fetchSubscription(purchaseToken, payload.packageName);
  // Never trust the product ID supplied by the device; require the verified
  // Google response to contain that same product.
  if (!snapshot.productIds.includes(productId)) {
    throw new ApiError(402, 'Purchase token does not match the requested product.');
  }
  const googleAccountId =
    snapshot.raw.externalAccountIdentifiers?.obfuscatedExternalAccountId;
  if (googleAccountId && googleAccountId !== userId.toString()) {
    throw new ApiError(
      409,
      'This Google Play purchase was started by another Hamme account.'
    );
  }
  if (!snapshot.active) {
    throw new ApiError(402, 'The subscription is not currently entitled to Pro.');
  }

  const ownershipToken = isIos
    ? snapshot.originalTransactionId
    : purchaseToken;
  await assertTokenOwnership(userId, ownershipToken, snapshot.linkedPurchaseToken);

  const user = await User.findById(userId).select('+proPurchaseToken');
  if (!user) throw new ApiError(404, 'User not found.');
  await saveSubscriptionSnapshot(user, ownershipToken, snapshot, platform);

  if (snapshot.acknowledgementPending) {
    try {
      await acknowledgeSubscription(
        purchaseToken,
        snapshot.productId,
        payload.packageName
      );
    } catch (error) {
      // The Flutter client also acknowledges after this endpoint succeeds.
      // Keep the verified entitlement and allow that fallback to run.
      logger.error('Server-side subscription acknowledgement failed', {
        userId: user.id,
        message: error.message,
      });
    }
  }

  return user;
}

/**
 * Recovers the original Hamme session after reinstall. Possession of a Play
 * purchase token alone is not trusted: Google must verify that it belongs to
 * this package, contains an approved active product, and is already linked to
 * the returned Hamme account (by stored token or Google's obfuscated account
 * identifier).
 */
async function restoreSessionFromPurchase(payload) {
  const { platform = 'android', productId, purchaseToken } = payload || {};
  if (!productId || !purchaseToken) {
    throw new ApiError(400, 'productId and purchaseToken are required.');
  }
  if (!PRO_PRODUCT_IDS.includes(productId)) {
    throw new ApiError(400, 'Unknown product id.');
  }

  const isIos = platform === 'ios';
  const snapshot = isIos
    ? await fetchAppleSubscription(purchaseToken)
    : await fetchSubscription(purchaseToken, payload.packageName);
  if (!snapshot.productIds.includes(productId)) {
    throw new ApiError(402, 'Purchase token does not match the requested product.');
  }
  if (!snapshot.active) {
    throw new ApiError(402, 'The subscription is not currently entitled to Pro.');
  }

  const ownershipToken = isIos
    ? snapshot.originalTransactionId
    : purchaseToken;
  let user = await User.findOne({ proPurchaseToken: ownershipToken }).select(
    '+proPurchaseToken'
  );
  if (!user) {
    const externalAccountId =
      snapshot.raw.externalAccountIdentifiers?.obfuscatedExternalAccountId;
    if (mongoose.isValidObjectId(externalAccountId)) {
      const attributedUser = await User.findById(externalAccountId).select(
        '+proPurchaseToken'
      );
      const tokenIsCompatible =
        attributedUser &&
        (!attributedUser.proPurchaseToken ||
          attributedUser.proPurchaseToken === purchaseToken ||
          attributedUser.proPurchaseToken === snapshot.linkedPurchaseToken);
      if (tokenIsCompatible) user = attributedUser;
    }
  }

  if (!user) {
    throw new ApiError(
      404,
      'No Hamme profile is linked to this Google Play subscription.'
    );
  }

  await saveSubscriptionSnapshot(user, ownershipToken, snapshot, platform);

  if (snapshot.acknowledgementPending) {
    try {
      await acknowledgeSubscription(
        purchaseToken,
        snapshot.productId,
        payload.packageName
      );
    } catch (error) {
      logger.error('Restored subscription acknowledgement failed', {
        userId: user.id,
        message: error.message,
      });
    }
  }

  const accessToken = createAccessToken(user);
  const refreshToken = createRefreshToken(user);
  await User.findByIdAndUpdate(user.id, {
    $push: {
      refreshTokens: {
        $each: [refreshToken],
        $slice: -10,
      },
    },
  });

  return {
    accessToken,
    refreshToken,
    user,
  };
}

/**
 * Re-checks the store token owned by a user. This gives the app a safe
 * reconciliation path in addition to RTDN delivery.
 */
async function syncUserSubscription(userId) {
  const user = await User.findById(userId).select('+proPurchaseToken');
  if (!user) throw new ApiError(404, 'User not found.');

  if (!user.proPurchaseToken) {
    user.adminPro = hasLegacyAdminGrant(user);
    user.storeProActive = false;
    user.isPro = user.adminPro;
    await user.save();
    return user;
  }

  try {
    const isIos = user.proPlatform === 'ios';
    const snapshot = isIos
      ? await fetchAppleSubscription(user.proPurchaseToken)
      : await fetchSubscription(user.proPurchaseToken);
    return saveSubscriptionSnapshot(
      user,
      isIos ? snapshot.originalTransactionId : user.proPurchaseToken,
      snapshot,
      isIos ? 'ios' : 'android'
    );
  } catch (error) {
    if (error instanceof ApiError && error.statusCode === 402) {
      return markStoreSubscriptionInactive(
        user,
        'SUBSCRIPTION_STATE_EXPIRED'
      );
    }
    throw error;
  }
}

async function verifyRtdnAuthorization(authorizationHeader) {
  const audience = (process.env.GOOGLE_PLAY_RTDN_AUDIENCE || '').trim();
  if (!audience) {
    throw new ApiError(503, 'GOOGLE_PLAY_RTDN_AUDIENCE is not configured.');
  }

  const match = /^Bearer\s+(.+)$/i.exec(authorizationHeader || '');
  if (!match) throw new ApiError(401, 'Missing RTDN authorization token.');

  oidcVerifier ||= new google.auth.OAuth2();
  let ticket;
  try {
    ticket = await oidcVerifier.verifyIdToken({
      idToken: match[1],
      audience,
    });
  } catch (_) {
    throw new ApiError(401, 'Invalid RTDN authorization token.');
  }

  const payload = ticket.getPayload();
  const expectedEmail = (
    process.env.GOOGLE_PLAY_RTDN_SERVICE_ACCOUNT_EMAIL || ''
  ).trim();
  if (
    payload?.email_verified !== true ||
    (expectedEmail && payload.email !== expectedEmail)
  ) {
    throw new ApiError(401, 'RTDN service account is not authorized.');
  }
}

function decodeDeveloperNotification(pubsubEnvelope) {
  const encoded = pubsubEnvelope?.message?.data;
  if (!encoded || typeof encoded !== 'string') {
    throw new ApiError(400, 'RTDN message data is required.');
  }

  try {
    return JSON.parse(Buffer.from(encoded, 'base64').toString('utf8'));
  } catch (_) {
    throw new ApiError(400, 'RTDN message data is invalid.');
  }
}

/**
 * Pub/Sub notifications contain only a token and event type. Always query the
 * Developer API for current state instead of trusting the notification type.
 * Reprocessing is intentionally idempotent, so Pub/Sub retries are safe.
 */
async function processRtdn(pubsubEnvelope) {
  const notification = decodeDeveloperNotification(pubsubEnvelope);
  if (notification.testNotification) {
    return { test: true, updated: false };
  }

  ensurePackageName(notification.packageName);
  const subscriptionNotification = notification.subscriptionNotification;
  if (!subscriptionNotification) {
    // The same Play topic can also carry one-time-product notifications.
    return { test: false, updated: false, ignored: true };
  }
  const purchaseToken = subscriptionNotification.purchaseToken;
  if (!purchaseToken) {
    throw new ApiError(400, 'RTDN subscription purchase token is required.');
  }

  let snapshot;
  try {
    snapshot = await fetchSubscription(
      purchaseToken,
      notification.packageName
    );
  } catch (error) {
    if (error instanceof ApiError && error.statusCode === 402) {
      const expiredUser = await User.findOne({
        proPurchaseToken: purchaseToken,
      }).select('+proPurchaseToken');
      if (expiredUser) {
        await markStoreSubscriptionInactive(
          expiredUser,
          'SUBSCRIPTION_STATE_EXPIRED'
        );
        return {
          test: false,
          updated: true,
          userId: expiredUser.id,
          active: false,
          state: 'SUBSCRIPTION_STATE_EXPIRED',
        };
      }
      return { test: false, updated: false };
    }
    throw error;
  }

  let user = await User.findOne({ proPurchaseToken: purchaseToken }).select(
    '+proPurchaseToken'
  );
  // Upgrades can produce a new token. Google links it to the prior token, which
  // lets us safely retain the same Hamme owner.
  if (!user && snapshot.linkedPurchaseToken) {
    user = await User.findOne({
      proPurchaseToken: snapshot.linkedPurchaseToken,
    }).select('+proPurchaseToken');
  }
  if (!user) {
    const externalAccountId =
      snapshot.raw.externalAccountIdentifiers?.obfuscatedExternalAccountId;
    if (mongoose.isValidObjectId(externalAccountId)) {
      const attributedUser = await User.findById(externalAccountId).select(
        '+proPurchaseToken'
      );
      // A modified client must not be able to replace an unrelated token by
      // supplying another user's id as its obfuscated account identifier.
      const mayReplaceToken =
        attributedUser &&
        (!attributedUser.proPurchaseToken ||
          attributedUser.proPurchaseToken === purchaseToken ||
          attributedUser.proPurchaseToken === snapshot.linkedPurchaseToken);
      if (mayReplaceToken) user = attributedUser;
    }
  }

  if (!user) {
    logger.info('RTDN token has no Hamme account owner yet', {
      messageId: pubsubEnvelope?.message?.messageId,
      state: snapshot.state,
    });
    return { test: false, updated: false };
  }

  await saveSubscriptionSnapshot(user, purchaseToken, snapshot);
  return {
    test: false,
    updated: true,
    userId: user.id,
    active: snapshot.active,
    state: snapshot.state,
  };
}

module.exports = {
  PRO_PRODUCT_IDS,
  processRtdn,
  restoreSessionFromPurchase,
  syncUserSubscription,
  verifyPurchase,
  verifyRtdnAuthorization,
};

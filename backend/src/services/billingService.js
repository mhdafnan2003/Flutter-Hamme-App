// Only the Play Developer API client. The full `googleapis` package loads all
// ~300 Google APIs and added ~100 MB of resident memory to the process.
const {
  androidpublisher,
  auth: googleAuth,
} = require('@googleapis/androidpublisher');
const mongoose = require('mongoose');
const fs = require('node:fs');
const path = require('node:path');
const {
  AppStoreServerAPIClient,
  Environment,
  Status,
  SignedDataVerifier,
} = require('@apple/app-store-server-library');

const User = require('../models/User');
const BillingOwnership = require('../models/BillingOwnership');
const ApiError = require('../utils/ApiError');
const logger = require('../utils/logger');
const env = require('../config/env');

// Product IDs that grant Pro. Override with PRO_PRODUCT_IDS (comma separated).
const PRO_PRODUCT_IDS = (process.env.PRO_PRODUCT_IDS || 'hamme_pro_weekly')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);

// Never let a slow Google response hold a request (and its memory) open.
const GOOGLE_API_TIMEOUT_MS = 10 * 1000;
// RTDN keeps store subscriptions current; the app's status check only repairs
// a missed notification, so don't re-ask the store more often than this.
const STORE_RECHECK_INTERVAL_MS = 12 * 60 * 60 * 1000;

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
    if (env.allowUnverifiedIap) {
      return packageName || 'com.hamme.app';
    }
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

    const auth = new googleAuth.GoogleAuth(authOptions);
    const authClient = await auth.getClient();
    return androidpublisher({ version: 'v3', auth: authClient });
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

function playAuthorizationError(googleMessage) {
  const message = (googleMessage || '').toLowerCase();
  if (message.includes('has not been linked')) {
    return 'Google Cloud project hamme-app is not linked in Play Console > Setup > API access.';
  }
  if (message.includes('access not configured') || message.includes('has not been used')) {
    return 'Google Play Android Developer API is not enabled on Cloud project hamme-app.';
  }
  if (message.includes('insufficient permissions') || message.includes('permission')) {
    return 'Play Console user hamme-play-billing@hamme-app.iam.gserviceaccount.com is missing financial/orders access on com.hamme.app.';
  }
  return 'Google Play verification credentials are not authorized.';
}

async function fetchSubscription(purchaseToken, packageName) {
  const publisher = await getAndroidPublisher();
  if (!publisher) {
    if (env.allowUnverifiedIap) {
      logger.warn(
        '[Billing] Bypassing Google Play verification in development mode (ALLOW_UNVERIFIED_IAP=true).'
      );
      const now = new Date();
      const expiryAt = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
      return {
        raw: {
          subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
          externalAccountIdentifiers: {},
        },
        productIds: PRO_PRODUCT_IDS,
        productId: PRO_PRODUCT_IDS[0] || 'hamme_pro_weekly',
        state: 'SUBSCRIPTION_STATE_ACTIVE',
        expiryAt,
        active: true,
        autoRenewing: true,
        linkedPurchaseToken: null,
        acknowledgementPending: false,
      };
    }
    throw new ApiError(
      503,
      'Google Play purchase verification is not configured on the server.'
    );
  }

  const resolvedPackageName = ensurePackageName(packageName);
  try {
    const response = await publisher.purchases.subscriptionsv2.get(
      {
        packageName: resolvedPackageName,
        token: purchaseToken,
      },
      { timeout: GOOGLE_API_TIMEOUT_MS }
    );
    return subscriptionSnapshot(response.data);
  } catch (error) {
    if (error instanceof ApiError) throw error;
    const status = Number(error?.code || error?.response?.status);
    const googleDetail =
      error?.errors?.[0]?.message ||
      error?.response?.data?.error?.message ||
      error?.message ||
      '';
    logger.error('Google Play subscription lookup failed', {
      status,
      message: googleDetail,
    });
    if ([400, 404, 410].includes(status)) {
      throw new ApiError(402, 'Google Play could not find an active purchase.');
    }
    if ([401, 403].includes(status)) {
      throw new ApiError(
        503,
        `${playAuthorizationError(googleDetail)}${googleDetail ? ` (${status}: ${googleDetail})` : ` (${status})`}`
      );
    }
    throw new ApiError(
      503,
      `Google Play verification is temporarily unavailable${googleDetail ? ` (${status}: ${googleDetail})` : ''}.`
    );
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
    expiryAt: latest.transaction.status === Status.BILLING_GRACE_PERIOD && latest.renewal?.gracePeriodExpiresDate
      ? new Date(latest.renewal.gracePeriodExpiresDate) : latest.expiryAt,
    active: appleStatusIsActive(
      latest.transaction.status,
      latest.transaction.status === Status.BILLING_GRACE_PERIOD && latest.renewal?.gracePeriodExpiresDate
        ? new Date(latest.renewal.gracePeriodExpiresDate) : latest.expiryAt,
      Boolean(latest.decoded.revocationDate)
    ),
    autoRenewing: latest.renewal?.autoRenewStatus === 1,
    linkedPurchaseToken: null,
    acknowledgementPending: false,
    originalTransactionId: originalTransactionId.toString(),
  };
}

async function fetchAppleSubscription(receiptOrJws, trustedTransactionId = false) {
  const isAppleConfigured =
    Boolean(env.appleIapPrivateKeyBase64 &&
    env.appleIapIssuerId &&
    env.appleIapKeyId &&
    env.appleIapBundleId);

  if (!isAppleConfigured && env.allowUnverifiedIap) {
    logger.warn(
      '[Billing] Bypassing Apple purchase verification in development mode (ALLOW_UNVERIFIED_IAP=true).'
    );
    const now = new Date();
    const expiryAt = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
    const originalTransactionId =
      typeof receiptOrJws === 'string' && receiptOrJws.trim().length > 0
        ? receiptOrJws.trim().slice(0, 64)
        : 'dev_mock_transaction_id';
    return {
      raw: {},
      productIds: PRO_PRODUCT_IDS,
      productId: PRO_PRODUCT_IDS[0] || 'hamme_pro_weekly',
      state: 'APPLE_ACTIVE',
      expiryAt,
      active: true,
      autoRenewing: true,
      originalTransactionId,
    };
  }

  let transactionId;
  if (trustedTransactionId) {
    transactionId = receiptOrJws;
  } else if (receiptOrJws.split('.').length === 3) {
    const hint = decodeAppleJwsPayload(receiptOrJws);
    if (![Environment.PRODUCTION, Environment.SANDBOX].includes(hint.environment)) {
      throw new ApiError(402, 'Apple purchase environment is invalid.');
    }
    const appId = Number(env.appleIapAppId);
    if (hint.environment === Environment.PRODUCTION && !appId) {
      throw new ApiError(503, 'APPLE_IAP_APP_ID is required for production purchase verification.');
    }
    const verifier = new SignedDataVerifier(
      [fs.readFileSync(path.join(__dirname, '../certificates/AppleRootCA-G3.cer'))],
      true, hint.environment, env.appleIapBundleId,
      hint.environment === Environment.PRODUCTION ? appId : undefined
    );
    try {
      const verified = await verifier.verifyAndDecodeTransaction(receiptOrJws);
      transactionId = verified.transactionId;
    } catch (_) {
      throw new ApiError(402, 'Apple purchase signature could not be verified.');
    }
  } else {
    throw new ApiError(402, 'A signed Apple transaction is required. Update Hamme and restore your purchase again.');
  }
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

let ownershipIndexesReady;
async function ensureOwnershipIndexes() {
  ownershipIndexesReady ||= (async () => {
    // MongoDB cannot reuse a unique index key on a different document within
    // one transaction. Move uniqueness to a stable subscription record first.
    await BillingOwnership.init();
    await User.collection.createIndex({ proPurchaseToken: 1 }, {
      name: 'pro_purchase_lookup',
      partialFilterExpression: { proPurchaseToken: { $type: 'string' } },
    });
    try {
      await User.collection.dropIndex('proPurchaseToken_1');
    } catch (error) {
      if (error.code !== 27 && error.codeName !== 'IndexNotFound') throw error;
    }
  })().catch((error) => { ownershipIndexesReady = null; throw error; });
  return ownershipIndexesReady;
}

async function saveSubscriptionSnapshot(
  user,
  purchaseToken,
  snapshot,
  platform = 'android'
) {
  await ensureOwnershipIndexes();
  const session = user.$session();
  // The ownership update and entitlement save must commit together, including
  // RTDN and status refreshes racing a profile transfer.
  if (!session) {
    const transaction = await mongoose.startSession();
    try {
      let saved;
      await transaction.withTransaction(async () => {
        const current = await User.findById(user.id).select('+proPurchaseToken').session(transaction);
        if (!current) throw new ApiError(404, 'User not found.');
        saved = await saveSubscriptionSnapshot(current, purchaseToken, snapshot, platform);
      });
      return saved;
    } finally {
      await transaction.endSession();
    }
  }
  const key = `${platform}:${purchaseToken}`;
  const ownership = await BillingOwnership.findById(key).session(session);
  if (ownership && ownership.userId.toString() !== user.id) {
    throw new ApiError(409, 'Restore this subscription to your current profile.', { code: 'RESTORE_REQUIRED' });
  }
  await BillingOwnership.findOneAndUpdate({ _id: key }, {
    $set: { userId: user.id }, $inc: { revision: 1 },
  }, { upsert: true, session });
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
        'This subscription is already linked to another Hamme profile. Restore it to this profile.',
        { code: 'RESTORE_REQUIRED' }
      );
    }
    throw error;
  }
  return user;
}

async function markStoreSubscriptionInactive(user, state) {
  const adminPro = hasLegacyAdminGrant(user);
  await User.updateOne({ _id: user.id, proPurchaseToken: user.proPurchaseToken }, {
    $set: {
      adminPro, storeProActive: false, isPro: adminPro,
      proSubscriptionState: state, proAutoRenewing: false,
      proLastVerifiedAt: new Date(), proUpdatedAt: new Date(),
    },
  });
  return User.findById(user.id).select('+proPurchaseToken');
}

async function assertTokenOwnership(userId, purchaseToken, linkedPurchaseToken) {
  const tokenOwner = await User.findOne({ proPurchaseToken: purchaseToken })
    .select('+proPurchaseToken')
    .lean();
  if (tokenOwner && tokenOwner._id.toString() !== userId.toString()) {
    throw new ApiError(
      409,
      'Restore this subscription to your current Hamme profile.',
      { code: 'RESTORE_REQUIRED' }
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
        'Restore this subscription to your current Hamme profile.',
        { code: 'RESTORE_REQUIRED' }
      );
    }
  }
}

async function acknowledgeSubscription(purchaseToken, productId, packageName) {
  const publisher = await getAndroidPublisher();
  if (!publisher) return;

  try {
    await publisher.purchases.subscriptions.acknowledge(
      {
        packageName: ensurePackageName(packageName),
        subscriptionId: productId,
        token: purchaseToken,
        requestBody: {},
      },
      { timeout: GOOGLE_API_TIMEOUT_MS }
    );
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
  const currentOwner = await User.findOne({ proPurchaseToken: purchaseToken }).lean();
  if (googleAccountId && googleAccountId !== userId.toString() &&
      currentOwner?._id.toString() !== userId.toString()) {
    throw new ApiError(
      409,
      'Restore this subscription to your current Hamme profile.',
      { code: 'RESTORE_REQUIRED' }
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
  const verifiedUser = await saveSubscriptionSnapshot(user, ownershipToken, snapshot, platform);

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

  return verifiedUser;
}

/** Restore a store-verified subscription to the authenticated current profile.
 * The transaction revokes the old owner's store grant and assigns the new one
 * together. A store purchase never acts as a login credential for profile data.
 */
async function restorePurchase(userId, payload) {
  const { platform = 'android', productId, purchaseToken, confirmTransfer } = payload || {};
  if (!['android', 'ios'].includes(platform) || !purchaseToken ||
      !PRO_PRODUCT_IDS.includes(productId)) {
    throw new ApiError(400, 'A supported platform, Pro product and purchase token are required.');
  }
  const snapshot = platform === 'ios'
    ? await fetchAppleSubscription(purchaseToken)
    : await fetchSubscription(purchaseToken, payload.packageName);
  if (!snapshot.productIds.includes(productId) || !snapshot.active) {
    throw new ApiError(402, 'No active Pro subscription was found. Check the store account used to purchase Pro.');
  }
  const ownershipToken = platform === 'ios' ? snapshot.originalTransactionId : purchaseToken;
  const tokens = [ownershipToken, snapshot.linkedPurchaseToken].filter(Boolean);
  let restoredUser;
  await ensureOwnershipIndexes();
  const session = await mongoose.startSession();
  try {
    await session.withTransaction(async () => {
      const user = await User.findById(userId).select('+proPurchaseToken').session(session);
      if (!user) throw new ApiError(404, 'User not found.');
      const owners = await User.find({ proPurchaseToken: { $in: tokens } })
        .select('+proPurchaseToken').session(session);
      if (user.proPurchaseToken !== ownershipToken && confirmTransfer !== true) {
        throw new ApiError(409, 'An active Pro subscription was found. Restore it to this Hamme profile?',
          { code: 'RESTORE_REQUIRED' });
      }
      if (user.proPurchaseToken && !tokens.includes(user.proPurchaseToken) && user.storeProActive &&
          user.proExpiryAt && user.proExpiryAt > new Date()) {
        throw new ApiError(409, 'This profile already has another active subscription. Manage it in its store before restoring a different one.');
      }
      // Updating a stable record makes competing restores conflict/retry.
      for (const token of tokens) {
        await BillingOwnership.findOneAndUpdate({ _id: `${platform}:${token}` }, {
          $set: { userId: user.id }, $inc: { revision: 1 },
        }, { upsert: true, session });
      }
      for (const owner of owners) {
        if (owner.id === user.id) continue;
        owner.adminPro = hasLegacyAdminGrant(owner);
        owner.isPro = owner.adminPro;
        owner.storeProActive = false;
        owner.proPurchaseToken = null;
        owner.proProductId = null;
        owner.proPlatform = owner.adminPro ? 'admin' : null;
        owner.proSubscriptionState = 'TRANSFERRED';
        owner.proExpiryAt = null;
        owner.proAutoRenewing = false;
        owner.proLastVerifiedAt = new Date();
        owner.proUpdatedAt = new Date();
        await owner.save({ session });
      }
      // Documents loaded in the transaction retain their session for save().
      restoredUser = await saveSubscriptionSnapshot(user, ownershipToken, snapshot, platform);
    });
  } finally {
    await session.endSession();
  }
  if (snapshot.acknowledgementPending) {
    try {
      await acknowledgeSubscription(purchaseToken, snapshot.productId, payload.packageName);
    } catch (error) {
      logger.error('Restored subscription acknowledgement failed', { userId, message: error.message });
    }
  }
  return restoredUser;
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
    // save() on an unchanged document still costs a query.
    if (user.isModified()) await user.save();
    return user;
  }

  const verifiedRecently =
    user.proLastVerifiedAt &&
    Date.now() - user.proLastVerifiedAt.getTime() < STORE_RECHECK_INTERVAL_MS;
  const paidPeriodRemaining =
    user.proExpiryAt && user.proExpiryAt.getTime() > Date.now();
  if (verifiedRecently && paidPeriodRemaining) {
    return user;
  }

  try {
    const isIos = user.proPlatform === 'ios';
    const snapshot = isIos
      ? await fetchAppleSubscription(user.proPurchaseToken, true)
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

  oidcVerifier ||= new googleAuth.OAuth2();
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
    const ownership = await BillingOwnership.findById(`android:${purchaseToken}`).lean()
      || (snapshot.linkedPurchaseToken
        ? await BillingOwnership.findById(`android:${snapshot.linkedPurchaseToken}`).lean() : null);
    if (ownership) {
      user = await User.findById(ownership.userId).select('+proPurchaseToken');
      // Do not revive the original attribution after a transfer/deletion or
      // overwrite a newer subscription with an old token's delayed event.
      if (!user || (user.proPurchaseToken !== purchaseToken &&
          user.proPurchaseToken !== snapshot.linkedPurchaseToken)) {
        return { test: false, updated: false, ignored: true };
      }
    }
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
  restorePurchase,
  syncUserSubscription,
  verifyPurchase,
  verifyRtdnAuthorization,
};

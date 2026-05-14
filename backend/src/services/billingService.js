const jwt = require('jsonwebtoken');

const ApiError = require('../utils/ApiError');
const env = require('../config/env');
const BillingEntitlement = require('../models/BillingEntitlement');

const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const GOOGLE_ANDROID_SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

function resolvePrivateKey(raw) {
  if (!raw) return '';
  return raw.replace(/\\n/g, '\n');
}

function mapGoogleSubscriptionStatus(subscriptionState) {
  switch (subscriptionState) {
    case 'SUBSCRIPTION_STATE_ACTIVE':
      return { status: 'active', isPro: true };
    case 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD':
      return { status: 'grace', isPro: true };
    case 'SUBSCRIPTION_STATE_ON_HOLD':
      return { status: 'hold', isPro: false };
    case 'SUBSCRIPTION_STATE_PAUSED':
      return { status: 'paused', isPro: false };
    case 'SUBSCRIPTION_STATE_CANCELED':
      return { status: 'canceled', isPro: false };
    case 'SUBSCRIPTION_STATE_EXPIRED':
      return { status: 'expired', isPro: false };
    default:
      return { status: 'inactive', isPro: false };
  }
}

function getLatestExpiry(lineItems) {
  if (!Array.isArray(lineItems) || lineItems.length === 0) return null;
  const values = lineItems
    .map((item) => (item.expiryTime ? new Date(item.expiryTime).getTime() : null))
    .filter((value) => Number.isFinite(value));
  if (values.length === 0) return null;
  return new Date(Math.max(...values));
}

function isAnyAutoRenewing(lineItems) {
  if (!Array.isArray(lineItems)) return false;
  return lineItems.some((item) => Boolean(item.autoRenewingPlan));
}

function getPrimaryProductId(lineItems) {
  if (!Array.isArray(lineItems) || lineItems.length === 0) return 'unknown_product';
  return lineItems[0].productId || 'unknown_product';
}

async function getGoogleAccessToken() {
  const serviceEmail = env.googlePlayServiceAccountEmail;
  const privateKey = resolvePrivateKey(env.googlePlayServiceAccountPrivateKey);

  if (!serviceEmail || !privateKey) {
    throw new ApiError(
      500,
      'Google Play credentials are not configured. Set GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL and GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY.'
    );
  }

  const now = Math.floor(Date.now() / 1000);
  const assertion = jwt.sign(
    {
      iss: serviceEmail,
      scope: GOOGLE_ANDROID_SCOPE,
      aud: GOOGLE_TOKEN_URL,
      iat: now,
      exp: now + 3600,
    },
    privateKey,
    { algorithm: 'RS256' }
  );

  const response = await fetch(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!response.ok) {
    const raw = await response.text();
    throw new ApiError(502, `Unable to fetch Google access token: ${raw}`);
  }

  const payload = await response.json();
  if (!payload.access_token) {
    throw new ApiError(502, 'Google token response missing access_token.');
  }

  return payload.access_token;
}

async function verifyAndroidSubscriptionWithGoogle({ purchaseToken }) {
  const packageName = env.googlePlayPackageName;
  if (!packageName) {
    throw new ApiError(500, 'GOOGLE_PLAY_PACKAGE_NAME is not configured.');
  }

  const accessToken = await getGoogleAccessToken();
  const endpoint =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(
      packageName
    )}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;

  const response = await fetch(endpoint, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!response.ok) {
    const raw = await response.text();
    throw new ApiError(400, `Google verification failed: ${raw}`);
  }

  return response.json();
}

function buildMockVerification(token) {
  const active = token.toLowerCase().includes('mock_active') || token.toLowerCase().includes('mock_true');
  const status = active ? 'SUBSCRIPTION_STATE_ACTIVE' : 'SUBSCRIPTION_STATE_EXPIRED';
  const expiryDate = new Date(Date.now() + (active ? 7 : -1) * 24 * 60 * 60 * 1000);

  return {
    subscriptionState: status,
    lineItems: [
      {
        productId: 'hamme_pro_weekly',
        expiryTime: expiryDate.toISOString(),
        autoRenewingPlan: active ? { autoRenewEnabled: true } : undefined,
      },
    ],
    latestOrderId: `MOCK-${Date.now()}`,
  };
}

function normalizeVerificationPayload(payload) {
  const mapped = mapGoogleSubscriptionStatus(payload.subscriptionState);
  const expiryTime = getLatestExpiry(payload.lineItems);
  const isExpiredByTime = expiryTime ? expiryTime.getTime() <= Date.now() : false;
  const isPro = mapped.isPro && !isExpiredByTime;

  return {
    source: 'google_play',
    status: isPro ? mapped.status : (isExpiredByTime ? 'expired' : mapped.status),
    isPro,
    productId: getPrimaryProductId(payload.lineItems),
    orderId: payload.latestOrderId || null,
    expiryTime,
    isAutoRenewing: isAnyAutoRenewing(payload.lineItems),
    verificationPayload: payload,
  };
}

async function upsertEntitlement({ userId, purchaseToken, normalized }) {
  const update = {
    userId,
    platform: 'android',
    productId: normalized.productId,
    orderId: normalized.orderId,
    status: normalized.status,
    isAutoRenewing: normalized.isAutoRenewing,
    expiryTime: normalized.expiryTime,
    lastVerifiedAt: new Date(),
    verificationPayload: normalized.verificationPayload,
    source: normalized.source,
  };

  await BillingEntitlement.findOneAndUpdate(
    { purchaseToken },
    { $set: update, $setOnInsert: { purchaseToken } },
    { upsert: true, new: true }
  );
}

async function verifyAndroidPurchase({ userId, purchaseToken }) {
  if (!purchaseToken || purchaseToken.trim().length < 8) {
    throw new ApiError(400, 'A valid purchaseToken is required.');
  }

  const useMock = env.billingMockMode === true;
  const payload = useMock
    ? buildMockVerification(purchaseToken.trim())
    : await verifyAndroidSubscriptionWithGoogle({ purchaseToken: purchaseToken.trim() });

  const normalized = normalizeVerificationPayload(payload);
  await upsertEntitlement({ userId, purchaseToken: purchaseToken.trim(), normalized });

  return {
    isPro: normalized.isPro,
    status: normalized.status,
    source: normalized.source,
    productId: normalized.productId,
    orderId: normalized.orderId,
    expiryTime: normalized.expiryTime,
    isAutoRenewing: normalized.isAutoRenewing,
    verifiedAt: new Date(),
  };
}

async function restoreAndroidPurchases({ userId, purchaseTokens }) {
  if (!Array.isArray(purchaseTokens) || purchaseTokens.length === 0) {
    throw new ApiError(400, 'purchaseTokens must be a non-empty array.');
  }

  const results = [];
  for (const token of purchaseTokens) {
    try {
      const verified = await verifyAndroidPurchase({ userId, purchaseToken: token });
      results.push({ purchaseToken: token, success: true, ...verified });
    } catch (error) {
      results.push({ purchaseToken: token, success: false, error: error.message || 'Verification failed.' });
    }
  }

  const isPro = results.some((item) => item.success && item.isPro);
  return { isPro, results };
}

async function getCurrentEntitlement({ userId }) {
  const now = new Date();
  const active = await BillingEntitlement.findOne({
    userId,
    platform: 'android',
    status: { $in: ['active', 'grace'] },
    $or: [{ expiryTime: null }, { expiryTime: { $gt: now } }],
  })
    .sort({ expiryTime: -1, updatedAt: -1 })
    .lean();

  if (!active) {
    return {
      isPro: false,
      status: 'inactive',
      source: null,
      productId: null,
      orderId: null,
      expiryTime: null,
      isAutoRenewing: false,
      verifiedAt: null,
    };
  }

  return {
    isPro: true,
    status: active.status,
    source: active.source,
    productId: active.productId,
    orderId: active.orderId,
    expiryTime: active.expiryTime,
    isAutoRenewing: Boolean(active.isAutoRenewing),
    verifiedAt: active.lastVerifiedAt,
  };
}

module.exports = {
  verifyAndroidPurchase,
  restoreAndroidPurchases,
  getCurrentEntitlement,
};

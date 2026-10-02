const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');

function fixture({ platform = 'android', active = true, old = true, admin = false, attributed = 'old', failSave = false } = {}) {
  let users = new Map();
  let bindings = new Map();
  const token = platform === 'ios' ? 'apple-original' : 'play-token';
  if (old) users.set('old', { id: 'old', _id: 'old', proPurchaseToken: token, isPro: true, storeProActive: true, adminPro: admin });
  users.set('new', { id: 'new', _id: 'new', isPro: false });
  const query = (get, many = false) => {
    let session;
    const doc = (data) => data && {
      ...data,
      $session: () => session,
      save: async function () {
        if (failSave && this.id === 'new') throw new Error('Injected database failure');
        const saved = { ...this }; delete saved.save; delete saved.$session;
        users.set(this.id, saved);
      },
    };
    const q = {
      select: () => q, session: (s) => { session = s; return q; }, lean: () => q,
      then: (resolve, reject) => Promise.resolve().then(() => {
        const value = get(); return many ? value.map(doc) : doc(value);
      }).then(resolve, reject),
    };
    return q;
  };
  const User = {
    findById: (id) => query(() => users.get(id)),
    findOne: (filter) => query(() => [...users.values()].find(u => u.proPurchaseToken === filter.proPurchaseToken)),
    find: (filter) => query(() => [...users.values()].filter(u => filter.proPurchaseToken.$in.includes(u.proPurchaseToken)), true),
    collection: { createIndex: async () => {}, dropIndex: async () => {} },
  };
  const Ownership = {
    init: async () => {},
    findById: (id) => query(() => bindings.get(id)),
    findOneAndUpdate: async (filter, update) => bindings.set(filter._id, { userId: update.$set.userId }),
  };
  const raw = {
    subscriptionState: active ? 'SUBSCRIPTION_STATE_ACTIVE' : 'SUBSCRIPTION_STATE_EXPIRED',
    lineItems: [{ productId: 'hamme_pro_weekly', expiryTime: new Date(Date.now() + (active ? 86400000 : -86400000)).toISOString() }],
    externalAccountIdentifiers: { obfuscatedExternalAccountId: attributed },
  };
  const signed = (value) => `header.${Buffer.from(JSON.stringify(value)).toString('base64url')}.signature`;
  const appleTransaction = { transactionId: 'apple-tx', originalTransactionId: 'apple-original', productId: 'hamme_pro_weekly', expiresDate: Date.now() + (active ? 86400000 : -86400000), environment: 'Sandbox' };
  const ApiError = require('../src/utils/ApiError');
  const sandbox = {
    module: { exports: {} }, Buffer, Date, Set, Map, console, __dirname: path.resolve(__dirname, '../src/services'),
    process: { env: { GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: '{}', ANDROID_PACKAGE_NAME: 'com.hamme.app' } },
    require: (name) => {
      if (name === '../models/User') return User;
      if (name === '../models/BillingOwnership') return Ownership;
      if (name === '../utils/ApiError') return ApiError;
      if (name === '../utils/logger') return { warn() {}, info() {}, error() {} };
      if (name === '../config/env') return { appleIapPrivateKeyBase64: Buffer.from('-----BEGIN PRIVATE KEY-----').toString('base64'), appleIapIssuerId: 'issuer', appleIapKeyId: 'key', appleIapBundleId: 'com.hamme.app' };
      if (name === 'mongoose') return {
        isValidObjectId: () => false,
        startSession: async () => ({
          withTransaction: async (fn) => {
            const beforeUsers = structuredClone(users); const beforeBindings = structuredClone(bindings);
            try { return await fn(); } catch (e) { users = beforeUsers; bindings = beforeBindings; throw e; }
          }, endSession: async () => {},
        }),
      };
      if (name === '@googleapis/androidpublisher') return {
        auth: { GoogleAuth: class { async getClient() { return {}; } } },
        androidpublisher: () => ({ purchases: { subscriptionsv2: { get: async () => ({ data: raw }) } } }),
      };
      if (name === '@apple/app-store-server-library') return {
        Environment: { PRODUCTION: 'Production', SANDBOX: 'Sandbox' }, Status: { ACTIVE: 1, BILLING_GRACE_PERIOD: 4 },
        SignedDataVerifier: class { async verifyAndDecodeTransaction(value) {
          if (value !== signed(appleTransaction)) throw new Error('invalid signature');
          return appleTransaction;
        } },
        ReceiptUtility: class {},
        AppStoreServerAPIClient: class { async getAllSubscriptionStatuses() {
          return { bundleId: 'com.hamme.app', data: [{ lastTransactions: [{ status: active ? 1 : 2, originalTransactionId: 'apple-original', signedTransactionInfo: signed(appleTransaction) }] }] };
        } },
      };
      return require(name);
    },
  };
  vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, '../src/services/billingService.js'), 'utf8'), sandbox);
  return {
    service: sandbox.module.exports,
    users: () => users,
    payload: { platform, productId: 'hamme_pro_weekly', purchaseToken: platform === 'ios' ? signed(appleTransaction) : token },
  };
}

for (const platform of ['android', 'ios']) {
  test(`${platform}: linking another profile requires confirmation and makes no changes`, async () => {
    const f = fixture({ platform });
    await assert.rejects(f.service.restorePurchase('new', f.payload), e => e.statusCode === 409 && e.details.code === 'RESTORE_REQUIRED');
    assert.equal(f.users().get('old').isPro, true);
    assert.equal(f.users().get('new').isPro, false);
  });
  test(`${platform}: confirmed restore moves Pro without logging in to the old profile`, async () => {
    const f = fixture({ platform });
    const user = await f.service.restorePurchase('new', { ...f.payload, confirmTransfer: true });
    assert.equal(user.id, 'new'); assert.equal(user.isPro, true);
    assert.equal(f.users().get('old').isPro, false);
    assert.equal(f.users().get('old').proPurchaseToken, null);
    assert.equal('accessToken' in user, false);
    const repeated = await f.service.restorePurchase('new', f.payload);
    assert.equal(repeated.isPro, true);
  });
  test(`${platform}: deleted original profile does not prevent restoring Pro`, async () => {
    const f = fixture({ platform, old: false });
    const user = await f.service.restorePurchase('new', { ...f.payload, confirmTransfer: true });
    assert.equal(user.isPro, true);
  });
  test(`${platform}: expired subscriptions cannot transfer`, async () => {
    const f = fixture({ platform, active: false });
    await assert.rejects(f.service.restorePurchase('new', { ...f.payload, confirmTransfer: true }), e => e.statusCode === 402);
    assert.equal(f.users().get('new').isPro, false);
  });
}
test('transfer preserves old profile admin Pro', async () => {
  const f = fixture({ admin: true });
  await f.service.restorePurchase('new', { ...f.payload, confirmTransfer: true });
  assert.equal(f.users().get('old').isPro, true);
  assert.equal(f.users().get('old').storeProActive, false);
});
test('Apple rejects forged client transaction data before linking', async () => {
  const f = fixture({ platform: 'ios' });
  await assert.rejects(f.service.restorePurchase('new', { ...f.payload, purchaseToken: f.payload.purchaseToken + 'forged', confirmTransfer: true }), e => e.statusCode === 402);
  assert.equal(f.users().get('new').isPro, false);
});

test('fresh purchase verification returns the committed Pro entitlement', async () => {
  const f = fixture({ old: false, attributed: 'new' });
  const user = await f.service.verifyPurchase('new', f.payload);
  assert.equal(user.id, 'new');
  assert.equal(user.isPro, true);
  assert.equal(f.users().get('new').isPro, true);
});
test('database failure rolls back revocation and the new profile grant', async () => {
  const f = fixture({ failSave: true });
  await assert.rejects(f.service.restorePurchase('new', { ...f.payload, confirmTransfer: true }), /Injected database failure/);
  assert.equal(f.users().get('old').isPro, true);
  assert.equal(f.users().get('old').proPurchaseToken, 'play-token');
  assert.equal(f.users().get('new').isPro, false);
});

test('Apple status reconciliation accepts the stored original transaction ID', async () => {
  const f = fixture({ platform: 'ios' });
  await f.service.restorePurchase('new', { ...f.payload, confirmTransfer: true });
  f.users().get('new').proLastVerifiedAt = null;
  const user = await f.service.syncUserSubscription('new');
  assert.equal(user.isPro, true);
  assert.equal(user.proPurchaseToken, 'apple-original');
});

test('delayed Google notification cannot revive old attribution after token replacement', async () => {
  const f = fixture();
  await f.service.restorePurchase('new', { ...f.payload, confirmTransfer: true });
  f.users().get('new').proPurchaseToken = 'newer-play-token';
  const data = Buffer.from(JSON.stringify({
    packageName: 'com.hamme.app',
    subscriptionNotification: { purchaseToken: 'play-token' },
  })).toString('base64');
  const result = await f.service.processRtdn({ message: { data } });
  assert.equal(result.ignored, true);
  assert.equal(f.users().get('old').isPro, false);
  assert.equal(f.users().get('new').proPurchaseToken, 'newer-play-token');
});

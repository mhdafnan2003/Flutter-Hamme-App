const test = require('node:test');
const assert = require('node:assert/strict');
const { hasProAccess, comparePriorityVotes } = require('../src/utils/proEntitlement');

test('active paid and complimentary Pro get priority; expired plans do not', () => {
  const now = Date.now();
  assert.equal(hasProAccess({ storeProActive: true, proExpiryAt: new Date(now + 1000) }, now), true);
  assert.equal(hasProAccess({ isPro: true, storeProActive: true, proExpiryAt: new Date(now - 1000) }, now), false);
  assert.equal(hasProAccess({ adminPro: true }, now), true);
  assert.equal(hasProAccess({ isPro: true, proPlatform: 'admin' }, now), true);
  assert.equal(hasProAccess({ isPro: true, storeProActive: false, proExpiryAt: new Date(now + 1000) }, now), false);
});
test('older Pro votes appear before newer free votes and keep date order within each group', () => {
  const votes = [
    { fromUser: 'free', createdAt: new Date(4000) },
    { fromUser: 'pro', createdAt: new Date(1000) },
    { fromUser: 'pro', createdAt: new Date(3000) },
    { fromUser: '', createdAt: new Date(2000) },
  ];
  votes.sort((a, b) => comparePriorityVotes(a, b, new Set(['pro'])));
  assert.deepEqual(votes.map(v => v.createdAt.getTime()), [3000, 1000, 4000, 2000]);
});

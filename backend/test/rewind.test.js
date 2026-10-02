const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const ApiError = require('../src/utils/ApiError');

function fixture({ pro = true, anonymous = false, matched = false, hidden = false, blocked = false } = {}) {
  const inbound = { id: 'poll', _id: 'poll', toUser: 'me', fromUser: anonymous ? null : 'voter', type: 'crush', createdAt: new Date(Date.now() - 10000), hiddenByRecipientAt: hidden ? new Date() : null,
    metadata: anonymous ? { anonymous: true, creatorResponseType: matched ? 'crush' : 'friend', anonymousMatched: matched } : null };
  const outgoing = { id: 'answer', _id: 'answer', toUser: 'voter', fromUser: 'me', type: matched ? 'crush' : 'friend', createdAt: new Date() };
  const docs = [inbound, outgoing];
  let creations = 0;
  const value = (doc, key) => key.split('.').reduce((item, part) => item?.[part], doc);
  const fits = (doc, filter) => Object.entries(filter).every(([key, expected]) => {
    const actual = value(doc, key);
    if (expected === null) return actual == null;
    if (expected && typeof expected === 'object' && !(expected instanceof Date)) {
      if ('$gte' in expected) return actual >= expected.$gte;
      if ('$exists' in expected) return (actual !== undefined) === expected.$exists;
    }
    return actual === expected;
  });
  const query = (fn) => { const q = { sort: () => q, select: () => q, populate: () => q, then: (resolve, reject) => Promise.resolve().then(fn).then(resolve, reject) }; return q; };
  const hydrate = (doc) => doc && Object.assign(doc, { toJSON: () => ({ ...doc }) });
  const Interaction = {
    findOne: filter => query(() => hydrate(docs.find(doc => fits(doc, filter)))),
    findOneAndUpdate: (filter, update) => query(() => {
      const doc = docs.find(item => fits(item, filter));
      if (!doc) return null;
      for (const [key, v] of Object.entries(update.$set)) {
        const parts = key.split('.'); if (parts.length === 1) doc[key] = v; else doc[parts[0]][parts[1]] = v;
      }
      return hydrate(doc);
    }),
    create: async () => { creations++; throw new Error('Rewind must update the existing answer'); },
  };
  const status = { isPro: pro, limited: false };
  const Match = { exists: async () => matched, findOneAndUpdate: () => query(() => ({
    id: 'match', _id: 'match', userA: { id: 'me', _id: 'me', name: 'Me' }, userB: { id: 'voter', _id: 'voter', name: 'Voter' }, type: 'crush', createdAt: new Date(), lastMatchedAt: new Date(), triggeredBy: 'me',
  })) };
  const sandbox = { module: { exports: {} }, process: { env: {} }, Date, Set, Map, console,
    require: name => {
      if (name === '../models/Interaction') return Interaction;
      if (name === '../models/Match') return Match;
      if (name === '../models/User') return { findById: () => query(() => ({ id: 'voter', _id: 'voter', blockedUsers: [] })), exists: async () => blocked };
      if (name === '../models/PendingInteraction') return {};
      if (name === '../utils/ApiError') return ApiError;
      if (name === '../utils/safety') return { voteBlockedError: () => new ApiError(403, 'Vote blocked') };
      if (name === './appConfigService') return { getCardLimitStatus: async () => status, recordCardView: async () => status };
      if (name === './blockService') return {};
      if (name === './pushService') return { sendToUser: async () => {} };
      if (name === '../config/env') return { anonymousVoteBackEnabled: true };
      if (name === '../utils/proEntitlement') return require('../src/utils/proEntitlement');
      return require(name);
    },
  };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../src/services/interactionService.js'), 'utf8'), sandbox);
  return { service: sandbox.module.exports, inbound, outgoing, creations: () => creations };
}

for (const anonymous of [false, true]) {
  test(`${anonymous ? 'anonymous' : 'registered'}: Pro can change an answer and make a match`, async () => {
    const f = fixture({ anonymous });
    const result = await f.service.rewindInteraction({ currentUserId: 'me', interactionId: 'poll', type: 'crush' });
    assert.equal(result.matched, true);
    assert.equal(anonymous ? f.inbound.metadata.creatorResponseType : f.outgoing.type, 'crush');
    assert.equal(f.creations(), 0);
  });
  for (const options of [{ pro: false }, { matched: true }, { hidden: true }]) {
    test(`${anonymous ? 'anonymous' : 'registered'}: refuses rewind ${JSON.stringify(options)}`, async () => {
      const f = fixture({ anonymous, ...options });
      await assert.rejects(f.service.rewindInteraction({ currentUserId: 'me', interactionId: 'poll', type: 'frenemy' }), e => [403, 404, 409].includes(e.statusCode));
      assert.equal(f.creations(), 0);
    });
  }
}
test('registered: blocked profiles cannot be rewound', async () => {
  const f = fixture({ blocked: true });
  await assert.rejects(f.service.rewindInteraction({ currentUserId: 'me', interactionId: 'poll', type: 'frenemy' }), e => e.statusCode === 403);
  assert.equal(f.outgoing.type, 'friend');
});
test('another recipient cannot rewind the poll', async () => {
  const f = fixture();
  await assert.rejects(f.service.rewindInteraction({ currentUserId: 'other', interactionId: 'poll', type: 'frenemy' }), e => e.statusCode === 404);
});

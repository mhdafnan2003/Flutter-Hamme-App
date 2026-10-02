// Run from backend: node seed_ui_votes.js [shareCode] [--cleanup]
require('dotenv').config({ quiet: true });
const crypto = require('node:crypto');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('./src/models/User');
const Interaction = require('./src/models/Interaction');

const shareCode = process.argv.slice(2).find(arg => !arg.startsWith('--')) || 'jiiiii-a4ec73';
if (!/^[a-z0-9._-]+$/.test(shareCode)) throw new Error('Invalid share code');
const seedBatch = `ui-votes-${shareCode}-20261001`;
const types = ['crush', 'friend', 'frenemy'];
const accounts = Array.from({ length: 9 }, (_, i) => ({
  name: `UI Test Voter ${i + 1}`,
  username: `ui_test_a4ec73_${i + 1}`,
  email: `ui-test-a4ec73-${i + 1}@example.invalid`,
  shareCode: `ui-test-a4ec73-${i + 1}`,
}));

async function main() {
  if (!process.env.MONGODB_URI) throw new Error('MONGODB_URI missing');
  await mongoose.connect(process.env.MONGODB_URI, { autoIndex: false, serverSelectionTimeoutMS: 10000 });
  const target = await User.findOne({ shareCode }).lean();
  if (!target || target.isBanned) throw new Error('Target profile missing or banned');
  const filter = { toUser: target._id, 'metadata.seedBatch': seedBatch };
  if (process.argv.includes('--cleanup')) {
    const removed = await Interaction.deleteMany(filter);
    // Keep test accounts: UI testing may have created responses/matches referencing them.
    console.log(JSON.stringify({ removedVotes: removed.deletedCount, testAccountsRetained: true }));
    return;
  }
  const passwordHash = await bcrypt.hash(crypto.randomBytes(32).toString('hex'), 10);
  const voters = [];
  for (const account of accounts) {
    let voter = await User.findOne({ email: account.email });
    if (voter && (voter.username !== account.username || voter.shareCode !== account.shareCode)) {
      throw new Error('Test account identity conflict');
    }
    if (!voter) voter = await User.create({ ...account, passwordHash });
    voters.push(voter);
  }
  const now = Date.now();
  for (let i = 0; i < 18; i++) {
    const anonymous = i % 2 === 0;
    const slot = `${anonymous ? 'anonymous' : 'registered'}-${Math.floor(i / 2) + 1}`;
    const data = {
      toUser: target._id,
      fromUser: anonymous ? null : voters[Math.floor(i / 2)]._id,
      type: types[Math.floor(i / 2) % types.length],
      createdAt: new Date(now - i * 37 * 60 * 1000),
      metadata: {
        seedBatch, seedSlot: slot, isTestData: true, source: 'ui-test-seed',
        ...(anonymous ? { anonymous: true, sessionId: `${seedBatch}-${slot}` } : {}),
      },
    };
    const existing = await Interaction.exists({ ...filter, 'metadata.seedSlot': slot });
    if (!existing) await Interaction.create(data);
  }
  // Repair the first seed batch as well as any existing votes in this batch.
  await Interaction.updateMany({
    fromUser: null,
    'metadata.isTestData': true,
    'metadata.seedBatch': { $in: [seedBatch, 'ui-votes-jiiiii-a4ec73-20261001'] },
  }, { $set: { 'metadata.anonymous': true } });
  const votes = await Interaction.find(filter).lean();
  if (votes.length !== 18) throw new Error(`Expected 18 seeded votes; found ${votes.length}`);
  console.log(JSON.stringify({ profile: shareCode, seedBatch, total: votes.length,
    anonymous: votes.filter(v => !v.fromUser).length,
    registered: votes.filter(v => v.fromUser).length,
    byType: Object.fromEntries(types.map(type => [type, votes.filter(v => v.type === type).length])),
  }, null, 2));
}

main().catch(error => {
  console.error(`${error.name}: seed failed; inspect database and rerun to resume safely`);
  process.exitCode = 1;
}).finally(() => mongoose.disconnect());

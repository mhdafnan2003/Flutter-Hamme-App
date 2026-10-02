// Run from backend: node seed_ui_matches.js <shareCode>
require('dotenv').config({ quiet: true });
const crypto = require('node:crypto');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('./src/models/User');
const Interaction = require('./src/models/Interaction');
const Match = require('./src/models/Match');
const { getMatchesForUser } = require('./src/services/interactionService');

async function main() {
  const shareCode = process.argv[2];
  if (!shareCode || !/^[a-z0-9._-]+$/.test(shareCode)) throw new Error('Valid shareCode required');
  if (!process.env.MONGODB_URI) throw new Error('MONGODB_URI missing');
  await mongoose.connect(process.env.MONGODB_URI, { autoIndex: false, serverSelectionTimeoutMS: 10000 });
  const target = await User.findOne({ shareCode }).select('+blockedUsers');
  if (!target || target.isBanned) throw new Error('Target profile missing or banned');
  const seedBatch = `ui-matches-${shareCode}`;
  const suffix = crypto.createHash('sha256').update(shareCode).digest('hex').slice(0, 8);
  const passwordHash = await bcrypt.hash(crypto.randomBytes(32).toString('hex'), 10);
  const matchIds = [];
  const now = Date.now();
  for (let i = 0; i < 15; i++) {
    const email = `ui-match-${suffix}-${i + 1}@example.invalid`;
    const username = `ui_match_${suffix}_${i + 1}`;
    const voterShareCode = `ui-match-${suffix}-${i + 1}`;
    let voter = await User.findOne({ email }).select('+blockedUsers');
    if (!voter) voter = await User.create({
      name: `UI Test Match ${i + 1}`, email, username,
      shareCode: voterShareCode, passwordHash,
    });
    if (voter.username !== username || voter.shareCode !== voterShareCode || voter.isBanned ||
        target.blockedUsers.some(id => id.equals(voter._id)) ||
        voter.blockedUsers.some(id => id.equals(target._id))) throw new Error('Test voter conflict');
    const type = ['crush', 'friend', 'frenemy'][i % 3];
    const matchedAt = new Date(now - i * 5 * 60 * 1000);
    for (const [direction, fromUser, toUser] of [
      ['incoming', voter._id, target._id], ['response', target._id, voter._id],
    ]) {
      await Interaction.updateOne({ fromUser, toUser, 'metadata.seedBatch': seedBatch }, {
        $setOnInsert: { fromUser, toUser, type,
          createdAt: new Date(matchedAt.getTime() - (direction === 'incoming' ? 1000 : 0)),
          metadata: { seedBatch, isTestData: true, source: 'ui-test-match-seed' },
        },
      }, { upsert: true, runValidators: true });
    }
    const [userA, userB] = [target._id, voter._id].sort((a, b) => a.toString().localeCompare(b.toString()));
    const match = await Match.findOneAndUpdate({ userA, userB, type }, {
      $set: { lastMatchedAt: matchedAt },
      $setOnInsert: { userA, userB, type, triggeredBy: target._id, createdAt: matchedAt },
    }, { upsert: true, new: true, runValidators: true });
    matchIds.push(match._id.toString());
  }
  const visible = await getMatchesForUser(target._id);
  const seeded = visible.filter(match => matchIds.includes(match.id));
  if (seeded.length !== 15) throw new Error(`Expected 15 visible seeded matches; found ${seeded.length}`);
  console.log(JSON.stringify({ profile: shareCode, verifiedVisibleMatches: seeded.length,
    byType: Object.fromEntries(['crush', 'friend', 'frenemy'].map(type => [type, seeded.filter(match => match.type === type).length])),
  }, null, 2));
}
main().catch(error => {
  console.error(`${error.name}: match seeding or verification failed`);
  process.exitCode = 1;
}).finally(() => mongoose.disconnect());

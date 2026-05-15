require('dotenv').config();
const mongoose = require('mongoose');
const crypto = require('crypto');

const User = require('./src/models/User');
const Interaction = require('./src/models/Interaction');
const PendingInteraction = require('./src/models/PendingInteraction');

const TARGET_ID = new mongoose.Types.ObjectId('6a076b993c8fde90f997b9b4');
const TARGET_SHARE_CODE = 'shamilshan-503c49';

function uid() {
  return crypto.randomBytes(6).toString('hex');
}

async function main() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/hamme');
  console.log('✅ Connected to MongoDB');

  // 1. Seed 10 PendingInteractions (Anonymous Web Taps)
  console.log('⏳ Seeding 10 PendingInteractions…');
  const types = ['crush', 'friend', 'frenemy'];
  for (let i = 0; i < 10; i++) {
    const type = types[i % types.length];
    const token = `seed-token-${uid()}`;
    await PendingInteraction.create({
      targetUserId: TARGET_ID,
      type: type,
      source: 'web_mobile',
      sessionId: `session-${uid()}`,
      shareCode: TARGET_SHARE_CODE,
      status: 'pending',
      deepLinkToken: token,
      expiresAt: new Date(Date.now() + 48 * 60 * 60 * 1000), // 48h
    });
    console.log(`  ✅ Added Pending [${type}] - Token: ${token}`);
  }

  // 2. Seed 10 Interactions (Real Users who reacted but aren't matched)
  console.log('\n📨 Seeding 10 Real Interactions (Play Queue)…');
  const names = ['Aman', 'Sanya', 'Vikram', 'Neha', 'Rohan', 'Kiara', 'Siddharth', 'Anjali', 'Sameer', 'Pooja'];
  for (let i = 0; i < 10; i++) {
    const name = names[i];
    const email = `${name.toLowerCase()}.${uid()}@test.com`;
    const username = `${name.toLowerCase()}_${uid()}`;
    
    // Create the fake user first
    const user = await User.create({
      name: name,
      email: email,
      username: username,
      instagramId: `@${username}_ig`,
      profileImageUrl: `https://i.pravatar.cc/150?u=${uid()}`,
      shareCode: `${username}-${uid().substring(0, 4)}`,
      passwordHash: 'dummy-hash'
    });

    // Create the interaction (Fake User -> Shamil)
    const type = types[i % types.length];
    await Interaction.create({
      fromUser: user._id,
      toUser: TARGET_ID,
      type: type
    });
    console.log(`  ✅ ${name} sent [${type}] to Shamil`);
  }

  console.log('\n🎉 Massive seed complete!');
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ Massive seed failed:', e);
  process.exit(1);
});

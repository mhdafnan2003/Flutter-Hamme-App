/**
 * seed_data.js
 * Creates fake users + interactions + pending interactions + matches
 * against the main account (Shamil — 6a0097f33f93fc4d6df3b006).
 *
 * Run once:  node seed_data.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt   = require('bcryptjs');
const crypto   = require('crypto');

const User               = require('./src/models/User');
const Interaction        = require('./src/models/Interaction');
const PendingInteraction = require('./src/models/PendingInteraction');
const Match              = require('./src/models/Match');

// ── Target user (shamilshan) ──────────────────────────────────────────────────────
const TARGET_ID = new mongoose.Types.ObjectId('6a076b993c8fde90f997b9b4');
const TARGET_SHARE_CODE = 'shamilshan-503c49';

// ── Fake seed users ───────────────────────────────────────────────────────────
const FAKE_USERS = [
  {
    name:     'Aneet Padda',
    email:    'aneet.padda@seed.dev',
    username: 'aneet_padda',
    instagramId: 'aneet.padda',
    profileImageUrl:
      'https://randomuser.me/api/portraits/women/44.jpg',
  },
  {
    name:     'Riya Sharma',
    email:    'riya.sharma@seed.dev',
    username: 'riya_sharma',
    snapchatId: 'riyasnap',
    profileImageUrl:
      'https://randomuser.me/api/portraits/women/68.jpg',
  },
  {
    name:     'Arjun Mehta',
    email:    'arjun.mehta@seed.dev',
    username: 'arjun_mehta',
    instagramId: 'arjunmehta',
    profileImageUrl:
      'https://randomuser.me/api/portraits/men/32.jpg',
  },
  {
    name:     'Priya Nair',
    email:    'priya.nair@seed.dev',
    username: 'priya_nair',
    snapchatId: 'priyasnap',
    profileImageUrl:
      'https://randomuser.me/api/portraits/women/22.jpg',
  },
  {
    name:     'Dev Kapoor',
    email:    'dev.kapoor@seed.dev',
    username: 'dev_kapoor',
    instagramId: 'devkapoor',
    profileImageUrl:
      'https://randomuser.me/api/portraits/men/85.jpg',
  },
];

// ── Interaction types ─────────────────────────────────────────────────────────
const TYPES = ['friend', 'crush', 'frenemy', 'friend', 'crush'];

function uid() {
  return crypto.randomBytes(6).toString('hex');
}

async function main() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/hamme');
  console.log('✅ Connected to MongoDB');

  const passwordHash = await bcrypt.hash('Password123!', 10);
  const createdUsers = [];

  // ── 1. Create (or reuse) fake users ─────────────────────────────────────────
  for (const fake of FAKE_USERS) {
    let user = await User.findOne({ email: fake.email });
    if (!user) {
      user = await User.create({
        name:            fake.name,
        email:           fake.email,
        username:        fake.username,
        instagramId:     fake.instagramId || '',
        snapchatId:      fake.snapchatId  || '',
        profileImageUrl: fake.profileImageUrl,
        shareCode:       `${fake.username}-${uid()}`,
        passwordHash,
      });
      console.log(`  👤 Created user: ${user.name} (${user.id})`);
    } else {
      console.log(`  ♻️  Reused user: ${user.name} (${user.id})`);
    }
    createdUsers.push(user);
  }

  // ── 2. Interactions: fake users → Shamil  (play-queue items) ─────────────────
  console.log('\n📨 Creating Interactions (fake → Shamil)…');
  for (let i = 0; i < createdUsers.length; i++) {
    const from = createdUsers[i];
    const type = TYPES[i];
    try {
      await Interaction.findOneAndUpdate(
        { fromUser: from._id, toUser: TARGET_ID },
        { fromUser: from._id, toUser: TARGET_ID, type },
        { upsert: true, new: true }
      );
      console.log(`  ✅ ${from.name} —[${type}]→ Target`);
    } catch (e) {
      console.warn(`  ⚠️  Interaction already exists or error: ${e.message}`);
    }
  }

  // ── 3. PendingInteractions: anonymous web taps → Target ──────────────────────
  console.log('\n⏳ Creating PendingInteractions…');
  const pendingTypes = ['friend', 'crush', 'frenemy'];
  for (const type of pendingTypes) {
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // +24 h
    try {
      await PendingInteraction.create({
        targetUserId: TARGET_ID,
        type,
        source:       'web_local',
        sessionId:    `seed-session-${uid()}`,
        shareCode:    TARGET_SHARE_CODE,
        status:       'pending',
        deepLinkToken:`seed-token-${uid()}`,
        expiresAt,
      });
      console.log(`  ✅ Pending [${type}] for Target`);
    } catch (e) {
      console.warn(`  ⚠️  PendingInteraction error: ${e.message}`);
    }
  }

  // ── 4. Matches: Target ↔ fake users ──────────────────────────────────────────
  console.log('\n💞 Creating Matches…');
  const matchPairs = [
    { userB: createdUsers[0], type: 'crush'   },
    { userB: createdUsers[1], type: 'friend'  },
    { userB: createdUsers[2], type: 'frenemy' },
  ];
  for (const { userB, type } of matchPairs) {
    try {
      await Match.findOneAndUpdate(
        { userA: TARGET_ID, userB: userB._id, type },
        { userA: TARGET_ID, userB: userB._id, type, triggeredBy: userB._id },
        { upsert: true, new: true }
      );
      console.log(`  ✅ Match [${type}]: Target ↔ ${userB.name}`);
    } catch (e) {
      console.warn(`  ⚠️  Match error: ${e.message}`);
    }
  }

  console.log('\n🎉 Seed complete!');
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ Seed failed:', e);
  process.exit(1);
});

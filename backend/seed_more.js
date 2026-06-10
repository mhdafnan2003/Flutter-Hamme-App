require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt   = require('bcryptjs');
const crypto   = require('crypto');

const User               = require('./src/models/User');
const Interaction        = require('./src/models/Interaction');
const Match              = require('./src/models/Match');

// Target user (shamilshan)
const TARGET_ID = new mongoose.Types.ObjectId('6a076b993c8fde90f997b9b4');

const EXTRA_USERS = [
  {
    name:     'Christina',
    email:    'christina@seed.dev',
    username: 'aeerriya_ig',
    instagramId: '@aeerriya',
    profileImageUrl: 'https://randomuser.me/api/portraits/women/10.jpg',
  },
  {
    name:     'Swathiii',
    email:    'swathiii@seed.dev',
    username: 'swathiii_ig',
    instagramId: '@aeerriya',
    profileImageUrl: 'https://randomuser.me/api/portraits/women/20.jpg',
  },
  {
    name:     'Lisa',
    email:    'lisa@seed.dev',
    username: 'lisa_snap',
    snapchatId: '@aeerriya',
    profileImageUrl: 'https://randomuser.me/api/portraits/women/30.jpg',
  },
  {
    name:     'Joan',
    email:    'joan@seed.dev',
    username: 'joan_ig',
    instagramId: '@aeerriya',
    profileImageUrl: 'https://randomuser.me/api/portraits/women/40.jpg',
  },
  {
    name:     'Marcus',
    email:    'marcus@seed.dev',
    username: 'marcus_ig',
    instagramId: '@marcus_vibe',
    profileImageUrl: 'https://randomuser.me/api/portraits/men/15.jpg',
  },
];

function uid() {
  return crypto.randomBytes(4).toString('hex');
}

async function main() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/hamme');
  console.log('✅ Connected to MongoDB');

  const passwordHash = await bcrypt.hash('Password123!', 10);

  for (const fake of EXTRA_USERS) {
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
      console.log(`  👤 Created user: ${user.name}`);
    }

    // Create Match
    const type = ['friend', 'crush', 'frenemy'][Math.floor(Math.random() * 3)];
    await Match.findOneAndUpdate(
      { userA: TARGET_ID, userB: user._id },
      { userA: TARGET_ID, userB: user._id, type, triggeredBy: user._id },
      { upsert: true, new: true }
    );
    console.log(`  💞 Matched with ${user.name} as ${type}`);
  }

  console.log('\n🎉 Extra seed complete!');
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ Seed failed:', e);
  process.exit(1);
});

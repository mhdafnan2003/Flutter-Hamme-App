require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt   = require('bcryptjs');
const crypto   = require('crypto');

const User               = require('./src/models/User');
const Interaction        = require('./src/models/Interaction');

// Target user (shamilshan)
const TARGET_ID = new mongoose.Types.ObjectId('6a076b993c8fde90f997b9b4');

const PLAY_USERS = [
  {
    name:     'Zara Khan',
    email:    'zara.khan@seed.dev',
    username: 'zara_k',
    instagramId: '@zara_vibe',
    profileImageUrl: 'https://randomuser.me/api/portraits/women/50.jpg',
  },
  {
    name:     'Ishaan Gupta',
    email:    'ishaan.gupta@seed.dev',
    username: 'ishaan_g',
    snapchatId: '@ishaan_snap',
    profileImageUrl: 'https://randomuser.me/api/portraits/men/50.jpg',
  },
  {
    name:     'Maya Roy',
    email:    'maya.roy@seed.dev',
    username: 'maya_r',
    instagramId: '@maya_insta',
    profileImageUrl: 'https://randomuser.me/api/portraits/women/60.jpg',
  },
  {
    name:     'Kabir Singh',
    email:    'kabir.singh@seed.dev',
    username: 'kabir_s',
    instagramId: '@kabir_vibe',
    profileImageUrl: 'https://randomuser.me/api/portraits/men/60.jpg',
  },
];

function uid() {
  return crypto.randomBytes(4).toString('hex');
}

async function main() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/hamme');
  console.log('✅ Connected to MongoDB');

  const passwordHash = await bcrypt.hash('Password123!', 10);

  for (const fake of PLAY_USERS) {
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

    // Create Interaction (fake -> Shamil)
    // IMPORTANT: No reciprocal match is created, so it appears in Shamil's play queue.
    const type = ['friend', 'crush', 'frenemy'][Math.floor(Math.random() * 3)];
    await Interaction.findOneAndUpdate(
      { fromUser: user._id, toUser: TARGET_ID },
      { fromUser: user._id, toUser: TARGET_ID, type },
      { upsert: true, new: true }
    );
    console.log(`  📨 ${user.name} sent [${type}] interaction to Shamil`);
  }

  console.log('\n🎉 Play queue seed complete!');
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ Seed failed:', e);
  process.exit(1);
});

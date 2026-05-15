require('dotenv').config();
const mongoose = require('mongoose');
const PendingInteraction = require('./src/models/PendingInteraction');

function uid() {
  const crypto = require('crypto');
  return crypto.randomBytes(6).toString('hex');
}

async function main() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/hamme');
  console.log('✅ Connected to MongoDB');

  const token = `seed-token-${uid()}`;
  const data = {
    targetUserId: new mongoose.Types.ObjectId("6a076b993c8fde90f997b9b4"),
    type: "friend",
    source: "web_local",
    sessionId: `seed-session-${uid()}`,
    shareCode: "shamilshan-503c49",
    status: "pending",
    deepLinkToken: token,
    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
    createdAt: new Date(),
    updatedAt: new Date()
  };

  try {
    await PendingInteraction.create(data);
    console.log(`✅ Another PendingInteraction seeded! Token: ${token}`);
  } catch (e) {
    console.error('❌ Failed to seed:', e);
  }

  process.exit(0);
}

main().catch((e) => {
  console.error('❌ Seed failed:', e);
  process.exit(1);
});

require('dotenv').config();
const mongoose = require('mongoose');
const PendingInteraction = require('./src/models/PendingInteraction');

async function main() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/hamme');
  console.log('✅ Connected to MongoDB');

  const data = {
    _id: new mongoose.Types.ObjectId("6a077e7814a344f9e647f435"),
    targetUserId: new mongoose.Types.ObjectId("6a076b993c8fde90f997b9b4"),
    type: "crush",
    source: "web_local",
    sessionId: "seed-session-9540534f4262",
    shareCode: "shamilshan-503c49",
    status: "pending",
    deepLinkToken: "seed-token-d905b1373f0a",
    expiresAt: new Date("2026-05-16T20:13:44.768Z"),
    createdAt: new Date("2026-05-15T20:13:44.769Z"),
    updatedAt: new Date("2026-05-15T20:13:44.769Z")
  };

  try {
    await PendingInteraction.deleteOne({ _id: data._id });
    await PendingInteraction.create(data);
    console.log('✅ Specific PendingInteraction seeded successfully!');
  } catch (e) {
    console.error('❌ Failed to seed:', e);
  }

  process.exit(0);
}

main().catch((e) => {
  console.error('❌ Seed failed:', e);
  process.exit(1);
});

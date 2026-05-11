const mongoose = require('mongoose');
const Interaction = require('./src/models/Interaction');
const PendingInteraction = require('./src/models/PendingInteraction');
require('dotenv').config();

async function check() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/hamme');
  const interactions = await Interaction.find().sort({ createdAt: -1 }).limit(5);
  const pending = await PendingInteraction.find().sort({ createdAt: -1 }).limit(5);
  
  console.log('--- LATEST INTERACTIONS ---');
  console.log(JSON.stringify(interactions, null, 2));
  
  console.log('--- LATEST PENDING ---');
  console.log(JSON.stringify(pending, null, 2));
  
  process.exit(0);
}

check();

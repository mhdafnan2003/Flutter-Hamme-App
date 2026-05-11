const mongoose = require('mongoose');
const Interaction = require('./src/models/Interaction');
require('dotenv').config();

async function check() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/hamme');
  const interactions = await Interaction.find().lean();
  console.log('--- ALL INTERACTIONS ---');
  console.log(JSON.stringify(interactions, null, 2));
  process.exit(0);
}

check();

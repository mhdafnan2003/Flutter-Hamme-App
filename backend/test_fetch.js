require('dotenv').config();
const mongoose = require('mongoose');
const interactionService = require('./src/services/interactionService');

async function run() {
  await mongoose.connect('mongodb://127.0.0.1:27017/hamme');
  const items = await interactionService.getReceivedInteractions('6a007cfaca7843a519d9189a');
  console.log(JSON.stringify(items, null, 2));
  process.exit(0);
}
run();

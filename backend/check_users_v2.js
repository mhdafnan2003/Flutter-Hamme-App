const mongoose = require('mongoose');
const User = require('./src/models/User');
require('dotenv').config();

async function check() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/hamme');
  const users = await User.find({}, 'name username shareCode deviceId');
  console.log(JSON.stringify(users, null, 2));
  process.exit(0);
}

check();

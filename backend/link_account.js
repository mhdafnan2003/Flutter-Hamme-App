const mongoose = require('mongoose');
const User = require('./src/models/User');
require('dotenv').config();

async function check() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/hamme');
  const res = await User.updateOne(
    { username: 'shaamilshan' },
    { deviceId: 'hamme-dev-device-stable' }
  );
  console.log('Update result:', res);
  process.exit(0);
}

check();

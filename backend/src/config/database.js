const mongoose = require('mongoose');

const env = require('./env');
const logger = require('../utils/logger');

let connectionPromise = null;

async function connectDatabase() {
  if (mongoose.connection.readyState === 1) {
    return mongoose.connection;
  }

  if (connectionPromise) {
    await connectionPromise;
    return mongoose.connection;
  }

  connectionPromise = mongoose
    .connect(env.mongoUri)
    .then(() => {
      logger.info(`MongoDB connected to ${mongoose.connection.name}`);
      return mongoose.connection;
    })
    .catch((error) => {
      connectionPromise = null;
      throw error;
    });

  await connectionPromise;
  return mongoose.connection;
}

module.exports = connectDatabase;

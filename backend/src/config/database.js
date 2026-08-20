const mongoose = require('mongoose');

const env = require('./env');
const logger = require('../utils/logger');
const Interaction = require('../models/Interaction');

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
    .then(async () => {
      // Remove only the former permanent uniqueness lock. Avoid syncIndexes()
      // here because it can also remove operational indexes created outside
      // Mongoose. The replacement query index is declared on the model.
      try {
        await Interaction.collection.dropIndex('fromUser_1_toUser_1_type_1');
      } catch (error) {
        if (error?.codeName !== 'IndexNotFound' && error?.code !== 27) {
          throw error;
        }
      }
      await Interaction.createIndexes();
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

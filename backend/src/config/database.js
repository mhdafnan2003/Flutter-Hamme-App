const mongoose = require('mongoose');

const env = require('./env');
const logger = require('../utils/logger');
const Interaction = require('../models/Interaction');
const UserReport = require('../models/UserReport');

let connectionPromise = null;

// The driver reconnects on its own; log transitions so outages are visible.
mongoose.connection.on('disconnected', () => logger.warn('MongoDB disconnected.'));
mongoose.connection.on('reconnected', () => logger.info('MongoDB reconnected.'));
mongoose.connection.on('error', (error) => {
  logger.error(`MongoDB connection error: ${error.message}`);
});

async function migrateInteractionIndexes() {
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
}

async function connectDatabase() {
  if (mongoose.connection.readyState === 1) {
    return mongoose.connection;
  }

  if (connectionPromise) {
    await connectionPromise;
    return mongoose.connection;
  }

  connectionPromise = mongoose
    .connect(env.mongoUri, {
      // Fail a query after 10s instead of the 30s default when no server is
      // reachable: the app gives up at 15s, so longer waits only pile up
      // abandoned requests in memory.
      serverSelectionTimeoutMS: 10000,
      // One small process; the default pool of 100 is never needed.
      maxPoolSize: 10,
    })
    .then(() => {
      logger.info(`MongoDB connected to ${mongoose.connection.name}`);
      // Index maintenance runs in the background so it doesn't add extra
      // round trips to the first request on every serverless cold start.
      migrateInteractionIndexes().catch((error) => {
        logger.error(`Interaction index migration failed: ${error.message}`);
      });
      // Anonymous reports need the old one-report-per-user unique index gone.
      // reportService retries the drop if an insert still collides with it.
      UserReport.dropLegacyIndexes()
        .then((dropped) => dropped && logger.info('Dropped legacy UserReport unique index.'))
        .catch((error) => {
          logger.error(`UserReport index migration failed: ${error.message}`);
        });
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

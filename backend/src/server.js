const http = require('http');

const app = require('./app');
const connectDatabase = require('./config/database');
const env = require('./config/env');
const logger = require('./utils/logger');
const { initializeSocket } = require('./socket');

async function startServer() {
  await connectDatabase();

  const server = http.createServer(app);

  if (env.enableSockets) {
    initializeSocket(server);
  }

  server.listen(env.port, '0.0.0.0', () => {
    logger.info(`API listening on 0.0.0.0:${env.port}`);
  });
}

startServer().catch((error) => {
  logger.error('Failed to start server.', error);
  process.exit(1);
});

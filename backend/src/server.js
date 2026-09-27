const http = require('http');
const mongoose = require('mongoose');

const app = require('./app');
const connectDatabase = require('./config/database');
const env = require('./config/env');
const logger = require('./utils/logger');

const DB_RETRY_DELAY_MS = 5000;
const SHUTDOWN_TIMEOUT_MS = 10 * 1000;

// A stray rejected promise (e.g. a push that failed after the response was
// sent) must be visible in the logs but must not take every request down.
process.on('unhandledRejection', (reason) => {
  logger.error('Unhandled promise rejection', reason);
});

async function connectWithRetry() {
  for (;;) {
    try {
      await connectDatabase();
      return;
    } catch (error) {
      logger.error(
        `MongoDB connection failed; retrying in ${DB_RETRY_DELAY_MS / 1000}s: ${error.message}`
      );
      await new Promise((resolve) => setTimeout(resolve, DB_RETRY_DELAY_MS));
    }
  }
}

function startServer() {
  if (!env.jwtAccessSecret || !env.jwtRefreshSecret) {
    logger.error(
      'JWT_ACCESS_SECRET and JWT_REFRESH_SECRET must be configured before starting the API.'
    );
    process.exit(1);
  }

  const server = http.createServer(app);
  // Keep idle keep-alive sockets open longer than the proxy in front of us
  // (commonly 60s). If Node closes first (default 5s), the proxy can reuse a
  // socket that is just being closed and answers the client with a 502.
  server.keepAliveTimeout = 65 * 1000;
  server.headersTimeout = 66 * 1000;

  // Listen right away: /health reports 503 until MongoDB is connected, and
  // requests that arrive meanwhile wait for the connection instead of
  // failing at the proxy.
  server.listen(env.port, '0.0.0.0', () => {
    logger.info(`API listening on 0.0.0.0:${env.port}`);
  });
  connectWithRetry();

  let shuttingDown = false;
  const shutdown = (signal) => {
    if (shuttingDown) return;
    shuttingDown = true;
    logger.info(`${signal} received; draining connections.`);
    // Let in-flight requests finish (redeploys and sleep send SIGTERM).
    server.close(() => {
      mongoose.connection.close().finally(() => process.exit(0));
    });
    setTimeout(() => process.exit(0), SHUTDOWN_TIMEOUT_MS).unref();
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

startServer();

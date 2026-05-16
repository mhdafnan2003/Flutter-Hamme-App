const { Server } = require('socket.io');

const env = require('./config/env');

let ioInstance = null;
const normalizeOrigin = (origin) =>
  origin?.trim().replace(/\/+$/, '').toLowerCase();
const isPrivateNetworkDevOrigin = (origin) =>
  /^http:\/\/(192\.168\.\d{1,3}\.\d{1,3}|10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3})(:\d+)?$/.test(
    normalizeOrigin(origin) || ''
  );

function initializeSocket(server) {
  ioInstance = new Server(server, {
    cors: {
      origin: (origin, callback) => {
        if (!origin) return callback(null, true);
        if (env.clientOrigin === '*') return callback(null, true);
        const normalizedOrigin = normalizeOrigin(origin);

        const isExplicitlyAllowed =
          Array.isArray(env.clientOrigin) &&
          env.clientOrigin.some(
            (allowedOrigin) =>
              normalizeOrigin(allowedOrigin) === normalizedOrigin
          );
        const isLocalhostDevOrigin =
          env.nodeEnv !== 'production' &&
          /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(
            normalizedOrigin || ''
          );
        const isLanDevOrigin =
          env.nodeEnv !== 'production' &&
          isPrivateNetworkDevOrigin(normalizedOrigin);

        if (isExplicitlyAllowed || isLocalhostDevOrigin || isLanDevOrigin) {
          return callback(null, true);
        }

        return callback(new Error(`CORS blocked origin: ${origin}`));
      },
      credentials: true,
    },
  });

  ioInstance.on('connection', (socket) => {
    socket.on('join:user', (userId) => {
      if (userId) {
        socket.join(`user:${userId}`);
      }
    });
  });

  return ioInstance;
}

function emitMatchFound(userIds, payload) {
  if (!ioInstance) {
    return;
  }

  userIds.forEach((userId) => {
    ioInstance.to(`user:${userId}`).emit('match:found', payload);
  });
}

module.exports = {
  initializeSocket,
  emitMatchFound,
};

const cors = require('cors');
const express = require('express');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const morgan = require('morgan');

const env = require('./config/env');
const apiRoutes = require('./routes');
const errorHandler = require('./middleware/errorHandler');
const notFound = require('./middleware/notFound');

const app = express();
const isVercel = Boolean(process.env.VERCEL);
const trustProxyEnv = process.env.TRUST_PROXY;
const isPrivateNetworkDevOrigin = (origin) =>
  /^http:\/\/(192\.168\.\d{1,3}\.\d{1,3}|10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3})(:\d+)?$/.test(
    origin
  );

if (trustProxyEnv === 'true') {
  app.set('trust proxy', 1);
} else if (trustProxyEnv === 'false') {
  app.set('trust proxy', false);
} else if (isVercel || env.nodeEnv !== 'production') {
  app.set('trust proxy', 1);
}

app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  })
);
app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin) return callback(null, true);
      if (env.clientOrigin === '*') return callback(null, true);

      const isExplicitlyAllowed =
        Array.isArray(env.clientOrigin) && env.clientOrigin.includes(origin);

      const isLocalhostDevOrigin =
        env.nodeEnv !== 'production' &&
        /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
      const isLanDevOrigin =
        env.nodeEnv !== 'production' && isPrivateNetworkDevOrigin(origin);

      if (isExplicitlyAllowed || isLocalhostDevOrigin || isLanDevOrigin) {
        return callback(null, true);
      }

      return callback(new Error(`CORS blocked origin: ${origin}`));
    },
    credentials: true,
  })
);
app.use(morgan(env.nodeEnv === 'production' ? 'combined' : 'dev'));
app.use(
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 200,
    standardHeaders: true,
    legacyHeaders: false,
    validate: {
      xForwardedForHeader: false,
      forwardedHeader: false,
    },
  })
);
app.use(express.json({ limit: '1mb' }));

app.get('/', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.use('/api/v1', apiRoutes);
app.use(notFound);
app.use(errorHandler);

module.exports = app;

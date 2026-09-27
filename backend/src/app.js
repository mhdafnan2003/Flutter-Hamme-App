const cors = require('cors');
const express = require('express');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const mongoose = require('mongoose');
const morgan = require('morgan');

const env = require('./config/env');
const apiRoutes = require('./routes');
const errorHandler = require('./middleware/errorHandler');
const notFound = require('./middleware/notFound');
const ApiError = require('./utils/ApiError');

const app = express();
const normalizeOrigin = (origin) =>
  origin?.trim().replace(/\/+$/, '').toLowerCase();
const isPrivateNetworkDevOrigin = (origin) =>
  /^http:\/\/(192\.168\.\d{1,3}\.\d{1,3}|10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3})(:\d+)?$/.test(
    normalizeOrigin(origin) || ''
  );

// The API always runs behind one proxy (Railway/Vercel), which puts the real
// client IP in X-Forwarded-For. Without this every user shares the proxy's IP
// and therefore a single rate-limit bucket. Set TRUST_PROXY=false only when
// the API is exposed directly.
app.set('trust proxy', process.env.TRUST_PROXY === 'false' ? false : 1);

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
      const normalizedOrigin = normalizeOrigin(origin);

      const isExplicitlyAllowed =
        Array.isArray(env.clientOrigin) &&
        env.clientOrigin.some(
          (allowedOrigin) => normalizeOrigin(allowedOrigin) === normalizedOrigin
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

      return callback(new ApiError(403, `CORS blocked origin: ${origin}`));
    },
    credentials: true,
    // Let browsers cache the preflight instead of sending an OPTIONS request
    // before every JSON POST from the web vote page.
    maxAge: 24 * 60 * 60,
  })
);
app.use(
  morgan(env.nodeEnv === 'production' ? 'combined' : 'dev', {
    skip: (req) => req.path === '/health',
  })
);
app.use(
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: env.apiRateLimit,
    message: { message: 'Too many requests. Please try again shortly.' },
    // Pub/Sub authenticates this endpoint with a Google-signed OIDC token and
    // may legitimately deliver bursts or retries.
    skip: (req) => req.path === '/api/v1/billing/google-play/rtdn',
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

// Readiness probe (set as the Railway healthcheck path): a new deploy only
// receives traffic once it can reach MongoDB.
app.get('/health', (req, res) => {
  const ready = mongoose.connection.readyState === 1;
  res.status(ready ? 200 : 503).json({ status: ready ? 'ok' : 'starting' });
});

app.use('/api/v1', apiRoutes);
app.use(notFound);
app.use(errorHandler);

module.exports = app;

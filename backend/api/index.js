const app = require('../src/app');
const connectDatabase = require('../src/config/database');
const env = require('../src/config/env');

module.exports = async (req, res) => {
  if (!env.jwtAccessSecret || !env.jwtRefreshSecret) {
    throw new Error(
      'JWT_ACCESS_SECRET and JWT_REFRESH_SECRET must be configured before serving the API.'
    );
  }
  await connectDatabase();
  return app(req, res);
};

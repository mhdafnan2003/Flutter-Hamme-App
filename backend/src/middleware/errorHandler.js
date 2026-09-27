const ApiError = require('../utils/ApiError');
const logger = require('../utils/logger');

// Errors thrown by libraries carry no ApiError status. Map the ones caused by
// bad client input to 4xx so they aren't reported (and alerted on) as 500s.
function resolveStatus(error) {
  if (error.statusCode) return error.statusCode;
  // body-parser / http-errors (malformed JSON, payload too large).
  if (Number.isInteger(error.status)) return error.status;
  if (error.name === 'CastError') return 400;
  if (error.name === 'ValidationError') return 422;
  if (error.name === 'MulterError') return 400;
  return 500;
}

function errorHandler(error, req, res, next) {
  if (res.headersSent) {
    return next(error);
  }

  const statusCode = resolveStatus(error);
  if (statusCode >= 500) {
    logger.error(`${req.method} ${req.originalUrl} -> ${statusCode}: ${error.message}`, error.details || error.stack);
  } else {
    logger.info(`${req.method} ${req.originalUrl} -> ${statusCode}: ${error.message}`);
  }

  // Unexpected server errors must not leak internals to the client.
  const exposeMessage = error instanceof ApiError || statusCode < 500;
  return res.status(statusCode).json({
    message: exposeMessage ? error.message : 'Internal server error.',
    details: error instanceof ApiError ? error.details : undefined,
  });
}

module.exports = errorHandler;

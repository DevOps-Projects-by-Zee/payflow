const { v4: uuidv4 } = require('uuid');

// Correlation ID middleware
function correlationMiddleware(req, res, next) {
  const correlationId = req.headers['x-correlation-id'] || uuidv4();
  req.correlationId = correlationId;
  res.setHeader('X-Correlation-Id', correlationId);
  next();
}

// Add correlation ID to axios requests
function addCorrelationToAxios(axios, correlationId) {
  return {
    ...axios.defaults,
    headers: {
      ...axios.defaults.headers,
      'X-Correlation-Id': correlationId
    }
  };
}

module.exports = { correlationMiddleware, addCorrelationToAxios };

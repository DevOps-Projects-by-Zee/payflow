const CircuitBreaker = require('opossum');
const logger = require('./logger');

function createCircuitBreaker(asyncFunction, options = {}) {
  const defaultOptions = {
    timeout: 3000, // 3 seconds
    errorThresholdPercentage: 50, // Open circuit at 50% errors
    resetTimeout: 30000, // Try again after 30 seconds
    rollingCountTimeout: 10000, // 10 second window
    rollingCountBuckets: 10,
    name: options.name || 'unnamed-breaker'
  };

  const breaker = new CircuitBreaker(asyncFunction, { ...defaultOptions, ...options });

  // Event listeners for monitoring
  breaker.on('open', () => {
    logger.error(`Circuit breaker opened: ${breaker.name}`);
  });

  breaker.on('halfOpen', () => {
    logger.warn(`Circuit breaker half-open: ${breaker.name}`);
  });

  breaker.on('close', () => {
    logger.info(`Circuit breaker closed: ${breaker.name}`);
  });

  breaker.on('failure', (error) => {
    logger.error(`Circuit breaker failure: ${breaker.name}`, { error: error.message });
  });

  // Fallback
  breaker.fallback(() => {
    throw new Error(`Service temporarily unavailable: ${breaker.name}`);
  });

  return breaker;
}

module.exports = { createCircuitBreaker };

const retry = require('async-retry');
const logger = require('./logger');

async function retryWithBackoff(asyncFunction, options = {}) {
  const defaultOptions = {
    retries: 3,
    factor: 2,
    minTimeout: 1000,
    maxTimeout: 10000,
    randomize: true,
    onRetry: (error, attempt) => {
      logger.warn(`Retry attempt ${attempt}`, { error: error.message });
    }
  };

  return retry(async (bail, attempt) => {
    try {
      return await asyncFunction();
    } catch (error) {
      // Don't retry on 4xx errors (client errors)
      if (error.response && error.response.status >= 400 && error.response.status < 500) {
        bail(error);
        return;
      }
      throw error;
    }
  }, { ...defaultOptions, ...options });
}

module.exports = { retryWithBackoff };

const redis = require('redis');
const { v4: uuidv4 } = require('uuid');
const logger = require('./logger');

class IdempotencyManager {
  constructor(redisClient) {
    this.redis = redisClient;
    this.ttl = 24 * 60 * 60; // 24 hours
  }

  async check(key, handler) {
    const idempotencyKey = `idempotency:${key}`;
    
    try {
      // Check if request was already processed
      const cached = await this.redis.get(idempotencyKey);
      
      if (cached) {
        logger.info('Idempotent request detected', { key });
        return { fromCache: true, data: JSON.parse(cached) };
      }

      // Process request
      const result = await handler();

      // Store result
      await this.redis.setEx(idempotencyKey, this.ttl, JSON.stringify(result));

      return { fromCache: false, data: result };
    } catch (error) {
      logger.error('Idempotency check failed', { key, error: error.message });
      throw error;
    }
  }

  generateKey(userId, operation, params) {
    return `${userId}:${operation}:${JSON.stringify(params)}`;
  }
}

// Middleware for idempotency
function idempotencyMiddleware(redisClient) {
  const manager = new IdempotencyManager(redisClient);

  return async (req, res, next) => {
    const idempotencyKey = req.headers['idempotency-key'];

    if (!idempotencyKey) {
      return next();
    }

    const fullKey = `${req.user?.userId || 'anonymous'}:${req.path}:${idempotencyKey}`;

    try {
      const cached = await redisClient.get(`idempotency:${fullKey}`);

      if (cached) {
        logger.info('Returning cached idempotent response', { key: fullKey });
        return res.json(JSON.parse(cached));
      }

      // Store original res.json
      const originalJson = res.json.bind(res);

      // Override res.json to cache response
      res.json = function(data) {
        redisClient.setEx(`idempotency:${fullKey}`, 86400, JSON.stringify(data))
          .catch(err => logger.error('Failed to cache idempotent response', { error: err.message }));
        return originalJson(data);
      };

      next();
    } catch (error) {
      logger.error('Idempotency middleware error', { error: error.message });
      next();
    }
  };
}

module.exports = { IdempotencyManager, idempotencyMiddleware };

const express = require('express');
const { Pool } = require('pg');
const redis = require('redis');
const helmet = require('helmet');
const morgan = require('morgan');
const { body, param, validationResult } = require('express-validator');
const winston = require('winston');
const client = require('prom-client');
require('dotenv').config();

// #### Prometheus Metrics Setup ####
// #### These metrics track wallet operations and database performance ####

// Database connection metrics
const dbConnections = new client.Gauge({
  name: 'database_connections_active',
  help: 'Number of active database connections',
  labelNames: ['database']
});

// Redis operation metrics
const redisOperations = new client.Counter({
  name: 'redis_operations_total',
  help: 'Total number of Redis operations',
  labelNames: ['operation', 'status']
});

// Transaction metrics
const transactionMetrics = new client.Counter({
  name: 'transactions_total',
  help: 'Total number of transactions processed',
  labelNames: ['status', 'type', 'service']
});

// #### Business Metrics for Wallet Service ####
// #### These metrics track wallet-specific business operations ####
const transfers = new client.Counter({
  name: 'transfers_total',
  help: 'Total number of money transfers',
  labelNames: ['status', 'service', 'amount_range']
});

const failedTransfers = new client.Counter({
  name: 'failed_transfers_total',
  help: 'Total number of failed transfers',
  labelNames: ['reason', 'service']
});

// Request rate metrics
const requestRate = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code', 'service']
});

// Error rate metrics
const errorRate = new client.Counter({
  name: 'http_errors_total',
  help: 'Total number of HTTP errors',
  labelNames: ['method', 'route', 'status_code', 'service']
});

const app = express();
const PORT = process.env.PORT || 3001;

// ============================================
// LOGGING SETUP
// ============================================
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { 
    service: 'wallet-service',
    environment: process.env.NODE_ENV || 'development'
  },
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});

// ============================================
// METRICS SETUP
// ============================================
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

const cacheHitRate = new client.Counter({
  name: 'cache_hits_total',
  help: 'Total cache hits',
  labelNames: ['cache_type', 'hit']
});

const databaseQueryDuration = new client.Histogram({
  name: 'database_query_duration_seconds',
  help: 'Database query duration',
  labelNames: ['query_type'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2]
});

register.registerMetric(httpRequestDuration);
register.registerMetric(cacheHitRate);
register.registerMetric(databaseQueryDuration);
register.registerMetric(dbConnections);
register.registerMetric(redisOperations);
register.registerMetric(transactionMetrics);
register.registerMetric(transfers);
register.registerMetric(failedTransfers);
register.registerMetric(requestRate);
register.registerMetric(errorRate);

// ============================================
// MIDDLEWARE
// ============================================
// #### Metrics Collection Middleware ####
// #### This middleware collects metrics for every request ####
app.use((req, res, next) => {
  // Increment request counter
  requestRate.inc({
    method: req.method,
    route: req.route?.path || req.path,
    status_code: res.statusCode,
    service: 'wallet-service'
  });

  // Track errors
  res.on('finish', () => {
    if (res.statusCode >= 400) {
      errorRate.inc({
        method: req.method,
        route: req.route?.path || req.path,
        status_code: res.statusCode,
        service: 'wallet-service'
      });
    }
  });

  next();
});

app.use(helmet());
app.use(morgan('combined'));
app.use(express.json({ limit: '10kb' }));

// Correlation ID middleware
app.use((req, res, next) => {
  req.correlationId = req.headers['x-correlation-id'] || `wallet-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  res.setHeader('X-Correlation-Id', req.correlationId);
  next();
});

// Metrics middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route?.path || req.path;
    httpRequestDuration.labels(req.method, route, res.statusCode).observe(duration);
  });
  next();
});

// ============================================
// DATABASE CONNECTION
// ============================================
const pool = new Pool({
  host: process.env.DB_HOST || 'postgres',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'payflow',
  user: process.env.DB_USER || 'payflow',
  password: process.env.DB_PASSWORD || 'payflow123',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Wrap pool.query to measure duration
const originalQuery = pool.query.bind(pool);
pool.query = async function(...args) {
  const start = Date.now();
  try {
    const result = await originalQuery(...args);
    const duration = (Date.now() - start) / 1000;
    databaseQueryDuration.labels('select').observe(duration);
    return result;
  } catch (error) {
    const duration = (Date.now() - start) / 1000;
    databaseQueryDuration.labels('error').observe(duration);
    throw error;
  }
};

// ============================================
// REDIS CONNECTION
// ============================================
const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://redis:6379'
});

redisClient.on('error', (err) => logger.error('Redis error:', err));
redisClient.on('connect', () => logger.info('Redis connected'));

// Connect to Redis
(async () => {
  try {
    await redisClient.connect();
  } catch (error) {
    logger.error('Failed to connect to Redis:', error);
  }
})();

// ============================================
// INITIALIZE DATABASE
// ============================================
async function initDB() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS wallets (
        user_id VARCHAR(50) PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        currency VARCHAR(3) DEFAULT 'USD',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Create index
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_wallets_user ON wallets(user_id)
    `);

    logger.info('Database initialized');
  } catch (error) {
    logger.error('Database initialization error:', error);
  } finally {
    client.release();
  }
}

initDB().catch(console.error);

// ============================================
// VALIDATION MIDDLEWARE
// ============================================
const validate = (validations) => {
  return async (req, res, next) => {
    await Promise.all(validations.map(validation => validation.run(req)));
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        error: 'Validation failed',
        details: errors.array() 
      });
    }
    next();
  };
};

// ============================================
// ROUTES
// ============================================

// Health check
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    const redisPing = await redisClient.ping();
    res.json({ 
      status: 'healthy', 
      service: 'wallet-service',
      database: 'connected',
      redis: redisPing === 'PONG' ? 'connected' : 'disconnected',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Health check failed:', error);
    res.status(503).json({ 
      status: 'unhealthy', 
      error: error.message 
    });
  }
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Get all wallets
app.get('/wallets', async (req, res) => {
  const correlationId = req.correlationId;
  
  try {
    // Try cache first
    const cached = await redisClient.get('wallets:all');
    if (cached) {
      cacheHitRate.labels('wallets', 'hit').inc();
      logger.info('Cache hit for all wallets', { correlationId });
      return res.json(JSON.parse(cached));
    }

    cacheHitRate.labels('wallets', 'miss').inc();
    
    const result = await pool.query('SELECT * FROM wallets ORDER BY name');
    
    // Cache for 30 seconds
    await redisClient.setEx('wallets:all', 30, JSON.stringify(result.rows));
    
    logger.info('Retrieved all wallets', { 
      correlationId,
      count: result.rows.length 
    });
    
    res.json(result.rows);
  } catch (error) {
    logger.error('Failed to get wallets', { 
      correlationId,
      error: error.message 
    });
    res.status(500).json({ error: error.message });
  }
});

// Get wallet by user ID
app.get('/wallets/:userId', 
  validate([
    param('userId').isString().trim().notEmpty()
  ]),
  async (req, res) => {
    const { userId } = req.params;
    const correlationId = req.correlationId;
    
    try {
      // Try cache first
      const cacheKey = `wallet:${userId}`;
      const cached = await redisClient.get(cacheKey);
      
      if (cached) {
        cacheHitRate.labels('wallet', 'hit').inc();
        logger.info('Cache hit for wallet', { correlationId, userId });
        return res.json(JSON.parse(cached));
      }

      cacheHitRate.labels('wallet', 'miss').inc();

      const result = await pool.query(
        'SELECT * FROM wallets WHERE user_id = $1',
        [userId]
      );

      if (result.rows.length === 0) {
        logger.warn('Wallet not found', { correlationId, userId });
        return res.status(404).json({ error: 'Wallet not found' });
      }

      // Cache for 60 seconds
      await redisClient.setEx(cacheKey, 60, JSON.stringify(result.rows[0]));

      logger.info('Retrieved wallet', { 
        correlationId, 
        userId,
        balance: result.rows[0].balance 
      });

      res.json(result.rows[0]);
    } catch (error) {
      logger.error('Failed to get wallet', { 
        correlationId,
        userId,
        error: error.message 
      });
      res.status(500).json({ error: error.message });
    }
  }
);

// Create wallet (internal use - called by auth service)
app.post('/wallets',
  validate([
    body('user_id').isString().trim().notEmpty(),
    body('name').isString().trim().isLength({ min: 2, max: 100 }),
    body('balance').optional().isFloat({ min: 0 })
  ]),
  async (req, res) => {
    const { user_id, name, balance = 1000.00 } = req.body;
    const correlationId = req.correlationId;

    try {
      const result = await pool.query(
        `INSERT INTO wallets (user_id, name, balance) 
         VALUES ($1, $2, $3) 
         ON CONFLICT (user_id) DO NOTHING
         RETURNING *`,
        [user_id, name, balance]
      );

      if (result.rows.length === 0) {
        logger.warn('Wallet already exists', { correlationId, user_id });
        return res.status(409).json({ error: 'Wallet already exists' });
      }

      // Invalidate cache
      await redisClient.del('wallets:all');

      logger.info('Wallet created', { 
        correlationId,
        user_id,
        balance 
      });

      res.status(201).json(result.rows[0]);
    } catch (error) {
      logger.error('Failed to create wallet', { 
        correlationId,
        user_id,
        error: error.message 
      });
      res.status(500).json({ error: error.message });
    }
  }
);

// Transfer funds (internal use - called by transaction service)
// #### Transfer Endpoint with Metrics Tracking ####
// #### This endpoint tracks transaction metrics and database performance ####
app.post('/wallets/transfer',
  validate([
    body('fromUserId').isString().trim().notEmpty(),
    body('toUserId').isString().trim().notEmpty(),
    body('amount').isFloat({ min: 0.01 })
  ]),
  async (req, res) => {
    const { fromUserId, toUserId, amount } = req.body;
    const correlationId = req.correlationId;
    
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');
      
      // Track database connection
      dbConnections.set({ database: 'postgresql' }, pool.totalCount);

      logger.info('Starting transfer', {
        correlationId,
        fromUserId,
        toUserId,
        amount
      });

      // Lock rows for update
      const fromWallet = await client.query(
        'SELECT balance FROM wallets WHERE user_id = $1 FOR UPDATE',
        [fromUserId]
      );

      const toWallet = await client.query(
        'SELECT balance FROM wallets WHERE user_id = $1 FOR UPDATE',
        [toUserId]
      );

      if (fromWallet.rows.length === 0 || toWallet.rows.length === 0) {
        await client.query('ROLLBACK');
        logger.error('Wallet not found in transfer', {
          correlationId,
          fromUserId,
          toUserId
        });
        
        // Track failed transfer
        failedTransfers.inc({ reason: 'wallet_not_found', service: 'wallet-service' });
        
        return res.status(404).json({ error: 'Wallet not found' });
      }

      if (parseFloat(fromWallet.rows[0].balance) < amount) {
        await client.query('ROLLBACK');
        logger.warn('Insufficient funds', {
          correlationId,
          fromUserId,
          available: fromWallet.rows[0].balance,
          requested: amount
        });
        
        // Track failed transfer
        failedTransfers.inc({ reason: 'insufficient_funds', service: 'wallet-service' });
        
        return res.status(400).json({ error: 'Insufficient funds' });
      }

      // Update balances
      await client.query(
        'UPDATE wallets SET balance = balance - $1, updated_at = CURRENT_TIMESTAMP WHERE user_id = $2',
        [amount, fromUserId]
      );

      await client.query(
        'UPDATE wallets SET balance = balance + $1, updated_at = CURRENT_TIMESTAMP WHERE user_id = $2',
        [amount, toUserId]
      );

      await client.query('COMMIT');

      // Invalidate cache
      await Promise.all([
        redisClient.del(`wallet:${fromUserId}`),
        redisClient.del(`wallet:${toUserId}`),
        redisClient.del('wallets:all')
      ]);

      logger.info('Transfer completed successfully', {
        correlationId,
        fromUserId,
        toUserId,
        amount
      });

      // Track successful transaction
      transactionMetrics.inc({ status: 'success', type: 'transfer', service: 'wallet-service' });
      
      // Track successful transfer
      const amountRange = amount < 100 ? 'small' : amount < 1000 ? 'medium' : 'large';
      transfers.inc({ status: 'success', service: 'wallet-service', amount_range: amountRange });
      
      // Track Redis operations
      redisOperations.inc({ operation: 'del', status: 'success' });

      res.json({ 
        success: true, 
        message: 'Transfer completed',
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      await client.query('ROLLBACK');
      
      // Track failed transaction
      transactionMetrics.inc({ status: 'failed', type: 'transfer', service: 'wallet-service' });
      
      // Track failed transfer
      failedTransfers.inc({ reason: 'system_error', service: 'wallet-service' });
      
      logger.error('Transfer failed', {
        correlationId,
        fromUserId,
        toUserId,
        amount,
        error: error.message
      });
      res.status(500).json({ error: error.message });
    } finally {
      client.release();
    }
  }
);

// Get wallet balance (quick endpoint)
app.get('/wallets/:userId/balance',
  validate([
    param('userId').isString().trim().notEmpty()
  ]),
  async (req, res) => {
    const { userId } = req.params;
    const correlationId = req.correlationId;

    try {
      // Try cache first
      const cacheKey = `wallet:${userId}:balance`;
      const cached = await redisClient.get(cacheKey);

      if (cached) {
        cacheHitRate.labels('balance', 'hit').inc();
        return res.json({ balance: parseFloat(cached) });
      }

      cacheHitRate.labels('balance', 'miss').inc();

      const result = await pool.query(
        'SELECT balance FROM wallets WHERE user_id = $1',
        [userId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Wallet not found' });
      }

      const balance = result.rows[0].balance;

      // Cache for 10 seconds (balance changes frequently)
      await redisClient.setEx(cacheKey, 10, balance.toString());

      res.json({ balance: parseFloat(balance) });
    } catch (error) {
      logger.error('Failed to get balance', {
        correlationId,
        userId,
        error: error.message
      });
      res.status(500).json({ error: error.message });
    }
  }
);

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', {
    correlationId: req.correlationId,
    error: err.message,
    stack: err.stack
  });
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error',
    correlationId: req.correlationId
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ 
    error: 'Route not found',
    correlationId: req.correlationId
  });
});

// ============================================
// SERVER STARTUP
// ============================================
const server = app.listen(PORT, () => {
  logger.info(`Wallet service running on port ${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  server.close(async () => {
    logger.info('HTTP server closed');
    await pool.end();
    await redisClient.quit();
    process.exit(0);
  });
});

module.exports = app; // For testing
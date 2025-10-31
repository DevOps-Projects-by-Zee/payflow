const express = require('express');
const { Pool } = require('pg');
const amqp = require('amqplib');
const axios = require('axios');
const redis = require('redis');
const helmet = require('helmet');
const morgan = require('morgan');
const { body, param, query, validationResult } = require('express-validator');
const winston = require('winston');
const client = require('prom-client');
const CircuitBreaker = require('opossum');
const retry = require('async-retry');
const { v4: uuidv4 } = require('uuid');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3002;

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
    service: 'transaction-service',
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

const transactionTotal = new client.Counter({
  name: 'transactions_total',
  help: 'Total number of transactions',
  labelNames: ['status', 'type']
});

const transactionDuration = new client.Histogram({
  name: 'transaction_duration_seconds',
  help: 'Transaction processing duration',
  labelNames: ['status'],
  buckets: [1, 2, 5, 10, 30]
});

const queueDepth = new client.Gauge({
  name: 'queue_depth',
  help: 'Current depth of message queue',
  labelNames: ['queue_name']
});

register.registerMetric(httpRequestDuration);
register.registerMetric(transactionTotal);
register.registerMetric(transactionDuration);
register.registerMetric(queueDepth);

// ============================================
// MIDDLEWARE
// ============================================
app.use(helmet());
app.use(morgan('combined'));
app.use(express.json({ limit: '10kb' }));

// Correlation ID middleware
app.use((req, res, next) => {
  req.correlationId = req.headers['x-correlation-id'] || `txn-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
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

// ============================================
// REDIS CONNECTION (for idempotency)
// ============================================
const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://redis:6379'
});

redisClient.on('error', (err) => logger.error('Redis error:', err));
redisClient.connect();

// ============================================
// WALLET SERVICE CIRCUIT BREAKER
// ============================================
const WALLET_SERVICE_URL = process.env.WALLET_SERVICE_URL || 'http://wallet-service:3001';

const walletServiceBreaker = new CircuitBreaker(
  async ({ fromUserId, toUserId, amount, correlationId }) => {
    return axios.post(
      `${WALLET_SERVICE_URL}/wallets/transfer`,
      { fromUserId, toUserId, amount },
      { 
        headers: { 'X-Correlation-Id': correlationId },
        timeout: 5000
      }
    );
  },
  {
    timeout: 3000,
    errorThresholdPercentage: 50,
    resetTimeout: 30000,
    name: 'wallet-service'
  }
);

walletServiceBreaker.on('open', () => {
  logger.error('Circuit breaker opened: wallet-service');
});

walletServiceBreaker.on('halfOpen', () => {
  logger.warn('Circuit breaker half-open: wallet-service');
});

walletServiceBreaker.on('close', () => {
  logger.info('Circuit breaker closed: wallet-service');
});

walletServiceBreaker.fallback(() => {
  throw new Error('Wallet service temporarily unavailable');
});

// ============================================
// RABBITMQ CONNECTION
// ============================================
const RABBITMQ_URL = process.env.RABBITMQ_URL || 'amqp://rabbitmq:5672';
let channel;

async function initRabbitMQ() {
  try {
    const connection = await amqp.connect(RABBITMQ_URL);
    channel = await connection.createChannel();

    // Dead Letter Exchange
    await channel.assertExchange('dlx', 'direct', { durable: true });

    // Main transaction queue with DLX
    await channel.assertQueue('transactions', {
      durable: true,
      deadLetterExchange: 'dlx',
      deadLetterRoutingKey: 'transactions.failed',
      messageTtl: 600000 // 10 minutes
    });

    // Dead Letter Queue
    await channel.assertQueue('transactions.dlq', { durable: true });
    await channel.bindQueue('transactions.dlq', 'dlx', 'transactions.failed');

    // Retry queue
    await channel.assertQueue('transactions.retry', {
      durable: true,
      messageTtl: 30000, // 30 seconds
      deadLetterExchange: '',
      deadLetterRoutingKey: 'transactions'
    });

    // Notification queue
    await channel.assertQueue('notifications', { durable: true });

    // Monitor queue depth
    setInterval(async () => {
      try {
        const queue = await channel.checkQueue('transactions');
        queueDepth.labels('transactions').set(queue.messageCount);
      } catch (error) {
        logger.error('Queue monitoring error:', error);
      }
    }, 5000);

    // Start consuming
    channel.consume('transactions', async (msg) => {
      if (msg !== null) {
        const transaction = JSON.parse(msg.content.toString());
        const retryCount = msg.properties.headers['x-retry-count'] || 0;

        try {
          await processTransaction(transaction, retryCount);
          channel.ack(msg);
        } catch (error) {
          logger.error('Transaction processing failed:', {
            transactionId: transaction.id,
            retryCount,
            error: error.message
          });

          // Retry transient errors
          if (retryCount < 3 && isTransientError(error)) {
            logger.info('Requeuing transaction for retry:', {
              transactionId: transaction.id,
              retryCount: retryCount + 1
            });

            channel.sendToQueue('transactions.retry', msg.content, {
              persistent: true,
              headers: { 'x-retry-count': retryCount + 1 }
            });
            channel.ack(msg);
          } else {
            // Send to DLQ
            logger.error('Sending transaction to DLQ:', {
              transactionId: transaction.id,
              retryCount
            });
            channel.nack(msg, false, false);
          }
        }
      }
    }, { noAck: false });

    logger.info('RabbitMQ initialized successfully');
  } catch (error) {
    logger.error('RabbitMQ connection error:', error);
    setTimeout(initRabbitMQ, 5000);
  }
}

// Determine if error is transient
function isTransientError(error) {
  if (error.code === 'ECONNREFUSED' || error.code === 'ETIMEDOUT') {
    return true;
  }
  if (error.response) {
    const status = error.response.status;
    return status === 503 || status === 429 || status >= 500;
  }
  return false;
}

// ============================================
// IDEMPOTENCY MANAGER
// ============================================
class IdempotencyManager {
  constructor(redisClient) {
    this.redis = redisClient;
    this.ttl = 24 * 60 * 60; // 24 hours
  }

  async check(key, handler) {
    const idempotencyKey = `idempotency:${key}`;
    
    try {
      const cached = await this.redis.get(idempotencyKey);
      
      if (cached) {
        logger.info('Idempotent request detected:', { key });
        return { fromCache: true, data: JSON.parse(cached) };
      }

      const result = await handler();
      await this.redis.setEx(idempotencyKey, this.ttl, JSON.stringify(result));

      return { fromCache: false, data: result };
    } catch (error) {
      logger.error('Idempotency check failed:', { key, error: error.message });
      throw error;
    }
  }

  generateKey(userId, operation, params) {
    return `${userId}:${operation}:${JSON.stringify(params)}`;
  }
}

const idempotencyManager = new IdempotencyManager(redisClient);

// ============================================
// DATABASE INITIALIZATION
// ============================================
async function initDB() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS transactions (
        id VARCHAR(50) PRIMARY KEY,
        from_user_id VARCHAR(50) NOT NULL,
        to_user_id VARCHAR(50) NOT NULL,
        amount DECIMAL(15,2) NOT NULL,
        status VARCHAR(20) NOT NULL,
        error_message TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        processing_started_at TIMESTAMP,
        completed_at TIMESTAMP
      )
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);
      CREATE INDEX IF NOT EXISTS idx_transactions_from_user ON transactions(from_user_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_transactions_to_user ON transactions(to_user_id, created_at DESC);
    `);

    logger.info('Transaction database initialized');
  } finally {
    client.release();
  }
}

initDB().catch(console.error);
initRabbitMQ().catch(console.error);

// ============================================
// TRANSACTION PROCESSING
// ============================================
async function processTransaction(transaction, retryCount = 0) {
  const startTime = Date.now();
  const client = await pool.connect();
  
  try {
    logger.info('Processing transaction:', {
      transactionId: transaction.id,
      amount: transaction.amount,
      retryCount
    });

    // Update to PROCESSING
    await client.query(
      `UPDATE transactions 
       SET status = 'PROCESSING', processing_started_at = CURRENT_TIMESTAMP 
       WHERE id = $1`,
      [transaction.id]
    );

    // Simulate processing time
    await new Promise(resolve => setTimeout(resolve, 2000 + Math.random() * 1000));

    // Random 10% failure for demo
    if (Math.random() < 0.1) {
      throw new Error('Network timeout or insufficient funds');
    }

    // Call wallet service with circuit breaker and retry
    await retry(async () => {
      return walletServiceBreaker.fire({
        fromUserId: transaction.from_user_id,
        toUserId: transaction.to_user_id,
        amount: transaction.amount,
        correlationId: transaction.id
      });
    }, { 
      retries: 2,
      minTimeout: 1000,
      onRetry: (error, attempt) => {
        logger.warn('Retrying wallet service call:', {
          transactionId: transaction.id,
          attempt,
          error: error.message
        });
      }
    });

    // Update to COMPLETED
    await client.query(
      `UPDATE transactions 
       SET status = 'COMPLETED', completed_at = CURRENT_TIMESTAMP 
       WHERE id = $1`,
      [transaction.id]
    );

    const duration = (Date.now() - startTime) / 1000;
    transactionDuration.labels('completed').observe(duration);
    transactionTotal.labels('completed', 'transfer').inc();

    logger.info('Transaction completed successfully:', {
      transactionId: transaction.id,
      duration
    });

    // Send notifications
    if (channel) {
      channel.sendToQueue('notifications', Buffer.from(JSON.stringify({
        userId: transaction.from_user_id,
        type: 'TRANSACTION_COMPLETED',
        message: `Sent $${transaction.amount} to ${transaction.to_user_id}`,
        transactionId: transaction.id,
        amount: transaction.amount,
        otherParty: transaction.to_user_id
      })), { persistent: true });

      channel.sendToQueue('notifications', Buffer.from(JSON.stringify({
        userId: transaction.to_user_id,
        type: 'TRANSACTION_RECEIVED',
        message: `Received $${transaction.amount} from ${transaction.from_user_id}`,
        transactionId: transaction.id,
        amount: transaction.amount,
        otherParty: transaction.from_user_id
      })), { persistent: true });
    }

  } catch (error) {
    const duration = (Date.now() - startTime) / 1000;
    transactionDuration.labels('failed').observe(duration);
    transactionTotal.labels('failed', 'transfer').inc();

    logger.error('Transaction failed:', {
      transactionId: transaction.id,
      error: error.message,
      duration
    });

    await client.query(
      `UPDATE transactions 
       SET status = 'FAILED', error_message = $1, completed_at = CURRENT_TIMESTAMP 
       WHERE id = $2`,
      [error.message, transaction.id]
    );

    if (channel) {
      channel.sendToQueue('notifications', Buffer.from(JSON.stringify({
        userId: transaction.from_user_id,
        type: 'TRANSACTION_FAILED',
        message: `Transaction failed: ${error.message}`,
        transactionId: transaction.id
      })), { persistent: true });
    }

    throw error;
  } finally {
    client.release();
  }
}

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
    const queue = channel ? await channel.checkQueue('transactions').catch(() => null) : null;
    
    res.json({ 
      status: 'healthy', 
      service: 'transaction-service',
      database: 'connected',
      rabbitmq: channel ? 'connected' : 'disconnected',
      queueDepth: queue?.messageCount || 0,
      circuitBreaker: walletServiceBreaker.opened ? 'open' : 'closed',
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

// Create transaction
app.post('/transactions',
  validate([
    body('fromUserId').isString().trim().notEmpty(),
    body('toUserId').isString().trim().notEmpty(),
    body('amount').isFloat({ min: 0.01, max: 1000000 })
  ]),
  async (req, res) => {
    const { fromUserId, toUserId, amount } = req.body;
    const correlationId = req.correlationId;
    const idempotencyKey = req.headers['idempotency-key'];

    try {
      // Check idempotency if key provided
      if (idempotencyKey) {
        const key = idempotencyManager.generateKey(
          fromUserId,
          'create-transaction',
          { toUserId, amount }
        );

        const result = await idempotencyManager.check(key, async () => {
          return await createTransaction(fromUserId, toUserId, amount, correlationId);
        });

        if (result.fromCache) {
          res.setHeader('X-Idempotent-Replay', 'true');
        }

        return res.status(201).json(result.data);
      }

      // No idempotency key - process normally
      const result = await createTransaction(fromUserId, toUserId, amount, correlationId);
      res.status(201).json(result);

    } catch (error) {
      logger.error('Transaction creation failed:', {
        correlationId,
        error: error.message
      });
      res.status(500).json({ error: error.message });
    }
  }
);

async function createTransaction(fromUserId, toUserId, amount, correlationId) {
  const transactionId = `TXN-${Date.now()}-${Math.random().toString(36).substr(2, 9).toUpperCase()}`;

  logger.info('Creating transaction:', {
    correlationId,
    transactionId,
    fromUserId,
    toUserId,
    amount
  });

  await pool.query(
    `INSERT INTO transactions (id, from_user_id, to_user_id, amount, status) 
     VALUES ($1, $2, $3, $4, 'PENDING')`,
    [transactionId, fromUserId, toUserId, amount]
  );

  transactionTotal.labels('pending', 'transfer').inc();

  // Add to queue
  if (channel) {
    channel.sendToQueue('transactions', Buffer.from(JSON.stringify({
      id: transactionId,
      from_user_id: fromUserId,
      to_user_id: toUserId,
      amount: parseFloat(amount)
    })), { persistent: true });
  }

  return {
    id: transactionId,
    status: 'PENDING',
    message: 'Transaction queued for processing',
    timestamp: new Date().toISOString()
  };
}

// Get all transactions
app.get('/transactions',
  validate([
    query('userId').optional().isString(),
    query('status').optional().isIn(['PENDING', 'PROCESSING', 'COMPLETED', 'FAILED']),
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt()
  ]),
  async (req, res) => {
    const { userId, status, limit = 100 } = req.query;
    const correlationId = req.correlationId;

    try {
      let query = 'SELECT * FROM transactions WHERE 1=1';
      const params = [];

      if (userId) {
        params.push(userId);
        query += ` AND (from_user_id = $${params.length} OR to_user_id = $${params.length})`;
      }

      if (status) {
        params.push(status);
        query += ` AND status = $${params.length}`;
      }

      params.push(limit);
      query += ` ORDER BY created_at DESC LIMIT $${params.length}`;

      const result = await pool.query(query, params);

      logger.info('Retrieved transactions:', {
        correlationId,
        count: result.rows.length,
        userId,
        status
      });

      res.json(result.rows);
    } catch (error) {
      logger.error('Failed to get transactions:', {
        correlationId,
        error: error.message
      });
      res.status(500).json({ error: error.message });
    }
  }
);

// Get transaction by ID
app.get('/transactions/:txnId',
  validate([
    param('txnId').isString().trim().notEmpty()
  ]),
  async (req, res) => {
    const { txnId } = req.params;
    const correlationId = req.correlationId;

    try {
      const result = await pool.query(
        'SELECT * FROM transactions WHERE id = $1',
        [txnId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Transaction not found' });
      }

      logger.info('Retrieved transaction:', {
        correlationId,
        transactionId: txnId
      });

      res.json(result.rows[0]);
    } catch (error) {
      logger.error('Failed to get transaction:', {
        correlationId,
        transactionId: txnId,
        error: error.message
      });
      res.status(500).json({ error: error.message });
    }
  }
);

// Get queue metrics
app.get('/metrics/queue', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT status, COUNT(*) as count 
      FROM transactions 
      GROUP BY status
    `);

    const metrics = {
      pending: 0,
      processing: 0,
      completed: 0,
      failed: 0
    };

    result.rows.forEach(row => {
      metrics[row.status.toLowerCase()] = parseInt(row.count);
    });

    if (channel) {
      const queue = await channel.checkQueue('transactions');
      metrics.queueDepth = queue.messageCount;
    }

    res.json(metrics);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DLQ monitoring
app.get('/admin/dlq', async (req, res) => {
  try {
    if (!channel) {
      return res.status(503).json({ error: 'RabbitMQ not connected' });
    }

    const queue = await channel.checkQueue('transactions.dlq');

    res.json({
      queueName: 'transactions.dlq',
      messageCount: queue.messageCount,
      consumerCount: queue.consumerCount
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

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
  logger.info(`Transaction service running on port ${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  server.close(async () => {
    logger.info('HTTP server closed');
    if (channel) await channel.close();
    await pool.end();
    await redisClient.quit();
    process.exit(0);
  });
});

module.exports = app; // For testing
const express = require('express');
const { Pool } = require('pg');
const amqp = require('amqplib');
const nodemailer = require('nodemailer');
const helmet = require('helmet');
const morgan = require('morgan');
const { param, validationResult } = require('express-validator');
const winston = require('winston');
const client = require('prom-client');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3003;

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
    service: 'notification-service',
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

const notificationTotal = new client.Counter({
  name: 'notifications_total',
  help: 'Total number of notifications',
  labelNames: ['type', 'channel', 'status']
});

const emailSendDuration = new client.Histogram({
  name: 'email_send_duration_seconds',
  help: 'Email sending duration',
  buckets: [0.5, 1, 2, 5, 10]
});

register.registerMetric(httpRequestDuration);
register.registerMetric(notificationTotal);
register.registerMetric(emailSendDuration);

// ============================================
// MIDDLEWARE
// ============================================
app.use(helmet());
app.use(morgan('combined'));
app.use(express.json({ limit: '10kb' }));

// Correlation ID middleware
app.use((req, res, next) => {
  req.correlationId = req.headers['x-correlation-id'] || `notif-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
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
});

// ============================================
// EMAIL SERVICE SETUP
// ============================================
class EmailService {
  constructor() {
    this.transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || 'smtp.gmail.com',
      port: process.env.SMTP_PORT || 587,
      secure: false,
      auth: process.env.SMTP_USER ? {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASSWORD
      } : undefined
    });

    // Test connection on startup
    this.testConnection();
  }

  async testConnection() {
    if (!process.env.SMTP_USER) {
      logger.warn('SMTP not configured - emails will be logged only');
      return;
    }

    try {
      await this.transporter.verify();
      logger.info('SMTP connection verified');
    } catch (error) {
      logger.error('SMTP connection failed:', error.message);
    }
  }

  async sendTransactionNotification(to, transactionData) {
    const { type, amount, otherParty, transactionId } = transactionData;
    const startTime = Date.now();

    let subject, html;

    if (type === 'TRANSACTION_COMPLETED' || type === 'SENT') {
      subject = `Payment Sent: $${amount}`;
      html = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #2563eb;">Payment Sent Successfully</h2>
          <p>You have sent <strong>$${amount}</strong> to ${otherParty}.</p>
          <p><strong>Transaction ID:</strong> ${transactionId}</p>
          <p><strong>Date:</strong> ${new Date().toLocaleString()}</p>
          <hr style="border: 1px solid #e5e7eb; margin: 20px 0;">
          <p style="color: #6b7280; font-size: 12px;">
            If you did not authorize this transaction, please contact support immediately.
          </p>
        </div>
      `;
    } else if (type === 'TRANSACTION_RECEIVED' || type === 'RECEIVED') {
      subject = `Payment Received: $${amount}`;
      html = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #059669;">Payment Received</h2>
          <p>You have received <strong>$${amount}</strong> from ${otherParty}.</p>
          <p><strong>Transaction ID:</strong> ${transactionId}</p>
          <p><strong>Date:</strong> ${new Date().toLocaleString()}</p>
          <hr style="border: 1px solid #e5e7eb; margin: 20px 0;">
          <p style="color: #6b7280; font-size: 12px;">
            Your balance has been updated automatically.
          </p>
        </div>
      `;
    } else if (type === 'TRANSACTION_FAILED' || type === 'FAILED') {
      subject = `Transaction Failed`;
      html = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #dc2626;">Transaction Failed</h2>
          <p>Your transaction of <strong>$${amount}</strong> to ${otherParty} has failed.</p>
          <p><strong>Transaction ID:</strong> ${transactionId}</p>
          <p><strong>Reason:</strong> ${transactionData.reason || 'Processing error'}</p>
          <hr style="border: 1px solid #e5e7eb; margin: 20px 0;">
          <p style="color: #6b7280; font-size: 12px;">
            Please try again or contact support if the problem persists.
          </p>
        </div>
      `;
    }

    try {
      if (!process.env.SMTP_USER) {
        // Log email instead of sending if SMTP not configured
        logger.info('Email notification (not sent - SMTP not configured):', {
          to,
          subject,
          type
        });
        notificationTotal.labels(type, 'email', 'logged').inc();
        return { logged: true };
      }

      const info = await this.transporter.sendMail({
        from: '"PayFlow" <noreply@payflow.com>',
        to,
        subject,
        html
      });

      const duration = (Date.now() - startTime) / 1000;
      emailSendDuration.observe(duration);
      notificationTotal.labels(type, 'email', 'sent').inc();

      logger.info('Email sent successfully:', {
        messageId: info.messageId,
        to,
        type,
        duration
      });

      return info;
    } catch (error) {
      notificationTotal.labels(type, 'email', 'failed').inc();
      logger.error('Email sending failed:', {
        to,
        type,
        error: error.message
      });
      throw error;
    }
  }

  async sendWelcomeEmail(to, name) {
    const subject = 'Welcome to PayFlow!';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #2563eb;">Welcome to PayFlow, ${name}!</h1>
        <p>Thank you for joining our digital wallet platform.</p>
        <p>Your account has been created successfully with an initial balance of <strong>$1,000</strong>.</p>
        <h3>Getting Started:</h3>
        <ul>
          <li>Complete your profile</li>
          <li>Verify your email address</li>
          <li>Enable two-factor authentication for extra security</li>
          <li>Start sending and receiving payments</li>
        </ul>
        <hr style="border: 1px solid #e5e7eb; margin: 20px 0;">
        <p style="color: #6b7280; font-size: 12px;">
          If you have any questions, feel free to contact our support team.
        </p>
        <p style="color: #6b7280; font-size: 12px;">
          Best regards,<br>The PayFlow Team
        </p>
      </div>
    `;

    try {
      if (!process.env.SMTP_USER) {
        logger.info('Welcome email (not sent - SMTP not configured):', { to });
        return { logged: true };
      }

      const info = await this.transporter.sendMail({
        from: '"PayFlow" <welcome@payflow.com>',
        to,
        subject,
        html
      });

      notificationTotal.labels('welcome', 'email', 'sent').inc();
      logger.info('Welcome email sent:', { to, messageId: info.messageId });
      return info;
    } catch (error) {
      notificationTotal.labels('welcome', 'email', 'failed').inc();
      logger.error('Welcome email failed:', { to, error: error.message });
      throw error;
    }
  }
}

const emailService = new EmailService();

// ============================================
// SMS SERVICE (Optional - Twilio)
// ============================================
class SMSService {
  constructor() {
    this.enabled = !!(process.env.TWILIO_ACCOUNT_SID && process.env.TWILIO_AUTH_TOKEN);
    
    if (this.enabled) {
      const twilio = require('twilio');
      this.client = twilio(
        process.env.TWILIO_ACCOUNT_SID,
        process.env.TWILIO_AUTH_TOKEN
      );
      this.fromNumber = process.env.TWILIO_PHONE_NUMBER;
      logger.info('SMS service enabled (Twilio)');
    } else {
      logger.warn('SMS service disabled - Twilio not configured');
    }
  }

  async sendTransactionAlert(to, amount, type) {
    if (!this.enabled) {
      logger.info('SMS notification (not sent - SMS not configured):', { to, amount, type });
      notificationTotal.labels('transaction', 'sms', 'logged').inc();
      return { logged: true };
    }

    const message = type === 'SENT' 
      ? `PayFlow: You sent $${amount}. Ref: ${Date.now()}`
      : `PayFlow: You received $${amount}. Ref: ${Date.now()}`;

    try {
      const result = await this.client.messages.create({
        body: message,
        from: this.fromNumber,
        to
      });

      notificationTotal.labels('transaction', 'sms', 'sent').inc();
      logger.info('SMS sent successfully:', {
        to,
        sid: result.sid,
        type
      });

      return result;
    } catch (error) {
      notificationTotal.labels('transaction', 'sms', 'failed').inc();
      logger.error('SMS sending failed:', {
        to,
        error: error.message
      });
      throw error;
    }
  }
}

const smsService = new SMSService();

// ============================================
// RABBITMQ CONNECTION
// ============================================
const RABBITMQ_URL = process.env.RABBITMQ_URL || 'amqp://rabbitmq:5672';
let channel;

async function initRabbitMQ() {
  try {
    const connection = await amqp.connect(RABBITMQ_URL);
    channel = await connection.createChannel();

    await channel.assertQueue('notifications', { durable: true });

    // Start consuming notifications
    channel.consume('notifications', async (msg) => {
      if (msg !== null) {
        try {
          const notification = JSON.parse(msg.content.toString());
          await processNotification(notification);
          channel.ack(msg);
        } catch (error) {
          logger.error('Notification processing failed:', error);
          // Don't requeue - log and move on
          channel.ack(msg);
        }
      }
    }, { noAck: false });

    logger.info('RabbitMQ initialized and consuming notifications');
  } catch (error) {
    logger.error('RabbitMQ connection error:', error);
    setTimeout(initRabbitMQ, 5000);
  }
}

// ============================================
// NOTIFICATION PROCESSING
// ============================================
async function processNotification(notification) {
  try {
    logger.info('Processing notification:', {
      userId: notification.userId,
      type: notification.type
    });

    // Store in database
    await pool.query(
      `INSERT INTO notifications (user_id, type, message, transaction_id) 
       VALUES ($1, $2, $3, $4)`,
      [
        notification.userId,
        notification.type,
        notification.message,
        notification.transactionId || null
      ]
    );

    notificationTotal.labels(notification.type, 'database', 'stored').inc();

    // Get user email for sending notifications
    const userResult = await pool.query(
      'SELECT email, name FROM users WHERE id = $1',
      [notification.userId]
    );

    if (userResult.rows.length === 0) {
      logger.warn('User not found for notification:', {
        userId: notification.userId
      });
      return;
    }

    const user = userResult.rows[0];

    // Send email notification (if user has email)
    if (user.email) {
      try {
        const transactionData = {
          type: notification.type,
          amount: notification.amount,
          otherParty: notification.otherParty,
          transactionId: notification.transactionId,
          reason: notification.error
        };

        await emailService.sendTransactionNotification(user.email, transactionData);
      } catch (error) {
        logger.error('Email notification failed (non-fatal):', {
          userId: notification.userId,
          error: error.message
        });
      }
    }

    // SMS notification could be added here if phone number available
    // if (user.phone && user.notification_preferences?.sms) { ... }

    logger.info('Notification processed successfully:', {
      userId: notification.userId,
      type: notification.type
    });

  } catch (error) {
    logger.error('Notification processing failed:', {
      error: error.message,
      notification
    });
    throw error;
  }
}

// ============================================
// DATABASE INITIALIZATION
// ============================================
async function initDB() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id SERIAL PRIMARY KEY,
        user_id VARCHAR(50) NOT NULL,
        type VARCHAR(50) NOT NULL,
        message TEXT NOT NULL,
        transaction_id VARCHAR(50),
        read BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC);
    `);

    logger.info('Notification database initialized');
  } finally {
    client.release();
  }
}

initDB().catch(console.error);
initRabbitMQ().catch(console.error);

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
    res.json({ 
      status: 'healthy', 
      service: 'notification-service',
      database: 'connected',
      rabbitmq: channel ? 'connected' : 'disconnected',
      email: process.env.SMTP_USER ? 'configured' : 'not_configured',
      sms: smsService.enabled ? 'configured' : 'not_configured',
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

// Get notifications for a user
app.get('/notifications/:userId',
  validate([
    param('userId').isString().trim().notEmpty()
  ]),
  async (req, res) => {
    const { userId } = req.params;
    const correlationId = req.correlationId;

    try {
      const result = await pool.query(
        `SELECT * FROM notifications 
         WHERE user_id = $1 
         ORDER BY created_at DESC 
         LIMIT 50`,
        [userId]
      );

      logger.info('Retrieved notifications:', {
        correlationId,
        userId,
        count: result.rows.length
      });

      res.json(result.rows);
    } catch (error) {
      logger.error('Failed to get notifications:', {
        correlationId,
        userId,
        error: error.message
      });
      res.status(500).json({ error: error.message });
    }
  }
);

// Mark notification as read
app.put('/notifications/:id/read',
  validate([
    param('id').isInt().toInt()
  ]),
  async (req, res) => {
    const { id } = req.params;
    const correlationId = req.correlationId;

    try {
      const result = await pool.query(
        'UPDATE notifications SET read = TRUE WHERE id = $1 RETURNING *',
        [id]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Notification not found' });
      }

      logger.info('Notification marked as read:', {
        correlationId,
        notificationId: id
      });

      res.json(result.rows[0]);
    } catch (error) {
      logger.error('Failed to mark notification as read:', {
        correlationId,
        notificationId: id,
        error: error.message
      });
      res.status(500).json({ error: error.message });
    }
  }
);

// Get notification statistics
app.get('/notifications/:userId/stats', async (req, res) => {
  const { userId } = req.params;

  try {
    const result = await pool.query(
      `SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE read = false) as unread,
        COUNT(*) FILTER (WHERE type = 'TRANSACTION_COMPLETED') as sent,
        COUNT(*) FILTER (WHERE type = 'TRANSACTION_RECEIVED') as received,
        COUNT(*) FILTER (WHERE type = 'TRANSACTION_FAILED') as failed
       FROM notifications 
       WHERE user_id = $1`,
      [userId]
    );

    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Manual notification trigger (for testing)
app.post('/notifications/test', async (req, res) => {
  const { userId, type, message } = req.body;

  try {
    if (!userId || !type || !message) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const notification = {
      userId,
      type,
      message,
      transactionId: `TEST-${Date.now()}`
    };

    await processNotification(notification);

    res.json({ 
      success: true, 
      message: 'Test notification processed' 
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
  logger.info(`Notification service running on port ${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  server.close(async () => {
    logger.info('HTTP server closed');
    if (channel) await channel.close();
    await pool.end();
    process.exit(0);
  });
});

module.exports = app; // For testing
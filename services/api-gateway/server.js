// #### PayFlow API Gateway Server ####
// #### This is the main entry point for all client requests ####
// #### It handles routing, authentication, rate limiting, and monitoring ####

// #### Core Dependencies ####
const express = require('express'); // #### Web framework for Node.js ####
const helmet = require('helmet'); // #### Security middleware - sets security headers ####
const cors = require('cors'); // #### Cross-Origin Resource Sharing - allows frontend to call API ####
const morgan = require('morgan'); // #### HTTP request logger middleware ####
const rateLimit = require('express-rate-limit'); // #### Rate limiting to prevent abuse ####
const axios = require('axios'); // #### HTTP client for calling other services ####

// #### Custom Middleware ####
const { authenticate, authorizeOwner, authorizeRole } = require('./middleware/auth'); // #### Authentication & authorization ####
const { validate, validators } = require('./middleware/validation'); // #### Input validation ####

// #### Monitoring Dependencies ####
const { register, Counter, Histogram, Gauge } = require('prom-client'); // #### Prometheus metrics collection ####
require('dotenv').config(); // #### Load environment variables from .env file ####

// #### Prometheus Metrics Setup ####
// #### These metrics track infrastructure health and performance ####
// #### Metrics are collected by Prometheus and displayed in Grafana ####

// #### Infrastructure Health Monitoring ####
// #### Tracks if PostgreSQL, Redis, RabbitMQ are up and running ####
const infrastructureHealth = new Gauge({
  name: 'infrastructure_health', // #### Metric name in Prometheus ####
  help: 'Health status of infrastructure services (1=healthy, 0=down)', // #### Description for Prometheus ####
  labelNames: ['service', 'type'] // #### Labels to categorize metrics ####
});

// #### Circuit Breaker Monitoring ####
// #### Tracks circuit breaker states to prevent cascading failures ####
const circuitBreakerState = new Gauge({
  name: 'circuit_breaker_state', // #### Metric name ####
  help: 'Circuit breaker state (0=closed, 1=open, 2=half-open)', // #### 0=working, 1=broken, 2=testing ####
  labelNames: ['service', 'operation'] // #### Which service and operation ####
});

// #### Database Connection Monitoring ####
// #### Tracks active database connections to prevent overload ####
const dbConnections = new Gauge({
  name: 'database_connections_active', // #### Metric name ####
  help: 'Number of active database connections', // #### Description ####
  labelNames: ['database'] // #### Which database (postgres, redis) ####
});

// #### Redis Operations Counter ####
// #### Counts Redis operations for performance monitoring ####
const redisOperations = new Counter({
  name: 'redis_operations_total', // #### Metric name ####
  help: 'Total number of Redis operations', // #### Description ####
  labelNames: ['operation', 'status'] // #### Operation type and success/failure ####
});

// #### RabbitMQ Message Counter ####
// #### Counts messages processed through RabbitMQ ####
const rabbitmqMessages = new Counter({
  name: 'rabbitmq_messages_total', // #### Metric name ####
  help: 'Total number of RabbitMQ messages processed', // #### Description ####
  labelNames: ['queue', 'status'] // #### Queue name and processing status ####
});

// #### Service Success Rate Monitoring ####
// #### Tracks how often services respond successfully ####
const serviceSuccessRate = new Gauge({
  name: 'service_success_rate', // #### Metric name ####
  help: 'Success rate of service operations (0-1)', // #### 0=0%, 1=100% success ####
  labelNames: ['service', 'operation'] // #### Which service and operation ####
});

// #### HTTP Request Rate Counter ####
// #### Counts all HTTP requests for traffic analysis ####
const requestRate = new Counter({
  name: 'http_requests_total', // #### Metric name ####
  help: 'Total number of HTTP requests', // #### Description ####
  labelNames: ['method', 'route', 'status_code', 'service'] // #### Request details ####
});

// #### HTTP Error Rate Counter ####
// #### Counts HTTP errors for failure analysis ####
const errorRate = new Counter({
  name: 'http_errors_total', // #### Metric name ####
  help: 'Total number of HTTP errors', // #### Description ####
  labelNames: ['method', 'route', 'status_code', 'service'] // #### Error details ####
});

// #### Business Metrics ####
// #### These metrics track business-specific KPIs for financial insights ####

// #### User Registration Tracking ####
// #### Counts successful and failed user signups ####
const userSignups = new Counter({
  name: 'user_signups_total', // #### Metric name ####
  help: 'Total number of user registrations', // #### Description ####
  labelNames: ['status', 'service'] // #### success/failure and service ####
});

// #### Money Transfer Tracking ####
// #### Counts money transfers for business analytics ####
const transfers = new Counter({
  name: 'transfers_total',
  help: 'Total number of money transfers',
  labelNames: ['status', 'service', 'amount_range']
});

// #### Failed Transfer Tracking ####
// #### Counts failed transfers for error analysis ####
const failedTransfers = new Counter({
  name: 'failed_transfers_total', // #### Metric name ####
  help: 'Total number of failed transfers', // #### Description ####
  labelNames: ['reason', 'service'] // #### Failure reason and service ####
});

// #### Transaction Metrics ####
// #### Counts all transaction types for business intelligence ####
const transactionMetrics = new Counter({
  name: 'transactions_total', // #### Metric name ####
  help: 'Total number of transactions processed', // #### Description ####
  labelNames: ['status', 'type', 'service'] // #### Transaction details ####
});

// #### Express Application Setup ####
// #### Create the main Express application ####
const app = express(); // #### Create Express app instance ####
const PORT = process.env.PORT || 3000; // #### Use environment port or default to 3000 ####

// #### Infrastructure Health Check Function ####
// #### This function checks the health of all infrastructure services ####
// #### Called periodically to update Prometheus metrics ####
const checkInfrastructureHealth = async () => {
  try {
    // #### Check PostgreSQL Database ####
    // #### Test database connection by running a simple query ####
    try {
      const { Pool } = require('pg'); // #### PostgreSQL client library ####
      const testPool = new Pool({ // #### Create connection pool ####
        host: 'postgres', // #### Database host (Docker service name) ####
        port: 5432, // #### PostgreSQL default port ####
        database: 'payflow', // #### Database name ####
        user: 'payflow', // #### Database username ####
        password: 'payflow123', // #### Database password ####
        max: 1, // #### Max connections in pool ####
        idleTimeoutMillis: 1000, // #### Close idle connections after 1 second ####
        connectionTimeoutMillis: 5000 // #### Connection timeout ####
      });
      const client = await testPool.connect(); // #### Get connection from pool ####
      await client.query('SELECT 1'); // #### Test query - returns 1 if DB is working ####
      client.release(); // #### Return connection to pool ####
      await testPool.end(); // #### Close pool ####
      infrastructureHealth.set({ service: 'postgresql', type: 'database' }, 1); // #### Mark as healthy ####
    } catch (error) {
      infrastructureHealth.set({ service: 'postgresql', type: 'database' }, 0); // #### Mark as down ####
    }

    // #### Check Redis Cache ####
    // #### Test Redis connection by sending ping command ####
    try {
      const redis = require('redis'); // #### Redis client library ####
      const redisClient = redis.createClient({ url: 'redis://redis:6379' }); // #### Connect to Redis ####
      await redisClient.connect(); // #### Establish connection ####
      await redisClient.ping(); // #### Send ping command ####
      await redisClient.quit(); // #### Close connection ####
      infrastructureHealth.set({ service: 'redis', type: 'cache' }, 1); // #### Mark as healthy ####
    } catch (error) {
      infrastructureHealth.set({ service: 'redis', type: 'cache' }, 0); // #### Mark as down ####
    }

    // #### Check RabbitMQ Message Queue ####
    // #### Test RabbitMQ by accessing management interface ####
    try {
      const rabbitmqResponse = await axios.get('http://rabbitmq:15672', { timeout: 5000 }); // #### HTTP request to management UI ####
      infrastructureHealth.set({ service: 'rabbitmq', type: 'queue' }, 1); // #### Mark as healthy ####
    } catch (error) {
      infrastructureHealth.set({ service: 'rabbitmq', type: 'queue' }, 0); // #### Mark as down ####
    }

    // #### Check Internal Microservices ####
    // #### Test all PayFlow services by calling their health endpoints ####
    const services = [
      { name: 'auth-service', port: 3004 },
      { name: 'wallet-service', port: 3001 },
      { name: 'transaction-service', port: 3002 },
      { name: 'notification-service', port: 3003 }
    ];
    
    for (const service of services) {
      try {
        const serviceResponse = await axios.get(`http://${service.name}:${service.port}/health`, { timeout: 5000 });
        serviceSuccessRate.set({ service: service.name, operation: 'health_check' }, 1);
      } catch (error) {
        serviceSuccessRate.set({ service: service.name, operation: 'health_check' }, 0);
      }
    }
  } catch (error) {
    console.error('Infrastructure health check failed:', error);
  }
};

// #### Circuit Breaker Implementation ####
// #### This prevents cascading failures when services are down ####
// #### Circuit breaker has 3 states: Closed (working), Open (broken), Half-Open (testing) ####
const circuitBreakers = new Map(); // #### Store circuit breaker states ####

// #### Get or create circuit breaker for a service/operation ####
const getCircuitBreaker = (service, operation) => {
  const key = `${service}-${operation}`; // #### Unique key for each service-operation ####
  if (!circuitBreakers.has(key)) { // #### Create new circuit breaker if doesn't exist ####
    circuitBreakers.set(key, {
      state: 0, // #### 0=closed (working), 1=open (broken), 2=half-open (testing) ####
      failures: 0, // #### Count of consecutive failures ####
      lastFailure: null, // #### Timestamp of last failure ####
      threshold: 5, // #### Number of failures before opening circuit ####
      timeout: 60000 // #### Time to wait before trying again (1 minute) ####
    });
  }
  return circuitBreakers.get(key); // #### Return circuit breaker state ####
};

// #### Execute function with circuit breaker protection ####
const executeWithCircuitBreaker = async (service, operation, fn) => {
  const breaker = getCircuitBreaker(service, operation); // #### Get circuit breaker ####
  const now = Date.now(); // #### Current timestamp ####

  // #### Check if circuit breaker should be reset ####
  // #### If circuit is open and timeout has passed, try half-open ####
  if (breaker.state === 1 && (now - breaker.lastFailure) > breaker.timeout) {
    breaker.state = 2; // #### half-open - testing if service is back ####
    circuitBreakerState.set({ service, operation }, 2); // #### Update Prometheus metric ####
  }

  // #### If circuit is open, reject immediately ####
  // #### Don't call the service if it's known to be broken ####
  if (breaker.state === 1) {
    circuitBreakerState.set({ service, operation }, 1); // #### Update metric ####
    throw new Error(`Circuit breaker open for ${service}-${operation}`); // #### Throw error ####
  }

  try {
    const result = await fn(); // #### Try to call the service ####
    // #### Success - reset circuit breaker ####
    breaker.failures = 0; // #### Reset failure count ####
    breaker.state = 0; // #### Set to closed (working) ####
    circuitBreakerState.set({ service, operation }, 0); // #### Update metric ####
    return result; // #### Return successful result ####
  } catch (error) {
    breaker.failures++; // #### Increment failure count ####
    breaker.lastFailure = now; // #### Record failure time ####
    
    // #### If too many failures, open the circuit ####
    if (breaker.failures >= breaker.threshold) {
      breaker.state = 1; // #### open - stop calling this service ####
      circuitBreakerState.set({ service, operation }, 1); // #### Update metric ####
    }
    throw error;
  }
};

// #### Periodic Infrastructure Health Checks ####
// #### Run health checks every 30 seconds to keep metrics updated ####
setInterval(checkInfrastructureHealth, 30000); // #### 30 seconds = 30000 milliseconds ####
checkInfrastructureHealth(); // #### Run initial check immediately ####

// #### Express Middleware Setup ####
// #### These middleware functions run on every request ####

// #### Security Middleware ####
app.use(helmet()); // #### Sets security headers (X-Frame-Options, X-XSS-Protection, etc.) ####
app.set('trust proxy', 1); // #### Trust proxy headers from ingress controller ####
app.use(cors({ // #### Cross-Origin Resource Sharing ####
  origin: process.env.CORS_ORIGIN || '*', // #### Allow requests from any origin (dev) or specific origin (prod) ####
  credentials: true // #### Allow cookies and authentication headers ####
}));
app.use(morgan('combined')); // #### Log all HTTP requests ####
app.use(express.json({ limit: '10kb' })); // #### Parse JSON bodies, limit to 10KB ####

// #### Rate Limiting Configuration ####
// #### Prevents abuse by limiting requests per IP address ####
const isDevelopment = process.env.NODE_ENV !== 'production'; // #### Check if running in development ####

// #### General Rate Limiter ####
// #### Applies to all API routes ####
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // #### 15 minutes window ####
  max: isDevelopment ? 1000 : 100, // #### 1000 requests in dev, 100 in production ####
  message: 'Too many requests from this IP', // #### Error message ####
  skipSuccessfulRequests: true, // #### Don't count successful requests ####
  standardHeaders: true, // #### Add rate limit headers to response ####
  legacyHeaders: false // #### Don't add legacy headers ####
});

// #### Authentication Rate Limiter ####
// #### Stricter limits for login/register endpoints ####
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // #### 15 minutes window ####
  max: isDevelopment ? 50 : 5, // #### 50 attempts in dev, 5 in prod ####
  message: 'Too many authentication attempts', // #### Error message ####
  skipSuccessfulRequests: true, // #### Don't penalize successful logins ####
  standardHeaders: true, // #### Add rate limit headers ####
  legacyHeaders: false, // #### Don't add legacy headers ####
  handler: (req, res) => { // #### Custom handler for rate limit exceeded ####
    console.log('Rate limit hit:', req.ip, req.path); // #### Log the violation ####
    res.status(429).json({ // #### Return 429 Too Many Requests ####
      error: 'Too many attempts. Please try again in a few minutes.', // #### User-friendly message ####
      retryAfter: '15 minutes' // #### When they can try again ####
    });
  }
});

// #### Transaction Rate Limiter ####
// #### Limits transaction requests to prevent spam ####
const transactionLimiter = rateLimit({
  windowMs: 60 * 1000, // #### 1 minute window ####
  max: isDevelopment ? 100 : 10, // #### 100 requests in dev, 10 in prod ####
  message: 'Too many transaction requests' // #### Error message ####
});

// #### Apply Rate Limiters ####
app.use('/api/', generalLimiter); // #### Apply general limiter to all API routes ####

// #### Metrics Collection Middleware ####
// #### This middleware collects metrics for every request ####
app.use((req, res, next) => {
  const start = Date.now();
  
  // Track errors when response finishes
  res.on('finish', () => {
    // Increment request counter with actual status code
    requestRate.inc({
      method: req.method,
      route: req.route?.path || req.path,
      status_code: res.statusCode,
      service: 'api-gateway'
    });

    // Track errors
    if (res.statusCode >= 400) {
      errorRate.inc({
        method: req.method,
        route: req.route?.path || req.path,
        status_code: res.statusCode,
        service: 'api-gateway'
      });
    }
  });

  next();
});

// Service URLs
const AUTH_SERVICE = process.env.AUTH_SERVICE_URL || 'http://auth-service:3004';
const WALLET_SERVICE = process.env.WALLET_SERVICE_URL || 'http://wallet-service:3001';
const TRANSACTION_SERVICE = process.env.TRANSACTION_SERVICE_URL || 'http://transaction-service:3002';
const NOTIFICATION_SERVICE = process.env.NOTIFICATION_SERVICE_URL || 'http://notification-service:3003';

// #### Health Check Endpoint ####
// #### This endpoint reports the health of the API Gateway ####
// #### Available at both /health and /api/health for compatibility ####
const healthCheckHandler = (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    service: 'api-gateway',
    version: process.env.npm_package_version || '1.0.0'
  });
};

app.get('/health', healthCheckHandler);
app.get('/api/health', healthCheckHandler);  // Also available at /api/health for consistency

// #### Metrics Endpoint ####
// #### This endpoint exposes Prometheus metrics ####
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (error) {
    res.status(500).end(error.message);
  }
});

// ============================================
// AUTH ROUTES (Public)
// ============================================
// #### Auth Routes with Circuit Breaker ####
// #### These routes use circuit breakers to prevent cascading failures ####
app.post('/api/auth/register', authLimiter, async (req, res) => {
  try {
    const response = await executeWithCircuitBreaker('auth-service', 'register', async () => {
      return await axios.post(`${AUTH_SERVICE}/auth/register`, req.body);
    });
    
    // Track successful registration
    transactionMetrics.inc({ status: 'success', type: 'registration', service: 'auth-service' });
    userSignups.inc({ status: 'success', service: 'auth-service' });
    res.status(201).json(response.data);
  } catch (error) {
    // Track failed registration
    transactionMetrics.inc({ status: 'failed', type: 'registration', service: 'auth-service' });
    userSignups.inc({ status: 'failed', service: 'auth-service' });
    res.status(error.response?.status || 500).json(
      error.response?.data || { error: 'Registration failed' }
    );
  }
});

app.post('/api/auth/login', authLimiter, async (req, res) => {
  try {
    const response = await executeWithCircuitBreaker('auth-service', 'login', async () => {
      return await axios.post(`${AUTH_SERVICE}/auth/login`, req.body);
    });
    
    // Track successful login
    transactionMetrics.inc({ status: 'success', type: 'login', service: 'auth-service' });
    res.json(response.data);
  } catch (error) {
    // Track failed login
    transactionMetrics.inc({ status: 'failed', type: 'login', service: 'auth-service' });
    res.status(error.response?.status || 500).json(
      error.response?.data || { error: 'Login failed' }
    );
  }
});

app.post('/api/auth/refresh', async (req, res) => {
  try {
    const response = await axios.post(`${AUTH_SERVICE}/auth/refresh`, req.body);
    transactionMetrics.inc({ status: 'success', type: 'token_refresh', service: 'auth-service' });
    res.json(response.data);
  } catch (error) {
    transactionMetrics.inc({ status: 'failed', type: 'token_refresh', service: 'auth-service' });
    res.status(error.response?.status || 500).json(
      error.response?.data || { error: 'Token refresh failed' }
    );
  }
});

app.post('/api/auth/logout', authenticate, async (req, res) => {
  try {
    const response = await axios.post(
      `${AUTH_SERVICE}/auth/logout`,
      {},
      { headers: { Authorization: req.headers.authorization } }
    );
    transactionMetrics.inc({ status: 'success', type: 'logout', service: 'auth-service' });
    res.json(response.data);
  } catch (error) {
    transactionMetrics.inc({ status: 'failed', type: 'logout', service: 'auth-service' });
    res.status(error.response?.status || 500).json(
      error.response?.data || { error: 'Logout failed' }
    );
  }
});

app.get('/api/auth/me', authenticate, async (req, res) => {
  try {
    const response = await axios.get(
      `${AUTH_SERVICE}/auth/me`,
      { headers: { Authorization: req.headers.authorization } }
    );
    transactionMetrics.inc({ status: 'success', type: 'get_user', service: 'auth-service' });
    res.json(response.data);
  } catch (error) {
    transactionMetrics.inc({ status: 'failed', type: 'get_user', service: 'auth-service' });
    res.status(error.response?.status || 500).json(
      error.response?.data || { error: 'Failed to get user' }
    );
  }
});

// ============================================
// WALLET ROUTES (Protected)
// ============================================
app.get('/api/wallets', 
  authenticate,
  async (req, res) => {
    try {
      const response = await axios.get(`${WALLET_SERVICE}/wallets`);
      transactionMetrics.inc({ status: 'success', type: 'list_wallets', service: 'wallet-service' });
      res.json(response.data);
    } catch (error) {
      transactionMetrics.inc({ status: 'failed', type: 'list_wallets', service: 'wallet-service' });
      res.status(error.response?.status || 500).json({ error: error.message });
    }
  }
);

app.get('/api/wallets/:userId', 
  authenticate,
  validate([validators.userId]),
  authorizeOwner('userId'),
  async (req, res) => {
    try {
      const response = await axios.get(`${WALLET_SERVICE}/wallets/${req.params.userId}`);
      transactionMetrics.inc({ status: 'success', type: 'get_wallet', service: 'wallet-service' });
      res.json(response.data);
    } catch (error) {
      transactionMetrics.inc({ status: 'failed', type: 'get_wallet', service: 'wallet-service' });
      res.status(error.response?.status || 500).json({ error: error.message });
    }
  }
);

// ============================================
// TRANSACTION ROUTES (Protected)
// ============================================
app.post('/api/transactions',
  authenticate,
  transactionLimiter,
  validate(validators.createTransaction),
  authorizeOwner(), // Checks fromUserId from body
  async (req, res) => {
    try {
      // Add user context
      const transactionData = {
        ...req.body,
        initiatedBy: req.user.userId
      };

      const response = await axios.post(
        `${TRANSACTION_SERVICE}/transactions`,
        transactionData,
        { headers: { 'X-User-Id': req.user.userId } }
      );
      
      // Track successful transaction
      transactionMetrics.inc({ status: 'success', type: 'transfer', service: 'transaction-service' });
      transfers.inc({ status: 'completed', service: 'transaction-service', amount_range: 'other' });
      
      res.status(201).json(response.data);
    } catch (error) {
      // Track failed transaction
      transactionMetrics.inc({ status: 'failed', type: 'transfer', service: 'transaction-service' });
      failedTransfers.inc({ reason: error.message || 'unknown', service: 'transaction-service' });
      res.status(error.response?.status || 500).json({ error: error.message });
    }
  }
);

app.get('/api/transactions',
  authenticate,
  validate(validators.pagination),
  async (req, res) => {
    try {
      // Users can only see their own transactions unless admin
      const userId = req.user.role === 'admin' ? req.query.userId : req.user.userId;
      
      const response = await axios.get(`${TRANSACTION_SERVICE}/transactions`, {
        params: { userId, ...req.query }
      });
      transactionMetrics.inc({ status: 'success', type: 'list_transactions', service: 'transaction-service' });
      res.json(response.data);
    } catch (error) {
      transactionMetrics.inc({ status: 'failed', type: 'list_transactions', service: 'transaction-service' });
      res.status(error.response?.status || 500).json({ error: error.message });
    }
  }
);

app.get('/api/transactions/:txnId',
  authenticate,
  validate([validators.transactionId]),
  async (req, res) => {
    try {
      const response = await axios.get(`${TRANSACTION_SERVICE}/transactions/${req.params.txnId}`);
      
      // Verify user owns this transaction
      const transaction = response.data;
      if (
        transaction.from_user_id !== req.user.userId && 
        transaction.to_user_id !== req.user.userId &&
        req.user.role !== 'admin'
      ) {
        transactionMetrics.inc({ status: 'failed', type: 'get_transaction', service: 'transaction-service' });
        return res.status(403).json({ error: 'Access denied' });
      }

      transactionMetrics.inc({ status: 'success', type: 'get_transaction', service: 'transaction-service' });
      res.json(transaction);
    } catch (error) {
      transactionMetrics.inc({ status: 'failed', type: 'get_transaction', service: 'transaction-service' });
      res.status(error.response?.status || 500).json({ error: error.message });
    }
  }
);

// ============================================
// NOTIFICATION ROUTES (Protected)
// ============================================
app.get('/api/notifications/:userId',
  authenticate,
  validate([validators.userId]),
  authorizeOwner('userId'),
  async (req, res) => {
    try {
      const response = await axios.get(`${NOTIFICATION_SERVICE}/notifications/${req.params.userId}`);
      transactionMetrics.inc({ status: 'success', type: 'get_notifications', service: 'notification-service' });
      res.json(response.data);
    } catch (error) {
      transactionMetrics.inc({ status: 'failed', type: 'get_notifications', service: 'notification-service' });
      res.status(error.response?.status || 500).json({ error: error.message });
    }
  }
);

// ============================================
// ADMIN ROUTES (Admin only)
// ============================================
app.get('/api/admin/metrics',
  authenticate,
  authorizeRole('admin'),
  async (req, res) => {
    try {
      const [walletHealth, txnHealth, notifHealth, authHealth] = await Promise.all([
        axios.get(`${WALLET_SERVICE}/health`).catch(() => ({ data: { status: 'unhealthy' } })),
        axios.get(`${TRANSACTION_SERVICE}/health`).catch(() => ({ data: { status: 'unhealthy' } })),
        axios.get(`${NOTIFICATION_SERVICE}/health`).catch(() => ({ data: { status: 'unhealthy' } })),
        axios.get(`${AUTH_SERVICE}/health`).catch(() => ({ data: { status: 'unhealthy' } }))
      ]);

      res.json({
        gateway: { status: 'healthy' },
        authService: authHealth.data,
        walletService: walletHealth.data,
        transactionService: txnHealth.data,
        notificationService: notifHealth.data
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
);

// Public metrics (limited info)
app.get('/api/metrics', async (req, res) => {
  try {
    const [walletHealth, txnHealth, notifHealth] = await Promise.all([
      axios.get(`${WALLET_SERVICE}/health`).catch(() => ({ data: { status: 'unhealthy' } })),
      axios.get(`${TRANSACTION_SERVICE}/health`).catch(() => ({ data: { status: 'unhealthy' } })),
      axios.get(`${NOTIFICATION_SERVICE}/health`).catch(() => ({ data: { status: 'unhealthy' } }))
    ]);

    res.json({
      gateway: { status: 'healthy' },
      walletService: { status: walletHealth.data.status },
      transactionService: { status: txnHealth.data.status },
      notificationService: { status: notifHealth.data.status }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

app.listen(PORT, () => {
  console.log(`Secured API Gateway running on port ${PORT}`);
});

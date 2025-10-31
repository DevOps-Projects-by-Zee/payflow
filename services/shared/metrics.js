const client = require('prom-client');

// Create a Registry
const register = new client.Registry();

// Add default metrics (CPU, memory, etc.)
client.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

const httpRequestTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
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

const activeConnections = new client.Gauge({
  name: 'active_connections',
  help: 'Number of active connections',
  labelNames: ['service', 'type']
});

const databaseQueryDuration = new client.Histogram({
  name: 'database_query_duration_seconds',
  help: 'Database query duration',
  labelNames: ['query_type'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2]
});

const cacheHitRate = new client.Counter({
  name: 'cache_hits_total',
  help: 'Total cache hits',
  labelNames: ['cache_type', 'hit']
});

// Register custom metrics
register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestTotal);
register.registerMetric(transactionTotal);
register.registerMetric(transactionDuration);
register.registerMetric(queueDepth);
register.registerMetric(activeConnections);
register.registerMetric(databaseQueryDuration);
register.registerMetric(cacheHitRate);

// Middleware for HTTP metrics
function metricsMiddleware(req, res, next) {
  const start = Date.now();

  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route?.path || req.path;

    httpRequestDuration
      .labels(req.method, route, res.statusCode)
      .observe(duration);

    httpRequestTotal
      .labels(req.method, route, res.statusCode)
      .inc();
  });

  next();
}

// Metrics endpoint handler
async function metricsHandler(req, res) {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
}

module.exports = {
  register,
  httpRequestDuration,
  httpRequestTotal,
  transactionTotal,
  transactionDuration,
  queueDepth,
  activeConnections,
  databaseQueryDuration,
  cacheHitRate,
  metricsMiddleware,
  metricsHandler
};

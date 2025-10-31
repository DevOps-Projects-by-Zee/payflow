const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'PayFlow API',
      version: '1.0.0',
      description: 'Production-ready fintech microservices platform',
      contact: {
        name: 'PayFlow Support',
        email: 'support@payflow.com'
      },
      license: {
        name: 'MIT',
        url: 'https://opensource.org/licenses/MIT'
      }
    },
    servers: [
      {
        url: 'http://localhost:3000',
        description: 'Development server'
      },
      {
        url: 'https://api.payflow.com',
        description: 'Production server'
      }
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT'
        }
      },
      schemas: {
        User: {
          type: 'object',
          properties: {
            id: { type: 'string', example: 'user-001' },
            email: { type: 'string', format: 'email', example: 'user@example.com' },
            name: { type: 'string', example: 'John Doe' },
            role: { type: 'string', enum: ['user', 'admin'], example: 'user' }
          }
        },
        Wallet: {
          type: 'object',
          properties: {
            user_id: { type: 'string', example: 'user-001' },
            name: { type: 'string', example: 'John Doe' },
            balance: { type: 'number', format: 'decimal', example: 5000.00 },
            currency: { type: 'string', example: 'USD' },
            created_at: { type: 'string', format: 'date-time' }
          }
        },
        Transaction: {
          type: 'object',
          properties: {
            id: { type: 'string', example: 'TXN-123456' },
            from_user_id: { type: 'string', example: 'user-001' },
            to_user_id: { type: 'string', example: 'user-002' },
            amount: { type: 'number', format: 'decimal', example: 100.00 },
            status: { 
              type: 'string', 
              enum: ['PENDING', 'PROCESSING', 'COMPLETED', 'FAILED'],
              example: 'COMPLETED'
            },
            created_at: { type: 'string', format: 'date-time' }
          }
        },
        Error: {
          type: 'object',
          properties: {
            error: { type: 'string', example: 'Error message' },
            details: { type: 'array', items: { type: 'object' } }
          }
        }
      }
    },
    tags: [
      { name: 'Authentication', description: 'User authentication endpoints' },
      { name: 'Wallets', description: 'Wallet management endpoints' },
      { name: 'Transactions', description: 'Transaction processing endpoints' },
      { name: 'Notifications', description: 'Notification management endpoints' }
    ]
  },
  apis: ['./routes/*.js', './server.js']
};

const swaggerSpec = swaggerJsdoc(options);

function setupSwagger(app) {
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'PayFlow API Documentation'
  }));

  // Serve OpenAPI JSON
  app.get('/api-docs.json', (req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.send(swaggerSpec);
  });
}

module.exports = { setupSwagger };

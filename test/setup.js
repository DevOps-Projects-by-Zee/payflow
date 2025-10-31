// Global test setup
const { Pool } = require('pg');

// Setup test database connection
global.testPool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'payflow_test',
  user: process.env.DB_USER || 'payflow',
  password: process.env.DB_PASSWORD || 'payflow123'
});

// Global test cleanup
afterAll(async () => {
  if (global.testPool) {
    await global.testPool.end();
  }
});

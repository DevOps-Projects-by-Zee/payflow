const request = require('supertest');
const app = require('../server');
const { Pool } = require('pg');

describe('Transaction Service', () => {
  let pool;

  beforeAll(async () => {
    pool = new Pool({
      host: 'localhost',
      database: 'payflow_test',
      user: 'payflow',
      password: 'payflow123'
    });
  });

  afterAll(async () => {
    await pool.end();
  });

  beforeEach(async () => {
    // Clean database
    await pool.query('TRUNCATE transactions CASCADE');
  });

  describe('POST /transactions', () => {
    it('should create a new transaction', async () => {
      const response = await request(app)
        .post('/transactions')
        .send({
          fromUserId: 'user-001',
          toUserId: 'user-002',
          amount: 100.00
        })
        .expect(201);

      expect(response.body).toHaveProperty('id');
      expect(response.body.status).toBe('PENDING');
    });

    it('should reject invalid amount', async () => {
      await request(app)
        .post('/transactions')
        .send({
          fromUserId: 'user-001',
          toUserId: 'user-002',
          amount: -50
        })
        .expect(400);
    });

    it('should handle idempotency', async () => {
      const idempotencyKey = 'test-key-123';

      const response1 = await request(app)
        .post('/transactions')
        .set('Idempotency-Key', idempotencyKey)
        .send({
          fromUserId: 'user-001',
          toUserId: 'user-002',
          amount: 100.00
        })
        .expect(201);

      const response2 = await request(app)
        .post('/transactions')
        .set('Idempotency-Key', idempotencyKey)
        .send({
          fromUserId: 'user-001',
          toUserId: 'user-002',
          amount: 100.00
        })
        .expect(201);

      expect(response1.body.id).toBe(response2.body.id);
      expect(response2.headers['x-idempotent-replay']).toBe('true');
    });
  });

  describe('GET /transactions/:txnId', () => {
    it('should retrieve a transaction by ID', async () => {
      // Create transaction
      const createRes = await request(app)
        .post('/transactions')
        .send({
          fromUserId: 'user-001',
          toUserId: 'user-002',
          amount: 50.00
        });

      const txnId = createRes.body.id;

      // Retrieve transaction
      const response = await request(app)
        .get(`/transactions/${txnId}`)
        .expect(200);

      expect(response.body.id).toBe(txnId);
      expect(response.body.amount).toBe('50.00');
    });

    it('should return 404 for non-existent transaction', async () => {
      await request(app)
        .get('/transactions/invalid-id')
        .expect(404);
    });
  });
});

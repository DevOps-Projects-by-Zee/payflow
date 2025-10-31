const { body, param, query, validationResult } = require('express-validator');

// Validation middleware wrapper
function validate(validations) {
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
}

// Common validations
const validators = {
  userId: param('userId').isString().trim().notEmpty(),
  transactionId: param('txnId').isString().trim().notEmpty(),
  
  createTransaction: [
    body('fromUserId').isString().trim().notEmpty(),
    body('toUserId').isString().trim().notEmpty(),
    body('amount').isFloat({ min: 0.01, max: 1000000 }).toFloat()
  ],

  pagination: [
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt()
  ]
};

module.exports = { validate, validators };

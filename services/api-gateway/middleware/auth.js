const axios = require('axios');

const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL || 'http://auth-service:3004';

// Authentication middleware
async function authenticate(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  try {
    const response = await axios.post(
      `${AUTH_SERVICE_URL}/auth/verify`,
      {},
      { headers: { Authorization: `Bearer ${token}` } }
    );

    if (response.data.valid) {
      req.user = {
        userId: response.data.userId,
        email: response.data.email,
        role: response.data.role
      };
      next();
    } else {
      res.status(401).json({ error: 'Invalid token' });
    }
  } catch (error) {
    res.status(401).json({ error: 'Authentication failed' });
  }
}

// Authorization middleware - check if user owns the resource
function authorizeOwner(resourceIdParam = 'userId') {
  return (req, res, next) => {
    const resourceId = req.params[resourceIdParam] || req.body.fromUserId;
    
    if (req.user.userId !== resourceId && req.user.role !== 'admin') {
      return res.status(403).json({ 
        error: 'Access denied - you can only access your own resources' 
      });
    }
    
    next();
  };
}

// Role-based authorization
function authorizeRole(...roles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ 
        error: `Access denied - requires one of: ${roles.join(', ')}` 
      });
    }

    next();
  };
}

module.exports = { authenticate, authorizeOwner, authorizeRole };

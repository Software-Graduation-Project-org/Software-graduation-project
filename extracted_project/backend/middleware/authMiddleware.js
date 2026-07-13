const jwt = require('jsonwebtoken');

const authMiddleware = async (req, res, next) => {
  try {    // Get token from header
    const token = req.header('Authorization')?.replace('Bearer ', '');
    if (!token) {      return res.status(401).json({ message: 'No authentication token, access denied' });
    }

    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);    
    // Attach user info to request
    req.user = decoded;
    req.user._id = decoded._id || decoded.id; // Normalize _id for consistency

    next();
  } catch (error) {    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ message: 'Token has expired' });
    }
    res.status(401).json({ message: 'Token is not valid' });
  }
};

module.exports = authMiddleware;

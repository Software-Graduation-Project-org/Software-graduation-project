const rateLimit = require('express-rate-limit');

// Rate limiter for login attempts
const loginLimiter = rateLimit({
  windowMs:3 * 60 * 1000, // 3 minutes
  max: 5, // Limit each IP to 5 login requests per windowMs
  message: {
    message: '🚫 Too many login attempts from this IP, please try again after 3 minutes'
  },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
});

// General API rate limiter
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: {
    message: '🚫 Too many requests from this IP, please try again later'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Rate limiter for result uploads (stricter)
const resultUploadLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 10, // Limit to 10 result uploads per minute
  message: {
    message: '🚫 Too many result uploads. Please wait a moment before uploading more results.'
  },
  standardHeaders: true,
  legacyHeaders: false
});

// Rate limiter for sample collection
const sampleCollectionLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 20, // Allow 20 sample collections per minute (higher than results)
  message: {
    message: '🚫 Too many sample collections. Please slow down.'
  },
  standardHeaders: true,
  legacyHeaders: false
});

module.exports = {
  loginLimiter,
  apiLimiter,
  resultUploadLimiter,
  sampleCollectionLimiter
};

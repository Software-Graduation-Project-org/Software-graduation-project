const { body, param, query } = require('express-validator');

// Login Validation
exports.validateLogin = [
  body('username')
    .trim()
    .notEmpty().withMessage('Username is required')
    .isLength({ min: 3, max: 100 }).withMessage('Username must be 3-100 characters')
    .matches(/^[a-zA-Z0-9._@-]+$/).withMessage('Username contains invalid characters'),
  
  body('password')
    .notEmpty().withMessage('Password is required')
    .isLength({ min: 6, max: 100 }).withMessage('Password must be 6-100 characters')
];

// Request Test for Patient Validation
exports.validateRequestTest = [
  body('patient_id')
    .trim()
    .notEmpty().withMessage('Patient ID is required')
    .isMongoId().withMessage('Invalid patient ID format'),
  
  body('owner_id')
    .trim()
    .notEmpty().withMessage('Lab ID is required')
    .isMongoId().withMessage('Invalid lab ID format'),
  
  body('test_ids')
    .isArray({ min: 1 }).withMessage('At least one test is required'),
  
  body('test_ids.*')
    .isMongoId().withMessage('Invalid test ID format'),
  
  body('remarks')
    .optional()
    .trim()
    .isLength({ max: 500 }).withMessage('Remarks must not exceed 500 characters')
];

// Get Patient Test History Validation
exports.validatePatientId = [
  param('patient_id')
    .trim()
    .isMongoId().withMessage('Invalid patient ID format')
];

// Search Patients Validation
exports.validateSearchPatients = [
  query('query')
    .trim()
    .notEmpty().withMessage('Search query is required')
    .isLength({ min: 2, max: 100 }).withMessage('Search query must be 2-100 characters')
];

// Get Lab Tests Validation
exports.validateLabId = [
  param('lab_id')
    .trim()
    .isMongoId().withMessage('Invalid lab ID format')
];

// Feedback Validation
exports.validateFeedback = [
  body('target_id')
    .optional()
    .trim()
    .isMongoId().withMessage('Invalid target ID format'),
  
  body('target_model')
    .trim()
    .notEmpty().withMessage('Target model is required')
    .isIn(['Owner', 'Test', 'Order', 'Service', 'System']).withMessage('Invalid target model'),
  
  body('rating')
    .isInt({ min: 1, max: 5 }).withMessage('Rating must be between 1 and 5'),
  
  body('title')
    .trim()
    .notEmpty().withMessage('Feedback title is required')
    .isLength({ min: 5, max: 100 }).withMessage('Title must be 5-100 characters'),
  
  body('message')
    .trim()
    .notEmpty().withMessage('Feedback message is required')
    .isLength({ min: 10, max: 1000 }).withMessage('Message must be 10-1000 characters'),
  
  body('is_anonymous')
    .optional()
    .isBoolean().withMessage('is_anonymous must be true or false')
];

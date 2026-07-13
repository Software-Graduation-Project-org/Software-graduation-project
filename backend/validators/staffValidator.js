const { body, param } = require('express-validator');

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

// Upload Result Validation
exports.validateUploadResult = [
  body('detail_id')
    .trim()
    .notEmpty().withMessage('Detail ID is required')
    .isMongoId().withMessage('Invalid detail ID format'),

  // result_value is required only for tests without components
  body('result_value')
    .optional()
    .trim()
    .isLength({ max: 500 }).withMessage('Result value too long'),

  // components is required for tests with components
  body('components')
    .optional()
    .isArray().withMessage('Components must be an array'),

  body('components.*.component_id')
    .optional()
    .isMongoId().withMessage('Invalid component ID format'),

  body('components.*.component_value')
    .optional()
    .trim()
    .notEmpty().withMessage('Component value cannot be empty'),

  body('remarks')
    .optional()
    .trim()
    .isLength({ max: 500 }).withMessage('Remarks too long'),

  // Custom validation: either result_value OR components must be provided
  body().custom((value, { req }) => {
    const { result_value, components } = req.body;

    if (!result_value && (!components || !Array.isArray(components) || components.length === 0)) {
      throw new Error('Either result_value or components must be provided');
    }

    if (result_value && components && components.length > 0) {
      throw new Error('Cannot provide both result_value and components');
    }

    return true;
  })
];

// Collect Sample Validation
exports.validateCollectSample = [
  body('detail_id')
    .trim()
    .notEmpty().withMessage('Detail ID is required')
    .isMongoId().withMessage('Invalid detail ID format'),
  
  body('sample_collection_date')
    .optional()
    .isISO8601().withMessage('Invalid date format')
];

// Update Sample Status Validation
exports.validateUpdateSampleStatus = [
  body('detail_id')
    .trim()
    .notEmpty().withMessage('Detail ID is required')
    .isMongoId().withMessage('Invalid detail ID format'),
  
  body('status')
    .trim()
    .notEmpty().withMessage('Status is required')
    .isIn(['pending', 'collected', 'in_progress', 'completed'])
    .withMessage('Invalid status value')
];

// Register Patient from Order Validation
exports.validateRegisterPatient = [
  body('order_id')
    .trim()
    .notEmpty().withMessage('Order ID is required')
    .isMongoId().withMessage('Invalid order ID format')
];

// Assign Staff Validation
exports.validateAssignStaff = [
  body('detail_id')
    .trim()
    .notEmpty().withMessage('Detail ID is required')
    .isMongoId().withMessage('Invalid detail ID format'),
  
  body('staff_id')
    .trim()
    .notEmpty().withMessage('Staff ID is required')
    .isMongoId().withMessage('Invalid staff ID format')
];

// Get Order Details Validation
exports.validateOrderId = [
  param('order_id')
    .trim()
    .isMongoId().withMessage('Invalid order ID format')
];

// Feedback Validation
exports.validateFeedback = [
  body('target_type')
    .trim()
    .notEmpty().withMessage('Target type is required')
    .isIn(['lab', 'test', 'order', 'system']).withMessage('Target type must be lab, test, order, or system'),

  body('target_id')
    .optional()
    .trim()
    .if(body('target_type').not().equals('system'))
    .notEmpty().withMessage('Target ID is required for non-system feedback')
    .isMongoId().withMessage('Invalid target ID format'),

  body('rating')
    .isInt({ min: 1, max: 5 }).withMessage('Rating must be between 1 and 5'),

  body('message')
    .optional()
    .trim()
    .isLength({ max: 1000 }).withMessage('Message must not exceed 1000 characters'),

  body('is_anonymous')
    .optional()
    .isBoolean().withMessage('is_anonymous must be true or false')
];

// Assign Test to Me Validation
exports.validateAssignTestToMe = [
  body('detail_id')
    .trim()
    .notEmpty().withMessage('Detail ID is required')
    .isMongoId().withMessage('Invalid detail ID format')
];

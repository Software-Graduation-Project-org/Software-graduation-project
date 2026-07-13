const { body } = require('express-validator');

// Office Hours Validation
exports.validateOfficeHours = [
  body('office_hours')
    .optional()
    .isArray().withMessage('Office hours must be an array'),
  body('office_hours.*.day')
    .optional()
    .isIn(['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'])
    .withMessage('Day must be a valid weekday'),
  body('office_hours.*.open_time')
    .optional()
    .matches(/^([01]?[0-9]|2[0-3]):[0-5][0-9]$/)
    .withMessage('Open time must be in HH:MM format (24-hour)'),
  body('office_hours.*.close_time')
    .optional()
    .matches(/^([01]?[0-9]|2[0-3]):[0-5][0-9]$/)
    .withMessage('Close time must be in HH:MM format (24-hour)'),
  body('office_hours.*.is_closed')
    .optional()
    .isBoolean().withMessage('is_closed must be true or false')
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
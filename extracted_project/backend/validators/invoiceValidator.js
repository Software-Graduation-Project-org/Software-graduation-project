const { body, param } = require('express-validator');

// Record Payment Validation
exports.validateRecordPayment = [
  body('invoice_id')
    .trim()
    .notEmpty().withMessage('Invoice ID is required')
    .isMongoId().withMessage('Invalid invoice ID format'),
  
  body('payment_method')
    .trim()
    .notEmpty().withMessage('Payment method is required')
    .isIn(['cash', 'card', 'bank_transfer']).withMessage('Invalid payment method'),
  
  body('amount_paid')
    .notEmpty().withMessage('Amount is required')
    .isFloat({ min: 0.01 }).withMessage('Amount must be greater than 0'),
  
  body('remarks')
    .optional()
    .trim()
    .isLength({ max: 500 }).withMessage('Remarks too long')
];

// Get Invoice Validation
exports.validateInvoiceId = [
  param('invoice_id')
    .trim()
    .isMongoId().withMessage('Invalid invoice ID format')
];

// Apply Discount Validation
exports.validateApplyDiscount = [
  param('invoiceId')
    .trim()
    .isMongoId().withMessage('Invalid invoice ID format'),
  
  body('discount')
    .notEmpty().withMessage('Discount amount is required')
    .isFloat({ min: 0 }).withMessage('Discount must be 0 or greater')
];

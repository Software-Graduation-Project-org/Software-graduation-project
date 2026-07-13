const express = require('express');
const router = express.Router();
const invoiceController = require('../controllers/invoiceController');
const authMiddleware = require('../middleware/authMiddleware');
const roleMiddleware = require('../middleware/roleMiddleware');
const { validateRequest } = require('../middleware/validationMiddleware');
const invoiceValidator = require('../validators/invoiceValidator');

/**
 * @route   POST /api/invoice/record-payment
 * @desc    Record payment for an invoice (cash/card at lab)
 * @access  Private (Staff/Owner)
 */
router.post(
  '/record-payment',
  authMiddleware,
  roleMiddleware(['Staff', 'Owner']),
  ...invoiceValidator.validateRecordPayment,
  validateRequest,
  invoiceController.recordPayment
);

/**
 * @route   GET /api/invoice/:invoice_id
 * @desc    Get invoice details with tests and patient info
 * @access  Private (Staff/Owner/Patient)
 */
router.get(
  '/:invoice_id',
  authMiddleware,
  roleMiddleware(['Staff', 'Owner', 'Patient']),
  ...invoiceValidator.validateInvoiceId,
  validateRequest,
  invoiceController.getInvoice
);

/**
 * @route   GET /api/invoice/unpaid
 * @desc    Get all unpaid invoices for the lab
 * @access  Private (Owner/Staff)
 */
router.get(
  '/list/unpaid',
  authMiddleware,
  roleMiddleware(['Owner', 'Staff']),
  invoiceController.getUnpaidInvoices
);

/**
 * @route   POST /api/invoice/discount/:invoiceId
 * @desc    Apply discount to an invoice
 * @access  Private (Owner)
 */
router.post(
  '/discount/:invoiceId',
  authMiddleware,
  roleMiddleware(['Owner']),
  ...invoiceValidator.validateApplyDiscount,
  validateRequest,
  invoiceController.applyDiscount
);

/**
 * @route   POST /api/invoice/send-report/:invoiceId
 * @desc    Send invoice report to patient via email and WhatsApp
 * @access  Private (Staff/Owner)
 */
router.post(
  '/send-report/:invoiceId',
  authMiddleware,
  roleMiddleware(['Staff', 'Owner']),
  invoiceController.sendInvoiceReport
);

module.exports = router;

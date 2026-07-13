const express = require('express');
const router = express.Router();
const patientController = require('../controllers/patientController');
const authMiddleware = require('../middleware/authMiddleware');
const roleMiddleware = require('../middleware/roleMiddleware');
const { loginLimiter } = require('../middleware/rateLimitMiddleware');
const { validateRequest } = require('../middleware/validationMiddleware');
const patientValidator = require('../validators/patientValidator');

// ==================== AUTHENTICATION ROUTES ====================

/**
 * @route   POST /api/patient/login
 * @desc    Patient login
 * @access  Public
 */
router.post('/login', 
  loginLimiter, 
  ...patientValidator.validateLogin, 
  validateRequest, 
  patientController.login
);

/**
 * @route   GET /api/patient/profile
 * @desc    Get patient profile
 * @access  Private (Patient)
 */
router.get('/profile', authMiddleware, roleMiddleware(['patient']), patientController.getProfile);

/**
 * @route   PUT /api/patient/profile
 * @desc    Update patient profile
 * @access  Private (Patient)
 */
router.put('/profile', authMiddleware, roleMiddleware(['patient']), patientController.updateProfile);

/**
 * @route   PUT /api/patient/change-password
 * @desc    Change password
 * @access  Private (Patient)
 */
router.put('/change-password', 
  authMiddleware, 
  roleMiddleware(['patient']), 
  ...patientValidator.validateChangePassword, 
  validateRequest, 
  patientController.changePassword
);

// ==================== TEST ORDER ROUTES ====================

/**
 * @route   GET /api/patient/orders
 * @desc    Get all patient orders
 * @access  Private (Patient)
 */
router.get('/orders', 
  authMiddleware, 
  roleMiddleware(['patient']), 
  ...patientValidator.validateGetOrders, 
  validateRequest, 
  patientController.getMyOrders
);

/**
 * @route   GET /api/patient/orders/:orderId
 * @desc    Get single order details
 * @access  Private (Patient)
 */
router.get('/orders/:orderId', 
  authMiddleware, 
  roleMiddleware(['patient']), 
  ...patientValidator.validateOrderId, 
  validateRequest, 
  patientController.getOrderById
);

/**
 * @route   POST /api/patient/request-tests
 * @desc    Request new tests (self-request)
 * @access  Private (Patient)
 */
router.post('/request-tests', 
  authMiddleware, 
  roleMiddleware(['patient']), 
  ...patientValidator.validateRequestTests, 
  validateRequest, 
  patientController.requestTests
);

// ==================== TEST RESULTS ROUTES ====================

/**
 * @route   GET /api/patient/orders-with-results
 * @desc    Get order summaries with result counts
 * @access  Private (Patient)
 */
router.get('/orders-with-results', authMiddleware, roleMiddleware(['patient']), patientController.getOrdersWithResults);

/**
 * @route   GET /api/patient/orders/:orderId/results
 * @desc    Get all results for specific order
 * @access  Private (Patient)
 */
router.get('/orders/:orderId/results', authMiddleware, roleMiddleware(['patient']), patientController.getOrderResults);

/**
 * @route   GET /api/patient/results
 * @desc    Get all test results
 * @access  Private (Patient)
 */
router.get('/results', authMiddleware, roleMiddleware(['patient']), patientController.getMyResults);

/**
 * @route   GET /api/patient/results/:detailId
 * @desc    Get result for specific test
 * @access  Private (Patient)
 */
router.get('/results/:detailId', authMiddleware, roleMiddleware(['patient']), patientController.getResultById);

/**
 * @route   GET /api/patient/results/:detailId/download
 * @desc    Download result
 * @access  Private (Patient)
 */
router.get('/results/:detailId/download', authMiddleware, roleMiddleware(['patient']), patientController.downloadResult);

// ==================== MEDICAL HISTORY ROUTES ====================

/**
 * @route   GET /api/patient/history
 * @desc    Get medical test history
 * @access  Private (Patient)
 */
router.get('/history', authMiddleware, roleMiddleware(['patient']), patientController.getTestHistory);

// ==================== NOTIFICATION ROUTES ====================

/**
 * @route   GET /api/patient/notifications
 * @desc    Get all notifications
 * @access  Private (Patient)
 */
router.get('/notifications', authMiddleware, roleMiddleware(['patient']), patientController.getNotifications);

/**
 * @route   PUT /api/patient/notifications/:notificationId/read
 * @desc    Mark notification as read
 * @access  Private (Patient)
 */
router.put('/notifications/:notificationId/read', 
  authMiddleware, 
  roleMiddleware(['patient']), 
  ...patientValidator.validateNotificationId, 
  validateRequest, 
  patientController.markNotificationAsRead
);

// ==================== INVOICE ROUTES ====================

/**
 * @route   GET /api/patient/invoices
 * @desc    Get all invoices
 * @access  Private (Patient)
 */
router.get('/invoices', 
  authMiddleware, 
  roleMiddleware(['patient']), 
  patientController.getMyInvoices
);

/**
 * @route   GET /api/patient/invoices/:invoiceId
 * @desc    Get single invoice
 * @access  Private (Patient)
 */
router.get('/invoices/:invoiceId', 
  authMiddleware, 
  roleMiddleware(['patient']), 
  ...patientValidator.validateInvoiceId, 
  validateRequest, 
  patientController.getInvoiceById
);
/**
 * @route   POST /api/patient/invoices/:invoiceId/send-report
 * @desc    Request invoice report via email and WhatsApp
 * @access  Private (Patient)
 */
router.post('/invoices/:invoiceId/send-report', 
  authMiddleware, 
  roleMiddleware(['patient']), 
  ...patientValidator.validateInvoiceId, 
  validateRequest, 
  patientController.requestInvoiceReport
);

/**
 * @route   GET /api/patient/invoices/:invoiceId/download
 * @desc    Download invoice as PDF
 * @access  Private (Patient)
 */
router.get('/invoices/:invoiceId/download', 
  authMiddleware, 
  roleMiddleware(['patient']), 
  ...patientValidator.validateInvoiceId, 
  validateRequest, 
  patientController.downloadInvoicePDF
);

// ==================== LABS & TESTS & DOCTORS ROUTES ====================

/**
 * @route   GET /api/patient/doctors
 * @desc    Get available doctors (for linking to test orders)
 * @access  Private (Patient)
 */
router.get('/doctors', 
  authMiddleware, 
  roleMiddleware(['patient']), 
  ...patientValidator.validateSearchDoctors, 
  validateRequest, 
  patientController.getAvailableDoctors
);

/**
 * @route   GET /api/patient/labs
 * @desc    Get available labs
 * @access  Private (Patient)
 */
router.get('/labs', 
  authMiddleware, 
  roleMiddleware(['patient']), 
  patientController.getAvailableLabs
);

/**
 * @route   GET /api/patient/labs/:labId/tests
 * @desc    Get available tests for a lab
 * @access  Private (Patient)
 */
router.get('/labs/:labId/tests', 
  authMiddleware, 
  roleMiddleware(['patient']), 
  ...patientValidator.validateLabId, 
  validateRequest, 
  patientController.getLabTests
);

// ==================== FEEDBACK ROUTES ====================

/**
 * @route   POST /api/patient/feedback
 * @desc    Provide feedback on lab, test, or order
 * @access  Private (Patient)
 */
router.post('/feedback', 
  authMiddleware, 
  roleMiddleware(['patient']), 
  ...patientValidator.validateFeedback, 
  validateRequest, 
  patientController.provideFeedback
);

/**
 * @route   GET /api/patient/feedback
 * @desc    Get my feedback history
 * @access  Private (Patient)
 */
router.get('/feedback', 
  authMiddleware, 
  roleMiddleware(['patient']), 
  patientController.getMyFeedback
);

// ==================== DASHBOARD ROUTE ====================

/**
 * @route   GET /api/patient/dashboard
 * @desc    Get patient dashboard
 * @access  Private (Patient)
 */
router.get('/dashboard', authMiddleware, roleMiddleware(['patient']), patientController.getDashboard);

module.exports = router;


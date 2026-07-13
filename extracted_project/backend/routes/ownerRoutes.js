const express = require('express');
const router = express.Router();
const ownerController = require('../controllers/ownerController');
const authMiddleware = require('../middleware/authMiddleware');
const roleMiddleware = require('../middleware/roleMiddleware');
const ownerValidator = require('../validators/ownerValidator');
const { validateRequest } = require('../middleware/validationMiddleware');
// ==================== AUTHENTICATION ROUTES ====================

/**
 * @route   POST /api/owner/login
 * @desc    Lab Owner login
 * @access  Public
 */
router.post('/login', ownerController.login);

// Lab Owner Request Access
// POST /api/owner/request-access
router.post('/request-access', ownerController.requestAccess);



/**
 * @route   GET /api/owner/profile
 * @desc    Get owner profile
 * @access  Private (Owner)
 */
router.get('/profile', authMiddleware, roleMiddleware(['owner']), ownerController.getProfile);

/**
 * @route   PUT /api/owner/profile
 * @desc    Update owner profile
 * @access  Private (Owner)
 */
router.put('/profile', authMiddleware, roleMiddleware(['owner']), ownerValidator.validateOfficeHours, validateRequest, ownerController.updateProfile);

/**
 * @route   PUT /api/owner/change-password
 * @desc    Change password
 * @access  Private (Owner)
 */
router.put('/change-password', authMiddleware, roleMiddleware(['owner']), ownerController.changePassword);

// ==================== STAFF MANAGEMENT ROUTES ====================

/**
 * @route   GET /api/owner/staff
 * @desc    Get all staff members
 * @access  Private (Owner)
 */
router.get('/staff', authMiddleware, roleMiddleware(['owner']), ownerController.getAllStaff);

/**
 * @route   GET /api/owner/staff/:staffId
 * @desc    Get single staff member
 * @access  Private (Owner)
 */
router.get('/staff/:staffId', authMiddleware, roleMiddleware(['owner']), ownerController.getStaffById);

/**
 * @route   POST /api/owner/staff
 * @desc    Add new staff member
 * @access  Private (Owner)
 */
router.post('/staff', authMiddleware, roleMiddleware(['owner']), ownerController.addStaff);

/**
 * @route   PUT /api/owner/staff/:staffId
 * @desc    Update staff member
 * @access  Private (Owner)
 */
router.put('/staff/:staffId', authMiddleware, roleMiddleware(['owner']), ownerController.updateStaff);

/**
 * @route   DELETE /api/owner/staff/:staffId
 * @desc    Delete staff member
 * @access  Private (Owner)
 */
router.delete('/staff/:staffId', authMiddleware, roleMiddleware(['owner']), ownerController.deleteStaff);

// ==================== DOCTOR MANAGEMENT ROUTES ====================

/**
 * @route   GET /api/owner/doctors
 * @desc    Get all doctors
 * @access  Private (Owner)
 */
router.get('/doctors', authMiddleware, roleMiddleware(['owner']), ownerController.getAllDoctors);

/**
 * @route   GET /api/owner/doctors/:doctorId
 * @desc    Get single doctor
 * @access  Private (Owner)
 */
router.get('/doctors/:doctorId', authMiddleware, roleMiddleware(['owner']), ownerController.getDoctorById);

/**
 * @route   POST /api/owner/doctors
 * @desc    Add new doctor
 * @access  Private (Owner)
 */
router.post('/doctors', authMiddleware, roleMiddleware(['owner']), ownerController.addDoctor);

/**
 * @route   PUT /api/owner/doctors/:doctorId
 * @desc    Update doctor
 * @access  Private (Owner)
 */
router.put('/doctors/:doctorId', authMiddleware, roleMiddleware(['owner']), ownerController.updateDoctor);

/**
 * @route   DELETE /api/owner/doctors/:doctorId
 * @desc    Delete doctor
 * @access  Private (Owner)
 */
router.delete('/doctors/:doctorId', authMiddleware, roleMiddleware(['owner']), ownerController.deleteDoctor);

// ==================== DEVICE MANAGEMENT ROUTES ====================

/**
 * @route   GET /api/owner/devices
 * @desc    Get all devices
 * @access  Private (Owner)
 */
router.get('/devices', authMiddleware, roleMiddleware(['owner']), ownerController.getAllDevices);

/**
 * @route   GET /api/owner/devices/:deviceId
 * @desc    Get single device
 * @access  Private (Owner)
 */
router.get('/devices/:deviceId', authMiddleware, roleMiddleware(['owner']), ownerController.getDeviceById);

/**
 * @route   POST /api/owner/devices
 * @desc    Add new device
 * @access  Private (Owner)
 */
router.post('/devices', authMiddleware, roleMiddleware(['owner']), ownerController.addDevice);

/**
 * @route   PUT /api/owner/devices/:deviceId
 * @desc    Update device
 * @access  Private (Owner)
 */
router.put('/devices/:deviceId', authMiddleware, roleMiddleware(['owner']), ownerController.updateDevice);

/**
 * @route   DELETE /api/owner/devices/:deviceId
 * @desc    Delete device
 * @access  Private (Owner)
 */
router.delete('/devices/:deviceId', authMiddleware, roleMiddleware(['owner']), ownerController.deleteDevice);

/**
 * @route   POST /api/owner/assign-staff-to-device
 * @desc    Assign or unassign staff to a device
 * @access  Private (Owner)
 */
router.post('/assign-staff-to-device', authMiddleware, roleMiddleware(['owner']), ownerController.assignStaffToDevice);

// ==================== TEST MANAGEMENT ROUTES ====================

/**
 * @route   GET /api/owner/tests
 * @desc    Get all tests
 * @access  Private (Owner)
 */
router.get('/tests', authMiddleware, roleMiddleware(['owner']), ownerController.getAllTests);

/**
 * @route   GET /api/owner/tests/:testId
 * @desc    Get single test
 * @access  Private (Owner)
 */
router.get('/tests/:testId', authMiddleware, roleMiddleware(['owner']), ownerController.getTestById);

/**
 * @route   POST /api/owner/tests
 * @desc    Add new test
 * @access  Private (Owner)
 */
router.post('/tests', authMiddleware, roleMiddleware(['owner']), ownerController.addTest);

/**
 * @route   PUT /api/owner/tests/:testId
 * @desc    Update test
 * @access  Private (Owner)
 */
router.put('/tests/:testId', authMiddleware, roleMiddleware(['owner']), ownerController.updateTest);

/**
 * @route   DELETE /api/owner/tests/:testId
 * @desc    Delete test
 * @access  Private (Owner)
 */
router.delete('/tests/:testId', authMiddleware, roleMiddleware(['owner']), ownerController.deleteTest);

// ==================== INVENTORY MANAGEMENT ROUTES ====================

/**
 * @route   GET /api/owner/inventory
 * @desc    Get all inventory items
 * @access  Private (Owner)
 */
router.get('/inventory', authMiddleware, roleMiddleware(['owner']), ownerController.getAllInventory);

/**
 * @route   GET /api/owner/inventory/:itemId
 * @desc    Get single inventory item with transaction history
 * @access  Private (Owner)
 */
router.get('/inventory/:itemId', authMiddleware, roleMiddleware(['owner']), ownerController.getInventoryById);

/**
 * @route   POST /api/owner/inventory
 * @desc    Add inventory item
 * @access  Private (Owner)
 */
router.post('/inventory', authMiddleware, roleMiddleware(['owner']), ownerController.addInventoryItem);

/**
 * @route   PUT /api/owner/inventory/:itemId
 * @desc    Update inventory item
 * @access  Private (Owner)
 */
router.put('/inventory/:itemId', authMiddleware, roleMiddleware(['owner']), ownerController.updateInventoryItem);

/**
 * @route   DELETE /api/owner/inventory/:itemId
 * @desc    Delete inventory item
 * @access  Private (Owner)
 */
router.delete('/inventory/:itemId', authMiddleware, roleMiddleware(['owner']), ownerController.deleteInventoryItem);

/**
 * @route   POST /api/owner/inventory/input
 * @desc    Add stock input to inventory item
 * @access  Private (Owner)
 */
router.post('/inventory/input', authMiddleware, roleMiddleware(['owner']), ownerController.addStockInput);

// ==================== ORDER MANAGEMENT ROUTES ====================

/**
 * @route   GET /api/owner/orders
 * @desc    Get all orders for this lab
 * @access  Private (Owner)
 */
router.get('/orders', authMiddleware, roleMiddleware(['owner']), ownerController.getAllOrders);

/**
 * @route   GET /api/owner/orders/:orderId
 * @desc    Get single order details
 * @access  Private (Owner)
 */
router.get('/orders/:orderId', authMiddleware, roleMiddleware(['owner']), ownerController.getOrderById);

// ==================== DASHBOARD & ANALYTICS ROUTES ====================

/**
 * @route   GET /api/owner/dashboard
 * @desc    Get dashboard statistics
 * @access  Private (Owner)
 */
router.get('/dashboard', authMiddleware, roleMiddleware(['owner']), ownerController.getDashboard);

/**
 * @route   GET /api/owner/reports
 * @desc    Get performance reports
 * @access  Private (Owner)
 */
router.get('/reports', authMiddleware, roleMiddleware(['owner']), ownerController.getReports);

// ==================== NOTIFICATION ROUTES ====================

/**
 * @route   GET /api/owner/notifications
 * @desc    Get all notifications
 * @access  Private (Owner)
 */
router.get('/notifications', authMiddleware, roleMiddleware(['owner']), ownerController.getNotifications);

/**
 * @route   PUT /api/owner/notifications/:notificationId/read
 * @desc    Mark notification as read
 * @access  Private (Owner)
 */
router.put('/notifications/:notificationId/read', authMiddleware, roleMiddleware(['owner']), ownerController.markNotificationAsRead);

/**
 * @route   POST /api/owner/notifications/send
 * @desc    Send notification to staff
 * @access  Private (Owner)
 */
router.post('/notifications/send', authMiddleware, roleMiddleware(['owner']), ownerController.sendNotificationToStaff);

/**
 * @route   POST /api/owner/notifications/:notificationId/reply
 * @desc    Reply to a notification
 * @access  Private (Owner)
 */
router.post('/notifications/:notificationId/reply', authMiddleware, roleMiddleware(['owner']), ownerController.replyToNotification);

/**
 * @route   GET /api/owner/notifications/:notificationId/conversation
 * @desc    Get conversation thread for a notification
 * @access  Private (Owner)
 */
router.get('/notifications/:notificationId/conversation', authMiddleware, roleMiddleware(['owner']), ownerController.getConversationThread);

/**
 * @route   GET /api/owner/conversations
 * @desc    Get all conversations (grouped notifications)
 * @access  Private (Owner)
 */
router.get('/conversations', authMiddleware, roleMiddleware(['owner']), ownerController.getConversations);

// ==================== ADMIN COMMUNICATION ROUTES ====================

/**
 * @route   POST /api/owner/contact-admin
 * @desc    Send message to admin
 * @access  Private (Owner)
 */
router.post('/contact-admin', authMiddleware, roleMiddleware(['owner']), ownerController.contactAdmin);

// ==================== AUDIT LOG ROUTES ====================

/**
 * @route   GET /api/owner/audit-logs
 * @desc    Get audit logs
 * @access  Private (Owner)
 */
router.get('/audit-logs', authMiddleware, roleMiddleware(['owner']), ownerController.getAuditLogs);

// ==================== PATIENT VIEW ROUTES ====================

/**
 * @route   GET /api/owner/patients
 * @desc    Get all patients (who had tests in this lab)
 * @access  Private (Owner)
 */
router.get('/patients', authMiddleware, roleMiddleware(['owner']), ownerController.getAllPatients);

/**
 * @route   GET /api/owner/patients/:patientId
 * @desc    Get patient details
 * @access  Private (Owner)
 */
router.get('/patients/:patientId', authMiddleware, roleMiddleware(['owner']), ownerController.getPatientById);

// ==================== FEEDBACK ROUTES ====================

/**
 * @route   POST /api/owner/feedback
 * @desc    Provide feedback on lab, test, order, or system
 * @access  Private (Owner)
 */
router.post(
  '/feedback',
  authMiddleware,
  roleMiddleware(['owner']),
  ...ownerValidator.validateFeedback,
  validateRequest,
  ownerController.provideFeedback
);

/**
 * @route   GET /api/owner/feedback
 * @desc    Get my feedback history
 * @access  Private (Owner)
 */
router.get('/feedback', authMiddleware, roleMiddleware(['owner']), ownerController.getMyFeedback);

// ==================== TEST COMPONENT ROUTES ====================

/**
 * @route   POST /api/owner/tests/:testId/components
 * @desc    Add component to a test
 * @access  Private (Owner)
 */
router.post('/tests/:testId/components', authMiddleware, roleMiddleware(['owner']), ownerController.addTestComponent);

/**
 * @route   GET /api/owner/tests/:testId/components
 * @desc    Get all components for a test
 * @access  Private (Owner)
 */
router.get('/tests/:testId/components', authMiddleware, roleMiddleware(['owner']), ownerController.getTestComponents);

/**
 * @route   PUT /api/owner/tests/:testId/components/:componentId
 * @desc    Update a test component
 * @access  Private (Owner)
 */
router.put('/tests/:testId/components/:componentId', authMiddleware, roleMiddleware(['owner']), ownerController.updateTestComponent);

/**
 * @route   DELETE /api/owner/tests/:testId/components/:componentId
 * @desc    Delete a test component
 * @access  Private (Owner)
 */
router.delete('/tests/:testId/components/:componentId', authMiddleware, roleMiddleware(['owner']), ownerController.deleteTestComponent);

// ==================== RESULTS & INVOICES ROUTES ====================

/**
 * @route   GET /api/owner/results
 * @desc    Get all results for owner's lab
 * @access  Private (Owner)
 */
router.get('/results', authMiddleware, roleMiddleware(['owner']), ownerController.getAllResults);

/**
 * @route   GET /api/owner/invoices
 * @desc    Get all invoices for owner's lab
 * @access  Private (Owner)
 */
router.get('/invoices', authMiddleware, roleMiddleware(['owner']), ownerController.getAllInvoices);

/**
 * @route   GET /api/owner/invoices/:invoiceId
 * @desc    Get invoice details by invoice ID
 * @access  Private (Owner)
 */
router.get('/invoices/:invoiceId', authMiddleware, roleMiddleware(['owner']), ownerController.getInvoiceDetails);

/**
 * @route   GET /api/owner/invoices/order/:orderId
 * @desc    Get invoice by order ID
 * @access  Private (Owner)
 */
router.get('/invoices/order/:orderId', authMiddleware, roleMiddleware(['owner']), ownerController.getInvoiceByOrderId);

/**
 * @route   GET /api/owner/audit-logs
 * @desc    Get audit logs
 * @access  Private (Owner)
 */
router.get('/audit-logs', authMiddleware, roleMiddleware(['owner']), ownerController.getAuditLogs);

/**
 * @route   GET /api/owner/audit-logs/actions
 * @desc    Get available audit log actions
 * @access  Private (Owner)
 */
router.get('/audit-logs/actions', authMiddleware, roleMiddleware(['owner']), ownerController.getAuditLogActions);

/**
 * @route   POST /api/owner/request-renewal
 * @desc    Request subscription renewal
 * @access  Private (Owner)
 */
router.post('/request-renewal', authMiddleware, roleMiddleware(['owner']), ownerController.requestRenewal);

/**
 * @route   GET /api/owner/renewal-requests
 * @desc    Get renewal requests for owner
 * @access  Private (Owner)
 */
router.get('/renewal-requests', authMiddleware, roleMiddleware(['owner']), ownerController.getRenewalRequests);

module.exports = router;

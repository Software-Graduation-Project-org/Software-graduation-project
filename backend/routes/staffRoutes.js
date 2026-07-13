const express = require("express");
const router = express.Router();
const staffController = require("../controllers/staffController");
const { 
  loginLimiter, 
  resultUploadLimiter, 
  sampleCollectionLimiter 
} = require('../middleware/rateLimitMiddleware');
const inventoryController = require('../controllers/inventoryController');
const { recordStockUsage } = require('../controllers/inventoryController');
const authMiddleware = require('../middleware/authMiddleware');
const roleMiddleware = require('../middleware/roleMiddleware');
const staffValidator = require('../validators/staffValidator');
const { validateRequest } = require('../middleware/validationMiddleware');

// ===============================
// 🧩 Authentication
// ===============================
router.post("/login", loginLimiter, ...staffValidator.validateLogin, validateRequest, staffController.loginStaff);

// ===============================
// 👤 Profile Management
// ===============================
/**
 * @route   GET /api/staff/profile
 * @desc    Get staff profile
 * @access  Private (Staff)
 */
router.get("/profile", authMiddleware, roleMiddleware(['Staff']), staffController.getProfile);

/**
 * @route   PUT /api/staff/profile
 * @desc    Update staff profile
 * @access  Private (Staff)
 */
router.put("/profile", authMiddleware, roleMiddleware(['Staff']), staffController.updateProfile);

/**
 * @route   PUT /api/staff/change-password
 * @desc    Change staff password
 * @access  Private (Staff)
 */
router.put("/change-password", authMiddleware, roleMiddleware(['Staff']), staffController.changePassword);

// ===============================
// 🧪 Tests & Results
// ===============================
router.post("/collect-sample", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  sampleCollectionLimiter,  // ✅ Rate limit: 20 per minute
  ...staffValidator.validateCollectSample,
  validateRequest,
  staffController.collectSample
);

router.post("/update-sample-status", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  staffController.updateSampleStatus
);

router.post("/upload-result", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  resultUploadLimiter,  // ✅ Rate limit: 10 per minute
  ...staffValidator.validateUploadResult,
  validateRequest,
  staffController.uploadResult
);

router.post("/run-test", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  staffController.runTest
);

// Temporary test route without auth
router.post("/test-run-test", staffController.runTest);

router.get("/tests/:testId/components",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getTestComponentsForStaff
);

router.get("/assigned-tests/:staff_id", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  staffController.getAssignedTests
);

/**
 * @route   POST /api/staff/assign-test-to-me
 * @desc    Allow staff to assign themselves to an unassigned test
 * @access  Private (Staff)
 */
router.post("/assign-test-to-me", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  ...staffValidator.validateAssignTestToMe,
  validateRequest,
  staffController.assignTestToMe
);

/**
 * @route   POST /api/staff/fix-assigned-statuses
 * @desc    Fix assigned test statuses for tests that have staff_id but wrong status
 * @access  Private (Staff)
 */
router.post("/fix-assigned-statuses", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  staffController.fixAssignedTestStatuses
);

/**
 * @route   GET /api/staff/orders
 * @desc    Get all orders for the staff's lab
 * @access  Private (Staff)
 */
router.get("/orders", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  staffController.getAllLabOrders
);

/**
 * @route   GET /api/staff/lab-tests
 * @desc    Get all tests available in the staff's lab
 * @access  Private (Staff)
 */
router.get(
  "/lab-tests",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getLabTests
);

// ===============================
// ⚙️ Issues, Devices & Inventory
// ===============================
router.post("/report-issue", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  staffController.reportIssue
);

router.get("/devices/:staff_id", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  staffController.getStaffDevices
);

router.get("/inventory/:staff_id", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  staffController.getStaffInventory
);

// ===============================
// 🔔 Notifications
// ===============================
router.get("/notifications/:staff_id", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  staffController.getStaffNotifications
);

router.put('/notifications/:staff_id/:notificationId/read', 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  staffController.markNotificationAsRead
);

// ===============================
// 📊 Staff Login Activity (for Lab Owner)
router.get("/activity/:owner_id", staffController.getStaffLoginActivity);
// ===============================
// ⚙️ Inventory Stock Usage (Staff Only)
// ===============================
router.post(
  "/stock-usage",
  authMiddleware,                   // Ensure user is authenticated
  roleMiddleware(['Staff']),        // Ensure only Staff can use this route
  recordStockUsage
);

// 📦 Inventory Issue Reporting (Staff Only)
// ===============================
router.post(
  "/report-inventory-issue",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.reportInventoryIssue
);

router.post(
  "/consume-inventory",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.consumeInventory
);

router.get(
  "/inventory",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getInventoryItems
);
/**
 * @route   GET /api/staff/dashboard
 * @desc    Get staff dashboard summary (tests, notifications, devices, inventory)
 * @access  Private (Staff)
 */
router.get(
  "/dashboard",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getStaffDashboard
);

// ===============================
// 📋 Orders Management
// ===============================

/**
 * @route   GET /api/staff/patients/search
 * @desc    Search for patients by name, email, or ID
 * @access  Private (Staff)
 */
router.get(
  "/patients/search",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.searchPatients
);

/**
 * @route   POST /api/staff/create-walk-in-order
 * @desc    Create order for walk-in patient
 * @access  Private (Staff)
 */
router.post(
  "/create-walk-in-order",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.createWalkInOrder
);

/**
 * @route   GET /api/staff/orders
 * @desc    Get all orders for the lab (all statuses)
 * @access  Private (Staff)
 */
router.get(
  "/orders",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getAllLabOrders
);

/**
 * @route   GET /api/staff/pending-orders
 * @desc    Get all pending orders waiting for patient registration
 * @access  Private (Staff)
 */
router.get(
  "/pending-orders",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getPendingOrders
);

/**
 * @route   POST /api/staff/register-patient-from-order
 * @desc    Register patient and link to existing order
 * @access  Private (Staff)
 */
router.post(
  "/register-patient-from-order",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.registerPatientFromOrder
);

/**
 * @route   GET /api/staff/order-details/:orderId
 * @desc    Get all test items (OrderDetails) for a specific order
 * @access  Private (Staff)
 */
router.get(
  "/order-details/:orderId",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getOrderDetails
);

/**
 * @route   GET /api/staff/unassigned-tests
 * @desc    Get all tests that don't have staff assigned yet
 * @access  Private (Owner/Manager)
 */
router.get(
  "/unassigned-tests",
  authMiddleware,
  roleMiddleware(['Owner']),
  staffController.getUnassignedTests
);

/**
 * @route   GET /api/staff/my-unassigned-tests
 * @desc    Get unassigned tests for staff to assign themselves to
 * @access  Private (Staff)
 */
router.get(
  "/my-unassigned-tests",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getMyUnassignedTests
);

/**
 * @route   POST /api/staff/assign-to-test
 * @desc    Manually assign or reassign staff to a specific test
 * @access  Private (Owner/Manager)
 */
router.post(
  "/assign-to-test",
  authMiddleware,
  roleMiddleware(['Owner']),
  staffController.assignStaffToTest
);

/**
 * @route   GET /api/staff/my-assigned-tests
 * @desc    Get all tests assigned to the logged-in staff member
 * @access  Private (Staff)
 */
router.get(
  "/my-assigned-tests",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getMyAssignedTests
);

/**
 * @route   PUT /api/staff/mark-completed/:detail_id
 * @desc    Mark test as completed (for fixing already uploaded results)
 * @access  Private (Staff/Owner)
 */
router.put(
  "/mark-completed/:detail_id",
  authMiddleware,
  roleMiddleware(['Staff', 'Owner']),
  staffController.markTestCompleted
);

/**
 * @route   POST /api/staff/auto-assign-tests
 * @desc    Auto-assign tests based on device-staff relationship for an order
 * @access  Private (Staff)
 */
router.post(
  "/auto-assign-tests",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.autoAssignTests
);

/**
 * @route   POST /api/staff/generate-sample-barcode/:detail_id
 * @desc    Generate barcode for a sample/test (can be called before sample collection)
 * @access  Private (Staff)
 */
router.post(
  "/generate-sample-barcode/:detail_id",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.generateSampleBarcode
);

/**
 * @route   POST /api/staff/generate-barcode/:orderId
 * @desc    Generate barcode for an order (can be called before sample collection)
 * @access  Private (Staff)
 */
router.post(
  "/generate-barcode/:orderId",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.generateBarcode
);

// ==================== FEEDBACK ROUTES ====================

/**
 * @route   POST /api/staff/feedback
 * @desc    Provide feedback on lab, test, or order
 * @access  Private (Staff)
 */
router.post(
  "/feedback",
  authMiddleware,
  roleMiddleware(['Staff']),
  ...staffValidator.validateFeedback,
  validateRequest,
  staffController.provideFeedback
);

/**
 * @route   GET /api/staff/feedback
 * @desc    Get my feedback history
 * @access  Private (Staff)
 */
router.get(
  "/feedback",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getMyFeedback
);

/**
 * @route   GET /api/staff/doctors
 * @desc    Get all doctors
 * @access  Private (Staff)
 */
router.get('/doctors', authMiddleware, roleMiddleware(['Staff']), staffController.getAllDoctors);

// ===============================
// 📊 Results & Invoices
// ===============================

/**
 * @route   GET /api/staff/results
 * @desc    Get all results for staff's lab
 * @access  Private (Staff)
 */
router.get('/results', authMiddleware, roleMiddleware(['Staff']), staffController.getAllResults);

/**
 * @route   GET /api/staff/tests-for-upload
 * @desc    Get tests ready for result upload
 * @access  Private (Staff)
 */
router.get('/tests-for-upload', authMiddleware, roleMiddleware(['Staff']), staffController.getTestsForResultUpload);

/**
 * @route   GET /api/staff/invoices
 * @desc    Get all invoices for staff's lab
 * @access  Private (Staff)
 */
router.get('/invoices', authMiddleware, roleMiddleware(['Staff']), staffController.getAllInvoices);

/**
 * @route   GET /api/staff/orders/:orderId/results
 * @desc    Get order results report (same as patient view)
 * @access  Private (Staff)
 */
router.get('/orders/:orderId/results', authMiddleware, roleMiddleware(['Staff']), staffController.getOrderResultsReport);

/**
 * @route   GET /api/staff/invoices/:invoiceId/details
 * @desc    Get invoice details (same as patient view)
 * @access  Private (Staff)
 */
router.get('/invoices/:invoiceId/details', authMiddleware, roleMiddleware(['Staff']), staffController.getInvoiceDetails);

/**
 * @route   GET /api/staff/orders/:orderId/invoice
 * @desc    Get invoice ID for a specific order
 * @access  Private (Staff)
 */
router.get('/orders/:orderId/invoice', authMiddleware, roleMiddleware(['Staff']), staffController.getInvoiceByOrderId);

/**
 * @route   POST /api/staff/send-whatsapp
 * @desc    Send direct WhatsApp message (for testing)
 * @access  Private (Staff)
 */
router.post('/send-whatsapp', authMiddleware, roleMiddleware(['Staff']), async (req, res) => {
  try {
    const { phone_number, message } = req.body;

    if (!phone_number || !message) {
      return res.status(400).json({
        success: false,
        message: 'Phone number and message are required'
      });
    }

    const { sendWhatsAppMessage } = require('../utils/sendWhatsApp');
    const success = await sendWhatsAppMessage(phone_number, message);

    if (success) {
      res.json({
        success: true,
        message: 'WhatsApp message sent successfully'
      });
    } else {
      res.status(500).json({
        success: false,
        message: 'Failed to send WhatsApp message'
      });
    }
  } catch (error) {
    console.error('Error sending WhatsApp message:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// ===============================
// ✅ Export Router
// ===============================
module.exports = router;

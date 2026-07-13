const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const authMiddleware = require('../middleware/authMiddleware');
const roleMiddleware = require('../middleware/roleMiddleware');
router.post('/login', adminController.login);

// 🟢 Public routes (no authentication required)
router.get('/contact-info', adminController.getContactInfo);

// ✅ Protect routes: only Admins
router.use(authMiddleware, roleMiddleware(['admin']));

// � Profile Management
/**
 * @route   GET /api/admin/profile
 * @desc    Get admin profile
 * @access  Private (Admin)
 */
router.get('/profile', adminController.getProfile);

/**
 * @route   PUT /api/admin/profile
 * @desc    Update admin profile
 * @access  Private (Admin)
 */
router.put('/profile', adminController.updateProfile);

// �🟡 Lab Owner management routes
router.get('/labowners', adminController.getAllLabOwners);
router.get('/labowners/pending', adminController.getPendingLabOwners);
router.get('/labowners/:ownerId', adminController.getLabOwnerById);
router.put('/labowner/:ownerId/approve', adminController.approveLabOwner);
router.put('/labowner/:ownerId/reject', adminController.rejectLabOwner);
router.put('/labowners/:ownerId/deactivate', adminController.deactivateLabOwner);
router.put('/labowners/:ownerId/reactivate', adminController.reactivateLabOwner);

// 🟢 Notifications routes
router.post('/notifications/send', adminController.sendGlobalNotification);
router.get('/notifications', adminController.getAllNotifications);
router.put('/notifications/:notificationId/read', adminController.markNotificationAsRead);
router.post('/notifications/:notificationId/reply', adminController.replyToOwnerNotification);

// 📝 Feedback routes
router.get('/feedback', adminController.getAllFeedback);

// 📊 Dashboard & subscriptions
router.get('/dashboard', adminController.getDashboard);
router.get('/stats', adminController.getStats);
router.get('/expiring-subscriptions', adminController.getExpiringSubscriptions); // Uncommented - needed for frontend
router.post('/extend-subscription', adminController.extendSubscription); // Extend lab subscription

// 🆕 Enhanced Dashboard Features
router.get('/system-health', adminController.getSystemHealth);
router.get('/realtime-metrics', adminController.getRealTimeMetrics);
router.get('/alerts', adminController.getAlerts);

// 📊 Reports routes
router.get('/reports', adminController.generateReports);

// 🔄 Renewal Request Management
router.get('/renewal-requests', adminController.getRenewalRequests);
router.put('/renewal-requests/:requestId/approve', adminController.approveRenewalRequest);
router.put('/renewal-requests/:requestId/deny', adminController.denyRenewalRequest);

module.exports = router;

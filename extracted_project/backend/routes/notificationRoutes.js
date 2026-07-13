const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');
const authMiddleware = require('../middleware/authMiddleware');
const roleMiddleware = require('../middleware/roleMiddleware');

// ==================== FCM TOKEN MANAGEMENT ====================

/**
 * @route   POST /api/notifications/register-token
 * @desc    Register FCM token for push notifications
 * @access  Private (All authenticated users)
 */
router.post('/register-token', authMiddleware, notificationController.registerToken);

// ==================== PUSH NOTIFICATIONS ====================

/**
 * @route   POST /api/notifications/send-to-user
 * @desc    Send push notification to specific user
 * @access  Private (Admin/Owner)
 */
router.post('/send-to-user', authMiddleware, roleMiddleware(['admin', 'owner']), notificationController.sendToUser);

/**
 * @route   POST /api/notifications/send-bulk
 * @desc    Send push notification to multiple users
 * @access  Private (Admin/Owner)
 */
router.post('/send-bulk', authMiddleware, roleMiddleware(['admin', 'owner']), notificationController.sendBulk);

/**
 * @route   POST /api/notifications/test-result
 * @desc    Send test result notification to patient
 * @access  Private (Staff)
 */
router.post('/test-result', authMiddleware, roleMiddleware(['staff']), notificationController.sendTestResultNotification);

module.exports = router;
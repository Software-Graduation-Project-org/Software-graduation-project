const Notification = require('../models/Notification');
const Admin = require('../models/Admin');
const Owner = require('../models/Owner');
const Staff = require('../models/Staff');
const Doctor = require('../models/Doctor');
const Patient = require('../models/Patient');

const FCMToken = require('../models/FCMToken');

// Initialize Firebase Admin SDK
let admin;
let fcmTokens = new Map(); // Temporary fallback for in-memory storage

try {
  admin = require('firebase-admin');

  // Check if Firebase is already initialized
  if (!admin.apps.length) {
    const serviceAccount = require('../config/firebase-service-account.json');

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: 'medical-lab-6a8d4'
    });
  }

  console.log('✅ Firebase Admin SDK initialized successfully');
  console.log('📱 Push notifications are now enabled');
} catch (error) {
  console.warn('❌ Firebase Admin SDK initialization failed:', error.message);
  console.warn('📱 Push notifications will be simulated');
  admin = null; // Set to null to indicate Firebase is not available
}

// Helper function to get user's FCM token
const getUserFCMToken = async (userId) => {
  try {
    // Try to get from database first
    const tokenDoc = await FCMToken.findOne({
      user_id: userId,
      is_active: true
    }).sort({ last_updated: -1 });

    if (tokenDoc) {
      return tokenDoc.token;
    }

    // Fallback to in-memory storage
    return fcmTokens.get(userId.toString());
  } catch (error) {
    console.error('Error getting FCM token:', error);
    return fcmTokens.get(userId.toString());
  }
};

// Helper function to normalize user type to match schema enum
const normalizeUserType = (userType) => {
  const typeMap = {
    'patient': 'Patient',
    'staff': 'Staff', 
    'doctor': 'Doctor',
    'owner': 'Owner',
    'Patient': 'Patient',
    'Staff': 'Staff',
    'Doctor': 'Doctor',
    'Owner': 'Owner'
  };
  return typeMap[userType] || 'Patient';
};

// Helper function to store user's FCM token
const storeUserFCMToken = async (userId, token, userType = 'Patient') => {
  try {
    // Normalize the user type to match schema enum
    const normalizedUserType = normalizeUserType(userType);
    
    // First, check if this token exists for ANY user (same device, different user)
    const existingToken = await FCMToken.findOne({ token: token });
    
    if (existingToken) {
      // Token exists - update it to the new user (reassign device to new user)
      existingToken.user_id = userId;
      existingToken.user_model = normalizedUserType;
      existingToken.is_active = true;
      existingToken.last_updated = new Date();
      await existingToken.save();
      console.log(`📱 FCM token reassigned to ${normalizedUserType}: ${userId}`);
    } else {
      // Token doesn't exist - create new entry
      await FCMToken.create({
        user_id: userId,
        user_model: normalizedUserType,
        token: token,
        is_active: true,
        last_updated: new Date()
      });
      console.log(`📱 FCM token stored in database for ${normalizedUserType}: ${userId}`);
    }

    // Also store in memory as fallback
    fcmTokens.set(userId.toString(), token);
  } catch (error) {
    console.error('Error storing FCM token in database:', error);
    // Fallback to in-memory storage
    fcmTokens.set(userId.toString(), token);
    console.log(`📱 FCM token stored in memory for ${userType}: ${userId}`);
  }
};

// ==================== FCM TOKEN MANAGEMENT ====================

// Register FCM token for push notifications
const registerToken = async (req, res) => {
  try {
    const { token, userId, userType } = req.body;

    if (!token || !userId || !userType) {
      return res.status(400).json({
        success: false,
        message: 'Token, userId, and userType are required'
      });
    }

    // Store the FCM token
    await storeUserFCMToken(userId, token, userType);

    console.log(`📱 FCM Token registered for ${userType}: ${userId}`);

    res.status(200).json({
      success: true,
      message: 'FCM token registered successfully'
    });
  } catch (error) {
    console.error('❌ Error registering FCM token:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to register FCM token'
    });
  }
};

// ==================== PUSH NOTIFICATIONS ====================

// Send push notification to specific user
const sendToUser = async (req, res) => {
  try {
    const { userId, title, body, data } = req.body;

    if (!title || !body) {
      return res.status(400).json({
        success: false,
        message: 'Title and body are required'
      });
    }

    if (!admin) {
      console.log(`📱 SIMULATED: Sending notification to user ${userId}: ${title}`);
      return res.status(200).json({
        success: true,
        message: 'Notification sent successfully (simulated - Firebase not available)'
      });
    }

    // Find user and get their FCM token
    // For now, we'll need to implement token storage
    // This is a placeholder - you'll need to store FCM tokens in your database
    const userToken = await getUserFCMToken(userId);

    if (!userToken) {
      console.log(`No FCM token found for user ${userId}`);
      return res.status(404).json({
        success: false,
        message: 'User FCM token not found'
      });
    }

    const message = {
      token: userToken,
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    console.log(`📱 Sending push notification to user ${userId}: ${title}`);

    const response = await admin.messaging().send(message);

    console.log('✅ Push notification sent successfully:', response);

    res.status(200).json({
      success: true,
      message: 'Push notification sent successfully',
      messageId: response
    });
  } catch (error) {
    console.error('❌ Error sending push notification:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to send push notification',
      error: error.message
    });
  }
};

// Send push notification to patient (helper function for other controllers)
const sendPushNotificationToPatient = async (patientId, title, body, data = {}) => {
  try {
    if (!admin) {
      console.log(`📱 SIMULATED: Would send push notification to patient ${patientId}: ${title}`);
      return false; // Return false to indicate notification was not actually sent
    }

    const userToken = await getUserFCMToken(patientId);

    if (!userToken) {
      console.log(`📱 No FCM token found for patient ${patientId}`);
      return false;
    }

    const message = {
      token: userToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...Object.fromEntries(
          Object.entries(data).map(([key, value]) => [key, String(value)])
        ),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'test_results',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            alert: {
              title: title,
              body: body,
            },
          },
        },
      },
    };

    console.log(`📱 Sending push notification to patient ${patientId}: ${title}`);

    const response = await admin.messaging().send(message);

    console.log('✅ Push notification sent to patient successfully:', response);
    return true;
  } catch (error) {
    console.error('❌ Error sending push notification to patient:', error);
    return false;
  }
};

// Send push notification to doctor (helper function for other controllers)
const sendPushNotificationToDoctor = async (doctorId, title, body, data = {}) => {
  try {
    if (!admin) {
      console.log(`📱 SIMULATED: Would send push notification to doctor ${doctorId}: ${title}`);
      return false; // Return false to indicate notification was not actually sent
    }

    const userToken = await getUserFCMToken(doctorId);

    if (!userToken) {
      console.log(`📱 No FCM token found for doctor ${doctorId}`);
      return false;
    }

    const message = {
      token: userToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...Object.fromEntries(
          Object.entries(data).map(([key, value]) => [key, String(value)])
        ),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'general_notifications',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            alert: {
              title: title,
              body: body,
            },
          },
        },
      },
    };

    console.log(`📱 Sending push notification to doctor ${doctorId}: ${title}`);

    const response = await admin.messaging().send(message);

    console.log('✅ Push notification sent to doctor successfully:', response);
    return true;
  } catch (error) {
    console.error('❌ Error sending push notification to doctor:', error);
    return false;
  }
};

// Send push notification to staff (helper function for other controllers)
const sendPushNotificationToStaff = async (staffId, title, body, data = {}) => {
  try {
    if (!admin) {
      console.log(`📱 SIMULATED: Would send push notification to staff ${staffId}: ${title}`);
      return false; // Return false to indicate notification was not actually sent
    }

    const userToken = await getUserFCMToken(staffId);

    if (!userToken) {
      console.log(`📱 No FCM token found for staff ${staffId}`);
      return false;
    }

    const message = {
      token: userToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...Object.fromEntries(
          Object.entries(data).map(([key, value]) => [key, String(value)])
        ),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'general_notifications',
          priority: 'high',
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            alert: {
              title: title,
              body: body,
            },
          },
        },
      },
    };

    console.log(`📱 Sending push notification to staff ${staffId}: ${title}`);

    const response = await admin.messaging().send(message);

    console.log('✅ Push notification sent to staff successfully:', response);
    return true;
  } catch (error) {
    console.error('❌ Error sending push notification to staff:', error);
    return false;
  }
};

// Send push notification to admin (helper function for other controllers)
const sendPushNotificationToAdmin = async (adminId, title, body, data = {}) => {
  try {
    if (!admin) {
      console.log(`📱 SIMULATED: Would send push notification to admin ${adminId}: ${title}`);
      return false; // Return false to indicate notification was not actually sent
    }

    const userToken = await getUserFCMToken(adminId);

    if (!userToken) {
      console.log(`📱 No FCM token found for admin ${adminId}`);
      return false;
    }

    const message = {
      token: userToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...Object.fromEntries(
          Object.entries(data).map(([key, value]) => [key, String(value)])
        ),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'admin_notifications',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            alert: {
              title: title,
              body: body,
            },
          },
        },
      },
    };

    console.log(`📱 Sending push notification to admin ${adminId}: ${title}`);

    const response = await admin.messaging().send(message);

    console.log('✅ Push notification sent to admin successfully:', response);
    return true;
  } catch (error) {
    console.error('❌ Error sending push notification to admin:', error);
    return false;
  }
};

const sendPushNotificationToOwner = async (ownerId, title, body, data = {}) => {
  try {
    if (!admin) {
      console.log(`📱 SIMULATED: Would send push notification to owner ${ownerId}: ${title}`);
      return false; // Return false to indicate notification was not actually sent
    }

    const userToken = await getUserFCMToken(ownerId);

    if (!userToken) {
      console.log(`📱 No FCM token found for owner ${ownerId}`);
      return false;
    }

    const message = {
      token: userToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...Object.fromEntries(
          Object.entries(data).map(([key, value]) => [key, String(value)])
        ),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'owner_notifications',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            alert: {
              title: title,
              body: body,
            },
          },
        },
      },
      webpush: {
        fcm_options: {
          link: `http://localhost:8080/?notification=${data.type || 'general'}`
        }
      },
    };

    console.log(`📱 Sending push notification to owner ${ownerId}: ${title}`);

    const response = await admin.messaging().send(message);

    console.log('✅ Push notification sent to owner successfully:', response);
    return true;
  } catch (error) {
    console.error('❌ Error sending push notification to owner:', error);
    return false;
  }
};

// Send bulk notifications
const sendBulk = async (req, res) => {
  try {
    const { userIds, title, body, data } = req.body;

    // Simulate sending bulk notifications
    console.log(`Sending bulk notification to ${userIds.length} users: ${title}`);

    res.status(200).json({
      success: true,
      message: 'Bulk notifications sent successfully (simulated)'
    });
  } catch (error) {
    console.error('Error sending bulk notifications:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to send bulk notifications'
    });
  }
};

// Send test result notification
const sendTestResultNotification = async (req, res) => {
  try {
    const { patientId, testName, result } = req.body;

    // Simulate sending test result notification
    console.log(`Sending test result notification for ${testName} to patient ${patientId}`);

    res.status(200).json({
      success: true,
      message: 'Test result notification sent successfully (simulated)'
    });
  } catch (error) {
    console.error('Error sending test result notification:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to send test result notification'
    });
  }
};

module.exports = {
  registerToken,
  sendToUser,
  sendBulk,
  sendTestResultNotification,
  sendPushNotificationToPatient,
  sendPushNotificationToDoctor,
  sendPushNotificationToStaff,
  sendPushNotificationToAdmin,
  sendPushNotificationToOwner,
  getUserFCMToken,
  storeUserFCMToken
};
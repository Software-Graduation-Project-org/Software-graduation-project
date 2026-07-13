// cronJobs.js
const cron = require('node-cron');
const LabOwner = require('./models/Owner'); 
const Notification = require('./models/Notification');
const logger = require('./utils/logger');

// 🕒 Daily subscription check & suspension job
cron.schedule('0 8 * * *', async () => { // runs every day at 08:00
  try {
    const today = new Date();
    const owners = await LabOwner.find();

    for (const owner of owners) {
      if (!owner.subscription_end) continue;

      const diffDays = Math.ceil((owner.subscription_end - today) / (1000 * 60 * 60 * 24));

      // 🔹 Check if "Expiring Soon" notification already exists
      if (diffDays > 0 && diffDays <= 7) {
        const alreadyNotified = await Notification.findOne({
          receiver_id: owner._id,
          receiver_model: 'Owner',
          type: 'subscription',
          title: 'Subscription Expiring Soon',
          'message': { $regex: owner.subscription_end.toDateString() }
        });

        if (!alreadyNotified) {
          await Notification.create({
            receiver_id: owner._id,
            receiver_model: 'Owner',
            type: 'subscription',
            title: 'Subscription Expiring Soon',
            message: `Your subscription will expire in ${diffDays} day(s) on ${owner.subscription_end.toDateString()}. Please renew in time.`
          });

          // 📱 Send push notification to owner if Firebase is available
          try {
            const notificationController = require('./controllers/notificationController');
            const pushResult = await notificationController.sendPushNotificationToOwner(
              owner._id,
              'Subscription Expiring Soon',
              `Your subscription will expire in ${diffDays} day(s). Please renew in time.`,
              {
                type: 'subscription',
                owner_id: owner._id.toString(),
                days_remaining: diffDays.toString(),
                receiver_model: 'Owner'
              }
            );

            if (pushResult) {
              console.log('✅ DEBUG: Push notification sent to owner for subscription expiring');
            } else {
              console.log('📱 DEBUG: Push notification not sent to owner (Firebase not available or no token)');
            }
          } catch (pushError) {
            console.error('Failed to send push notification to owner (this does not affect notification creation):', pushError);
          }
        }
      }

      // 🔹 Suspend expired subscriptions if not already inactive
      if (diffDays <= 0 && owner.is_active) {
        owner.is_active = false;
        await owner.save();

        // Check if "Account Suspended" notification already exists
        const suspendedNotified = await Notification.findOne({
          receiver_id: owner._id,
          receiver_model: 'Owner',
          type: 'subscription',
          title: 'Account Suspended',
          'message': { $regex: owner.subscription_end.toDateString() }
        });

        if (!suspendedNotified) {
          await Notification.create({
            receiver_id: owner._id,
            receiver_model: 'Owner',
            type: 'subscription',
            title: 'Account Suspended',
            message: `Your lab account has been suspended because your subscription expired on ${owner.subscription_end.toDateString()}. Please renew to reactivate.`
          });

          // 📱 Send push notification to owner if Firebase is available
          try {
            const notificationController = require('./controllers/notificationController');
            const pushResult = await notificationController.sendPushNotificationToOwner(
              owner._id,
              'Account Suspended',
              `Your lab account has been suspended due to expired subscription. Please renew to reactivate.`,
              {
                type: 'subscription',
                owner_id: owner._id.toString(),
                status: 'suspended',
                receiver_model: 'Owner'
              }
            );

            if (pushResult) {
              console.log('✅ DEBUG: Push notification sent to owner for account suspension');
            } else {
              console.log('📱 DEBUG: Push notification not sent to owner (Firebase not available or no token)');
            }
          } catch (pushError) {
            console.error('Failed to send push notification to owner (this does not affect notification creation):', pushError);
          }
        }
      }
    }

    logger.info('Daily subscription check & notifications completed without duplicates.');
  } catch (err) {
    logger.error('Error in subscription cron job', { error: err.message, stack: err.stack });
  }
});
module.exports = cron;
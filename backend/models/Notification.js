const mongoose = require('mongoose');

const NotificationSchema = new mongoose.Schema({
  sender_id: { type: mongoose.Schema.Types.ObjectId, refPath: 'sender_model' },
  sender_model: { type: String, enum: ['Admin', 'Owner', 'Doctor', 'Patient','Staff', 'System'] },

  receiver_id: { type: mongoose.Schema.Types.ObjectId, refPath: 'receiver_model' },
  receiver_model: { type: String, enum: ['Owner', 'Patient', 'Doctor','Admin','Staff'], required: true },

  type: { type: String, enum: ['subscription', 'system', 'maintenance', 'test_result', 'request', 'payment', 'inventory', 'message', 'issue', 'feedback', 'result_uploaded', 'order_completed', 'renewal_request', 'renewal_confirmation', 'subscription_approved', 'subscription_denied', 'subscription_renewal'], default: 'subscription' },
  title: String,
  message: String,
  related_id: { type: mongoose.Schema.Types.ObjectId }, 
  metadata: { type: mongoose.Schema.Types.Mixed }, // Additional data for specific notification types
  is_read: { type: Boolean, default: false },
  
  // Conversation threading
  parent_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Notification' }, // Reference to original message
  conversation_id: { type: mongoose.Schema.Types.ObjectId }, // Group messages in same conversation
  is_reply: { type: Boolean, default: false }
}, {
  timestamps: true
});

// Index for faster conversation queries
NotificationSchema.index({ conversation_id: 1, createdAt: 1 });
NotificationSchema.index({ receiver_id: 1, is_read: 1 });

module.exports = mongoose.model('Notification', NotificationSchema);
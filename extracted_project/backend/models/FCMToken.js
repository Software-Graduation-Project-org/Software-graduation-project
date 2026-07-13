const mongoose = require('mongoose');

const fcmTokenSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    required: true,
    refPath: 'user_model'
  },
  user_model: {
    type: String,
    required: true,
    enum: ['Patient', 'Staff', 'Doctor', 'Owner']
  },
  token: {
    type: String,
    required: true,
    unique: true
  },
  platform: {
    type: String,
    enum: ['android', 'ios', 'web'],
    default: 'android'
  },
  is_active: {
    type: Boolean,
    default: true
  },
  last_updated: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Index for efficient lookups
fcmTokenSchema.index({ user_id: 1, user_model: 1 });

// Prevent duplicate tokens for the same user
fcmTokenSchema.pre('save', async function(next) {
  if (this.isNew) {
    // Deactivate old tokens for this user
    await this.constructor.updateMany(
      {
        user_id: this.user_id,
        user_model: this.user_model,
        is_active: true
      },
      { is_active: false }
    );
  }
  next();
});

module.exports = mongoose.model('FCMToken', fcmTokenSchema);
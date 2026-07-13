const mongoose = require('mongoose');

const feedbackSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    required: true,
    refPath: 'user_model'
  },
  user_model: {
    type: String,
    required: true,
    enum: ['Doctor', 'Patient', 'Staff', 'Owner']
  },
  target_type: {
    type: String,
    required: true,
    enum: ['lab', 'test', 'order', 'system', 'service']
  },
  target_id: {
    type: mongoose.Schema.Types.ObjectId,
    required: function() {
      return this.target_type !== 'system';
    },
    refPath: 'target_model'
  },
  target_model: {
    type: String,
    required: function() {
      return !['system', 'service'].includes(this.target_type);
    },
    enum: ['Owner', 'Test', 'Order']
  },
  rating: {
    type: Number,
    min: 1,
    max: 5,
    required: true
  },
  message: {
    type: String,
    required: true,
    trim: true,
    maxlength: 1000
  },
  is_anonymous: {
    type: Boolean,
    default: false
  },
  response: {
    message: String,
    responded_by: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Staff'
    },
    responded_at: Date
  }
}, {
  timestamps: true
});

// Indexes for better query performance
feedbackSchema.index({ user_id: 1, createdAt: -1 });
feedbackSchema.index({ rating: 1, createdAt: -1 });

module.exports = mongoose.model('Feedback', feedbackSchema);
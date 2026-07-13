const mongoose = require('mongoose');

const resultSchema = new mongoose.Schema({
  detail_id: { type: mongoose.Schema.Types.ObjectId, ref: 'OrderDetails' },
  // For simple tests with single value (backward compatibility)
  result_value: String,
  units: String,
  reference_range: String,
  remarks: String,
  // For complex tests with multiple components
  has_components: { type: Boolean, default: false },
  // Abnormality tracking
  is_abnormal: { type: Boolean, default: false },
  abnormal_components_count: { type: Number, default: 0 },
  // Staff who uploaded the result
  staff_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Staff' }
}, {
  timestamps: true
});

// Index for faster queries
resultSchema.index({ detail_id: 1 });

module.exports = mongoose.model('Result', resultSchema);

const mongoose = require('mongoose');

const orderDetailSchema = new mongoose.Schema({
  order_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Order' },
  test_id: { type: mongoose.Schema.Types.ObjectId, ref: 'TestManagement' },
  
  // Device assignment
  device_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Device' },
  
  // Staff assignment (auto-assigned based on device)
  staff_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Staff' },
  assigned_at: { type: Date },
  
  // Sample collection tracking
  sample_collected: { type: Boolean, default: false },
  sample_collected_date: { type: Date },
  
  // Result tracking
  result_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Result' },
  result_uploaded: { type: Boolean, default: false },
  completed_at: { type: Date },
  
  status: { 
    type: String, 
    enum: ['pending', 'assigned', 'collected', 'in_progress', 'simulating', 'failed', 'completed'], 
    default: 'pending' 
  }
}, {
  timestamps: true
});

// Index for staff querying their assigned tests
orderDetailSchema.index({ staff_id: 1, status: 1 });

// Index for device-based queries
orderDetailSchema.index({ device_id: 1, status: 1 });

module.exports = mongoose.model('OrderDetails', orderDetailSchema);

const mongoose = require('mongoose');

const testComponentSchema = new mongoose.Schema({
  test_id: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'TestManagement', 
    required: true,
    index: true
  },
  component_name: { 
    type: String, 
    required: true 
  },
  component_code: { 
    type: String 
  },
  units: { 
    type: String 
  },
  reference_range: { 
    type: String 
  },
  min_value: { 
    type: Number 
  },
  max_value: { 
    type: Number 
  },
  display_order: { 
    type: Number, 
    default: 0 
  },
  is_active: { 
    type: Boolean, 
    default: true 
  },
  description: { 
    type: String 
  }
}, {
  timestamps: true
});

// Compound index for faster queries
testComponentSchema.index({ test_id: 1, display_order: 1 });

module.exports = mongoose.model('TestComponent', testComponentSchema);

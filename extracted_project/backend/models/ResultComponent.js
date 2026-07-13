const mongoose = require('mongoose');

const resultComponentSchema = new mongoose.Schema({
  result_id: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Result', 
    required: true,
    index: true
  },
  component_id: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'TestComponent', 
    required: true 
  },
  component_name: { 
    type: String, 
    required: true 
  },
  component_value: { 
    type: String, 
    required: true 
  },
  units: { 
    type: String 
  },
  reference_range: { 
    type: String 
  },
  is_abnormal: { 
    type: Boolean, 
    default: false 
  },
  remarks: { 
    type: String 
  }
}, {
  timestamps: true
});

// Compound index for faster queries
resultComponentSchema.index({ result_id: 1, component_id: 1 });

module.exports = mongoose.model('ResultComponent', resultComponentSchema);

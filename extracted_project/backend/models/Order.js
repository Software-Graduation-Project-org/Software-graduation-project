const mongoose = require('mongoose');

const orderSchema = new mongoose.Schema({
  // Patient reference (optional initially - filled when staff registers patient)
  patient_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Patient',
    required: true
  },
  address: require('./schemas/addressSchema'),
  
  // Temporary patient info (for orders submitted before patient registration)
  temp_patient_info: {
    full_name: {
      first: String,
      middle: String,
      last: String
    },
    identity_number: String,
    email: String,
    phone_number: String,
    birthday: Date,
    gender: String,
    address: String
  },
  
  // Who requested this order (flexible reference using refPath)
  requested_by: { type: mongoose.Schema.Types.ObjectId, refPath: 'requested_by_model' },
  requested_by_model: { 
    type: String, 
    enum: ['Patient', 'Doctor'],
    default: null
  },
  
  doctor_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Doctor' },  // If doctor is involved
  order_date: { type: Date, default: Date.now },
  status: { type: String, enum: ['pending','processing','completed'], default: 'pending' },
  remarks: String,
  owner_id: { type: mongoose.Schema.Types.ObjectId, ref: 'LabOwner', required: true },
  
  // Track if patient has been registered
  is_patient_registered: { type: Boolean, default: false },
  
  // Account registration token for email/SMS link
  registration_token: { type: String, unique: true, sparse: true },
  registration_token_expires: { type: Date }
}, {
  timestamps: true
});


orderSchema.statics.generateRegistrationToken = function() {
  const crypto = require('crypto');
  return crypto.randomBytes(32).toString('hex');
};

module.exports = mongoose.model('Order', orderSchema);

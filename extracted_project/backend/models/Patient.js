const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const addressSchema = require('./schemas/addressSchema');

const patientSchema = new mongoose.Schema({
  full_name: { 
    first: { type: String, required: true }, 
    middle: String, 
    last: { type: String, required: true } 
  },
  identity_number: { type: String, required: true, unique: true },
  birthday: Date,
  gender: { type: String, enum: ['Male', 'Female', 'Other'] },
  social_status: { type: String, enum: ['Single', 'Married', 'Divorced', 'Widowed'] },
  phone_number: String,
  address: addressSchema,
  patient_id: { type: String, unique: true },
  insurance_provider: String,
  insurance_number: String,
  notes: String,
  email: { type: String, unique: true },
  username: { 
    type: String, 
    unique: true,
    lowercase: true,
    trim: true,
    validate: {
      validator: function(v) {
        return /^[a-z0-9._-]+$/.test(v);
      },
      message: 'Username can only contain lowercase letters, numbers, dots, underscores, and hyphens (no spaces)'
    }
  },
  password: { type: String, required: true },
  created_by_staff: { type: mongoose.Schema.Types.ObjectId, ref: 'Staff' },
  last_login: Date,

  // FCM Push Notification Token
  fcm_token: String,
  platform: { type: String, enum: ['android', 'ios', 'web'] },
  token_updated_at: Date
}, {
  timestamps: true
});

// Normalize username before saving
patientSchema.pre('save', async function(next) {
  if (this.isModified('username')) {
    // Remove spaces and convert to lowercase
    this.username = this.username.replace(/\s+/g, '.').toLowerCase();
    
    // Check uniqueness across all user collections
    const existingUsers = await Promise.all([
      mongoose.model('Doctor').findOne({ username: this.username }),
      mongoose.model('Staff').findOne({ username: this.username }),
      mongoose.model('LabOwner').findOne({ username: this.username }),
      mongoose.model('Admin').findOne({ username: this.username }),
      mongoose.model('Patient').findOne({ username: this.username, _id: { $ne: this._id } })
    ]);
    
    if (existingUsers.some(user => user !== null)) {
      return next(new Error('Username already exists across all user roles'));
    }
  }
  next();
});

// Hash password before saving
patientSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

// Method to compare password
patientSchema.methods.comparePassword = async function(password) {
  return bcrypt.compare(password, this.password);
};

module.exports = mongoose.model('Patient', patientSchema);

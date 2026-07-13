const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const ownerSchema = new mongoose.Schema({
    subscriptionFee: {
      type: Number,
      default: 100, // Default fee, can be changed per owner
      min: 0
    },
  subscription_period_months: {
    type: Number,
    default: 1,
    min: 1,
    max: 12
  },
  lab_name: {
    type: String,
    required: true,
    default: function() {
      // Auto-generate from name if not provided
      return `${this.name.first} ${this.name.middle ? this.name.middle + ' ' : ''}${this.name.last}`.trim();
    }
  },
  lab_license_number: {
    type: String
  },
  owner_id: {
    type: String,
    unique: true,
    sparse: true // Allow null values initially
  },
  name: {
    first: { type: String, required: true },
    middle: { type: String },
    last: { type: String, required: true }
  },
  identity_number: { 
    type: String, 
    required: true, 
    unique: true 
  },
  birthday: { 
    type: Date, 
    required: true 
  },
  gender: { 
    type: String, 
    enum: ['Male', 'Female', 'Other'],
    required: true 
  },
  social_status: { 
    type: String, 
    enum: ['Single', 'Married', 'Divorced', 'Widowed'] 
  },
  phone_number: { 
    type: String, 
    required: true 
  },
  address: require('./schemas/addressSchema'),
  qualification: { 
    type: String 
  },
  profession_license: { 
    type: String 
  },
  bank_iban: { 
    type: String 
  },
  email: { 
    type: String, 
    required: true, 
    unique: true 
  },
  username: { 
    type: String,
    required: function() {
      return this.status === 'approved';
    },
    unique: true,
    sparse: true, // Allow multiple null values for pending owners
    lowercase: true,
    trim: true,
    validate: {
      validator: function(v) {
        return /^[a-z0-9._-]+$/.test(v);
      },
      message: 'Username can only contain lowercase letters, numbers, dots, underscores, and hyphens (no spaces)'
    }
  },
  password: { 
    type: String, 
    required: function() {
      return this.status === 'approved';
    }
  },
  date_subscription: { 
    type: Date, 
    default: Date.now 
  },
  admin_id: { 
    type: mongoose.Schema.Types.ObjectId, ref: "Admin", required: true 
  },
  subscription_end: { 
    type: Date 
  },
  is_active: { 
    type: Boolean, 
    default: false 
  },
  status: { 
    type: String, 
    enum: ['pending', 'approved', 'rejected'],
    default: 'pending'
  },
  rejection_reason: {
    type: String
  },
  temp_credentials: {
    username: { type: String },
    password: { type: String }
  },

  // Office Hours
  office_hours: [{
    day: {
      type: String,
      enum: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
      required: true
    },
    open_time: {
      type: String,
      required: true,
      validate: {
        validator: function(v) {
          return /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/.test(v);
        },
        message: 'Open time must be in HH:MM format (24-hour)'
      }
    },
    close_time: {
      type: String,
      required: true,
      validate: {
        validator: function(v) {
          return /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/.test(v);
        },
        message: 'Close time must be in HH:MM format (24-hour)'
      }
    },
    is_closed: {
      type: Boolean,
      default: false
    }
  }],

  // FCM Push Notification Token
  fcm_token: String,
  platform: { type: String, enum: ['android', 'ios', 'web'] },
  token_updated_at: Date
}, {
  timestamps: true
});

// Normalize username before saving and check uniqueness
ownerSchema.pre('save', async function(next) {
  if (this.isModified('username')) {
    // Remove spaces and convert to lowercase
    this.username = this.username.replace(/\s+/g, '.').toLowerCase();
    
    // Check uniqueness across all user collections
    const existingUsers = await Promise.all([
      mongoose.model('Patient').findOne({ username: this.username }),
      mongoose.model('Doctor').findOne({ username: this.username }),
      mongoose.model('Staff').findOne({ username: this.username }),
      mongoose.model('Admin').findOne({ username: this.username }),
      mongoose.model('LabOwner').findOne({ username: this.username, _id: { $ne: this._id } })
    ]);
    
    if (existingUsers.some(user => user !== null)) {
      return next(new Error('Username already exists across all user roles'));
    }
  }
  next();
});

// Hash password before saving
ownerSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

// Method to compare password
ownerSchema.methods.comparePassword = async function(password) {
  return bcrypt.compare(password, this.password);
};

// Set collection name to match existing data
ownerSchema.set('collection', 'labowners');

// Register as 'Owner' for populate compatibility
try {
  module.exports = mongoose.model('Owner');
} catch (e) {
  module.exports = mongoose.model('Owner', ownerSchema);
}

// Also register as 'LabOwner' for backward compatibility
try {
  mongoose.model('LabOwner');
} catch (e) {
  mongoose.model('LabOwner', ownerSchema);
}

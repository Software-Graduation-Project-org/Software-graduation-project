const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const adminSchema = new mongoose.Schema({
  full_name: { first: String, middle: String, last: String },
  identity_number: { type: String, unique: true },
  birthday: Date,
  gender: { type: String, enum: ['Male','Female','Other'] },
  phone_number: String,
  admin_id: { type: String, unique: true },
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
  password: String,

  // FCM Push Notification Token
  fcm_token: String,
  platform: { type: String, enum: ['android', 'ios', 'web'] },
  token_updated_at: Date
});

// Normalize username before saving and check uniqueness
adminSchema.pre('save', async function(next) {
  if (this.isModified('username')) {
    // Remove spaces and convert to lowercase
    this.username = this.username.replace(/\s+/g, '.').toLowerCase();
    
    // Check uniqueness across all user collections
    const existingUsers = await Promise.all([
      mongoose.model('Patient').findOne({ username: this.username }),
      mongoose.model('Doctor').findOne({ username: this.username }),
      mongoose.model('Staff').findOne({ username: this.username }),
      mongoose.model('LabOwner').findOne({ username: this.username }),
      mongoose.model('Admin').findOne({ username: this.username, _id: { $ne: this._id } })
    ]);
    
    if (existingUsers.some(user => user !== null)) {
      return next(new Error('Username already exists across all user roles'));
    }
  }
  next();
});

// Hash password before saving
adminSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

// Method to compare password
adminSchema.methods.comparePassword = async function(password) {
  return bcrypt.compare(password, this.password);
};

module.exports = mongoose.model('Admin', adminSchema);




// const mongoose = require('mongoose');

// const LabOwnerSchema = new mongoose.Schema({
//   owner_id: { type: Number, required: true, unique: true },
//   name: {
//     first: String,
//     middle: String,
//     last: String
//   },
//   identity_number: String,
//   birthday: Date,
//   gender: String,
//   social_status: String,
//   phone_number: String,
//   address: String,
//   qualification: String,
//   profession_license: String,
//   bank_iban: String,
//   email: String,
//   username: String,
//   password: String,
//   date_subscription: { type: Date, default: Date.now },
//   admin_id: Number,

//   // ➕ Add these two fields for subscription tracking
//   subscription_end: { type: Date },              // subscription expiry date
//   is_active: { type: Boolean, default:false }    // whether lab is active
// });

// module.exports = mongoose.model('LabOwner', LabOwnerSchema);

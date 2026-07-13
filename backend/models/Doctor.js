const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const doctorSchema = new mongoose.Schema({
  doctor_id: { type: Number, required: true, unique: true },
  name: {
    first: { type: String, required: true },
    middle: { type: String },
    last: { type: String, required: true }
  },
  identity_number: { type: String, required: true, unique: true },
  birthday: { type: Date, required: true },
  gender: { type: String, enum: ['Male', 'Female', 'Other'], required: true },
  phone_number: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  username: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  specialty: { type: String },
  license_number: { type: String },
  years_of_experience: { type: Number },

  // FCM Push Notification Token
  fcm_token: String,
  platform: { type: String, enum: ['android', 'ios', 'web'] },
  token_updated_at: Date
});

// Check username uniqueness across all user collections
doctorSchema.pre('save', async function(next) {
  if (this.isModified('username')) {
    const existingUsers = await Promise.all([
      mongoose.model('Patient').findOne({ username: this.username }),
      mongoose.model('Staff').findOne({ username: this.username }),
      mongoose.model('LabOwner').findOne({ username: this.username }),
      mongoose.model('Admin').findOne({ username: this.username }),
      mongoose.model('Doctor').findOne({ username: this.username, _id: { $ne: this._id } })
    ]);
    
    if (existingUsers.some(user => user !== null)) {
      return next(new Error('Username already exists across all user roles'));
    }
  }
  next();
});

// Hash password before saving
doctorSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

// Method to compare password
doctorSchema.methods.comparePassword = async function(password) {
  return bcrypt.compare(password, this.password);
};

module.exports = mongoose.model('Doctor', doctorSchema);

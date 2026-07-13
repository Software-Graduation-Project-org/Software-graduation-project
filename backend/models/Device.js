const mongoose = require('mongoose');

const deviceSchema = new mongoose.Schema({
  name: String,
  serial_number: { type: String, unique: true },
  cleaning_reagent: String,
  manufacturer: String,
  status: { type: String, enum: ['active','inactive','maintenance'], default: 'active' },
  staff_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Staff' },
  capacity_of_sample: Number,
  maintenance_schedule: { type: String, enum: ['daily','weekly','monthly'] },
  owner_id: { type: mongoose.Schema.Types.ObjectId, ref: 'LabOwner' }
}, {
  timestamps: true
});

const Device = mongoose.model('Device', deviceSchema);

module.exports = Device;
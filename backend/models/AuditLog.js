const mongoose = require('mongoose');

const auditLogSchema = new mongoose.Schema({
  staff_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Staff' },
  username: String,
  action: String,
  table_name: String,
  record_id: mongoose.Schema.Types.ObjectId,
  message: String,
  timestamp: { type: Date, default: Date.now },
  owner_id: { type: mongoose.Schema.Types.ObjectId, ref: 'LabOwner' }
});

module.exports = mongoose.model('AuditLog', auditLogSchema);

/**
 * Log Action Utility
 * Logs staff/user actions to the AuditLog collection
 */

const AuditLog = require('../models/AuditLog');

/**
 * Log an action to the audit log
 * @param {String} staffId - ID of the staff member performing the action
 * @param {String} username - Username of the staff member
 * @param {String} action - Description of the action performed
 * @param {String} tableName - Optional: Name of the table/model affected
 * @param {String} recordId - Optional: ID of the record affected
 * @param {String} ownerId - Optional: ID of the lab owner
 */
const logAction = async (staffId, username, action, tableName = null, recordId = null, ownerId = null) => {
  try {
    const logEntry = await AuditLog.create({
      staff_id: staffId,
      username: username,
      action: action,
      table_name: tableName,
      record_id: recordId,
      owner_id: ownerId,
      timestamp: new Date()
    });

    return logEntry;
  } catch (error) {
    // Don't throw error - logging failure shouldn't break the main operation
    return null;
  }
};

module.exports = logAction;

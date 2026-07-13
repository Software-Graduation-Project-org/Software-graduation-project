/**
 * Dae Formatting Utilities
 * Provides consistent date formatting across the application
 */

/**
 * Format date to match Flutter frontend format: "Dec 18, 2025"
 * @param {Date|string} date - Date to format
 * @returns {string} - Formatted date string
 */
function formatDate(date) {
  if (!date) return 'N/A';

  const dateObj = new Date(date);
  if (isNaN(dateObj.getTime())) return 'N/A';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  const month = months[dateObj.getMonth()];
  const day = dateObj.getDate();
  const year = dateObj.getFullYear();

  return `${month} ${day}, ${year}`;
}

/**
 * Format date with time: "Dec 18, 2025 02:30 PM"
 * @param {Date|string} date - Date to format
 * @returns {string} - Formatted date and time string
 */
function formatDateTime(date) {
  if (!date) return 'N/A';

  const dateObj = new Date(date);
  if (isNaN(dateObj.getTime())) return 'N/A';

  const dateStr = formatDate(dateObj);
  const hours = dateObj.getHours();
  const minutes = dateObj.getMinutes().toString().padStart(2, '0');
  const ampm = hours >= 12 ? 'PM' : 'AM';
  const displayHours = hours % 12 || 12;

  return `${dateStr} ${displayHours}:${minutes} ${ampm}`;
}

/**
 * Format date for ISO string (yyyy-MM-dd)
 * @param {Date|string} date - Date to format
 * @returns {string} - ISO date string
 */
function formatISODate(date) {
  if (!date) return 'N/A';

  const dateObj = new Date(date);
  if (isNaN(dateObj.getTime())) return 'N/A';

  return dateObj.toISOString().split('T')[0];
}

module.exports = {
  formatDate,
  formatDateTime,
  formatISODate
};
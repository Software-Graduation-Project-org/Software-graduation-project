/**
 * Address Helper Utilit
 * Converts various address formats to the standardized addressSchema format
 */

/**
 * Convert string address to addressSchema object format
 * @param {String|Object} address - Address in string or object format
 * @returns {Object} Standardized address object
 */
function normalizeAddress(address) {
  // If already an object with required fields, return as-is
  if (address && typeof address === 'object' && !Array.isArray(address)) {
    return address;
  }

  // If string, convert to object format
  if (typeof address === 'string') {
    const addressParts = address.split(',').map(part => part.trim());
    
    return {
      street: addressParts.length > 2 ? addressParts[0] : '',
      city: addressParts.length >= 2 ? addressParts[0] : '',
      state: addressParts.length > 2 ? addressParts[1] : '',
      country: addressParts[addressParts.length - 1] || 'Palestine',
      full_address: address
    };
  }

  // If null or undefined, return empty address
  return {
    street: '',
    city: '',
    state: '',
    country: 'Palestine',
    full_address: ''
  };
}

module.exports = { normalizeAddress };

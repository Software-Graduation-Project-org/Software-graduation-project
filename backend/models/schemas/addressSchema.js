const mongoose = require('mongoose');

// Standardized address schema for consistent location data across all models
const addressSchema = new mongoose.Schema({
  street: { 
    type: String,
    trim: true
  },
  city: { 
    type: String,
    trim: true
  },
  country: { 
    type: String,
    default: 'Palestine',
    trim: true
  }
}, { _id: false });

// Virtual to get formatted address
addressSchema.virtual('formatted').get(function() {
  const parts = [];
  if (this.street) parts.push(this.street);
  if (this.city) parts.push(this.city);
  if (this.country && this.country !== 'Palestine') parts.push(this.country);
  
  return parts.join(', ') || 'No address provided';
});

module.exports = addressSchema;

const mongoose = require('mongoose');

const invoiceSchema = new mongoose.Schema({
  invoice_id: { type: String, unique: true },
  order_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Order' },
  invoice_date: { type: Date, default: Date.now },
  subtotal: Number,
  discount: { type: Number, default: 0 },
  total_amount: Number,
  amount_paid: { type: Number, default: 0 }, // Track how much has been paid
  payment_status: { type: String, enum: ['pending','paid','partial'], default: 'pending' },
  payment_method: { type: String, enum: ['cash','card','bank_transfer'] },
  payment_date: { type: Date }, // When payment was received
  paid_by: { type: mongoose.Schema.Types.ObjectId, ref: 'Staff' }, // Staff who recorded payment
  remarks: String,
  owner_id: { type: mongoose.Schema.Types.ObjectId, ref: 'LabOwner' },
  items: [{
    test_id: { type: mongoose.Schema.Types.ObjectId, ref: 'TestManagement' },
    test_name: String,
    price: Number,
    quantity: { type: Number, default: 1 }
  }]
});

module.exports = mongoose.model('Invoices', invoiceSchema);

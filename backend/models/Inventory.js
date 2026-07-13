const mongoose = require('mongoose');

const inventorySchema = new mongoose.Schema({
  name: String,
  item_code: String,
  cost: Number,
  expiration_date: Date,
  critical_level: Number,
  count: Number,
  balance: Number,
  owner_id: { type: mongoose.Schema.Types.ObjectId, ref: 'LabOwner' }
});

const stockInputSchema = new mongoose.Schema({
  item_id: { type: mongoose.Schema.Types.ObjectId, ref: 'StockInventory' },
  input_value: Number,
  input_date: { type: Date, default: Date.now }
});

const stockOutputSchema = new mongoose.Schema({
  item_id: { type: mongoose.Schema.Types.ObjectId, ref: 'StockInventory' },
  output_value: Number,
  out_date: { type: Date, default: Date.now }
});

const Inventory = mongoose.model('StockInventory', inventorySchema);
const StockInput = mongoose.model('StockInput', stockInputSchema);
const StockOutput = mongoose.model('StockOutput', stockOutputSchema);

module.exports = {
  Inventory,
  StockInput,
  StockOutput
};

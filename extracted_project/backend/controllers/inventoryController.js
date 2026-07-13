const { StockInventory, StockOutput } = require('../models/Inventory');
const Staff = require('../models/Staff');
const logAction = require('../utils/logAction');

/**
 * Staff inventory usage (StockOutput) controller
 */
exports.recordStockUsage = async (req, res) => {
  try {
    const { staff_id, item_id, quantity } = req.body;

    // Validation
    if (!staff_id || !item_id || !quantity) {
      return res.status(400).json({ message: "staff_id, item_id, and quantity are required" });
    }

    if (quantity >= 0) {
      return res.status(403).json({ message: "Staff can only record stock usage (negative quantity)" });
    }

    // Fetch staff to get their owner_id
    const staff = await Staff.findById(staff_id);
    if (!staff) return res.status(404).json({ message: "Staff not found" });

    // Fetch inventory item
    const item = await StockInventory.findById(item_id);
    if (!item) return res.status(404).json({ message: "Inventory item not found" });

    // Check ownership
    if (item.owner_id.toString() !== staff.owner_id.toString()) {
      return res.status(403).json({ message: "Cannot modify inventory from another lab" });
    }

    const usedQuantity = Math.abs(quantity);

    // Check stock availability
    if (item.count < usedQuantity) {
      return res.status(400).json({ message: "Insufficient stock for usage" });
    }

    // Record stock usage
    await StockOutput.create({
      item_id,
      output_value: usedQuantity,
      out_date: new Date()
    });

    // Update inventory count
    item.count -= usedQuantity;
    await item.save();

    // Log action
    await logAction(staff_id, staff.username, `Stock Used: ${usedQuantity} of ${item.name}`, 'StockInventory', item._id, staff.owner_id);

    res.json({ message: "Stock usage recorded successfully", item });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: err.message });
  }
};

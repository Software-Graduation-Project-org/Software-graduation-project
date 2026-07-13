const OrderDetail = require('../models/OrderDetails');
const Test = require('../models/Test');
const Invoice = require('../models/Invoices');
const Order = require('../models/Order');
const Notification = require('../models/Notification');
const logAction = require('../utils/logAction');




// ✅ Apply Discount to an Invoice
exports.applyDiscount = async (req, res) => {
  try {
    const { invoiceId } = req.params;
    const { discount } = req.body;

    const invoice = await Invoice.findById(invoiceId);
    if (!invoice) return res.status(404).json({ message: "Invoice not found" });

    invoice.discount = discount;
    invoice.total_amount = invoice.subtotal - discount;
    await invoice.save();

    const Staff = require('../models/Staff');
    const loggingStaff = await Staff.findById(req.user?._id).select('username');

    await logAction(req.user?._id, loggingStaff.username, `Applied discount of ${discount} to invoice ${invoiceId}`);

    res.json({ message: "Discount applied", invoice });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

/**
 * @desc    Record payment (Staff marks invoice as paid when patient pays at lab)
 * @route   POST /api/invoice/record-payment
 * @access  Private (Staff/Owner)
 */
exports.recordPayment = async (req, res) => {
  try {
    const { invoice_id, payment_method, amount_paid, remarks } = req.body;
    const staff_id = req.user.id;

    // Validate inputs
    if (!invoice_id || !payment_method || !amount_paid) {
      return res.status(400).json({ 
        message: "invoice_id, payment_method, and amount_paid are required" 
      });
    }

    if (!['cash', 'card', 'bank_transfer'].includes(payment_method)) {
      return res.status(400).json({ 
        message: "payment_method must be: cash, card, or bank_transfer" 
      });
    }

    // Find invoice with order and patient info
    const invoice = await Invoice.findById(invoice_id)
      .populate({
        path: 'order_id',
        populate: { path: 'patient_id', select: 'full_name email' }
      });

    if (!invoice) {
      return res.status(404).json({ message: "Invoice not found" });
    }

    // Validate payment amount
    if (amount_paid <= 0) {
      return res.status(400).json({ message: "Payment amount must be greater than 0" });
    }

    // Calculate payment status
    const totalDue = invoice.total_amount;
    const previouslyPaid = invoice.amount_paid || 0;
    const remainingBalance = totalDue - previouslyPaid;



    const totalPaid = previouslyPaid + amount_paid;
    
    let paymentStatus;
    if (totalPaid >= totalDue) {
      paymentStatus = 'paid';
    } else {
      paymentStatus = 'partial';
    }

    // Use atomic operation to prevent race conditions
    // Multiple staff members could try to record payment simultaneously
    const updateQuery = {
      payment_status: paymentStatus,
      payment_method: payment_method,
      paid_by: staff_id,
      payment_date: new Date(),
      $inc: { amount_paid: amount_paid }  // Atomic increment
    };
    
    if (remarks) {
      updateQuery.remarks = remarks;
    }
    
    const updatedInvoice = await Invoice.findByIdAndUpdate(
      invoice_id,
      updateQuery,
      { new: true, runValidators: true }
    );

    // Update order status to completed if fully paid
    if (paymentStatus === 'paid' && updatedInvoice.order_id) {
      await Order.findByIdAndUpdate(updatedInvoice.order_id._id, {
        status: 'completed'
      });
    }

    // Re-fetch invoice with populated fields for notification
    const invoiceWithDetails = await Invoice.findById(invoice_id)
      .populate({
        path: 'order_id',
        populate: { path: 'patient_id', select: 'full_name email' }
      });

    // Send notification to patient
    if (invoiceWithDetails.order_id && invoiceWithDetails.order_id.patient_id) {
      await Notification.create({
        sender_id: staff_id,
        sender_model: 'Staff',
        receiver_id: invoiceWithDetails.order_id.patient_id._id,
        receiver_model: 'Patient',
        type: 'payment',
        title: paymentStatus === 'paid' ? '✅ Payment Received' : '💰 Partial Payment Received',
        message: paymentStatus === 'paid' 
          ? `Your payment of ${amount_paid} has been received. Invoice is now fully paid. Thank you!`
          : `Partial payment of ${amount_paid} received. Remaining balance: ${totalDue - totalPaid}`,
        related_id: updatedInvoice._id
      });
    }

    // Log action
    const loggingStaff = await Staff.findById(staff_id).select('username');
    await logAction(
      staff_id,
      loggingStaff.username,
      `Recorded payment of ${amount_paid} (${payment_method}) for invoice ${updatedInvoice._id}`,
      'Invoice',
      updatedInvoice._id,
      updatedInvoice.owner_id
    );

    res.json({
      success: true,
      message: `Payment recorded successfully (${paymentStatus})`,
      invoice: {
        _id: updatedInvoice._id,
        payment_status: updatedInvoice.payment_status,
        payment_method: updatedInvoice.payment_method,
        amount_paid: updatedInvoice.amount_paid,
        total_amount: updatedInvoice.total_amount,
        balance: totalDue - updatedInvoice.amount_paid,
        payment_date: updatedInvoice.payment_date
      }
    });

  } catch (err) {
    console.error("Error recording payment:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get invoice details with order and tests
 * @route   GET /api/invoice/:invoice_id
 * @access  Private (Staff/Patient/Owner)
 */
exports.getInvoice = async (req, res) => {
  try {
    const { invoice_id } = req.params;

    const invoice = await Invoice.findById(invoice_id)
      .populate({
        path: 'order_id',
        populate: { path: 'patient_id', select: 'full_name patient_id email phone_number' }
      })
      .populate('owner_id', 'name address phone_number email');

    if (!invoice) {
      return res.status(404).json({ message: "Invoice not found" });
    }

    // Get order details (tests)
    const details = await OrderDetail.find({ order_id: invoice.order_id._id })
      .populate('test_id', 'test_name test_code price');

    res.json({
      success: true,
      invoice,
      tests: details.map(d => ({
        test_name: d.test_id?.test_name,
        test_code: d.test_id?.test_code,
        price: d.test_id?.price
      })),
      patient: invoice.order_id?.patient_id ? {
        name: `${invoice.order_id.patient_id.full_name.first} ${invoice.order_id.patient_id.full_name.last}`,
        patient_id: invoice.order_id.patient_id.patient_id,
        email: invoice.order_id.patient_id.email,
        phone: invoice.order_id.patient_id.phone_number
      } : null
    });

  } catch (err) {
    console.error("Error fetching invoice:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get all unpaid invoices (for lab dashboard/finance tracking)
 * @route   GET /api/invoice/unpaid
 * @access  Private (Owner/Staff)
 */
exports.getUnpaidInvoices = async (req, res) => {
  try {
    const owner_id = req.user.ownerId;

    const unpaidInvoices = await Invoice.find({
      owner_id,
      payment_status: { $in: ['pending', 'partial'] }
    })
    .populate({
      path: 'order_id',
      populate: { path: 'patient_id', select: 'full_name patient_id phone_number' }
    })
    .sort({ invoice_date: 1 }); // Oldest first

    const summary = {
      total_unpaid_invoices: unpaidInvoices.length,
      total_amount_due: unpaidInvoices.reduce((sum, inv) => {
        const paid = inv.amount_paid || 0;
        return sum + (inv.total_amount - paid);
      }, 0)
    };

    res.json({
      success: true,
      summary,
      invoices: unpaidInvoices.map(inv => ({
        invoice_id: inv._id,
        patient_name: inv.order_id?.patient_id 
          ? `${inv.order_id.patient_id.full_name.first} ${inv.order_id.patient_id.full_name.last}`
          : 'Unknown',
        patient_id: inv.order_id?.patient_id?.patient_id,
        phone: inv.order_id?.patient_id?.phone_number,
        total_amount: inv.total_amount,
        amount_paid: inv.amount_paid || 0,
        balance: inv.total_amount - (inv.amount_paid || 0),
        payment_status: inv.payment_status,
        invoice_date: inv.invoice_date,
        days_overdue: Math.floor((Date.now() - inv.invoice_date) / (1000 * 60 * 60 * 24))
      }))
    });

  } catch (err) {
    console.error("Error fetching unpaid invoices:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Send Invoice Report to Patient
 * @route   POST /api/invoice/send-report/:invoiceId
 * @access  Private (Staff/Owner)
 */
exports.sendInvoiceReport = async (req, res) => {
  try {
    const { invoiceId } = req.params;

    // Find invoice with populated data
    const invoice = await Invoice.findById(invoiceId)
      .populate({
        path: 'order_id',
        populate: {
          path: 'patient_id',
          select: 'full_name patient_id phone_number email'
        }
      })
      .populate('owner_id', 'lab_name address phone_number')
      .populate({
        path: 'items.test_id',
        select: 'test_name price'
      });

    if (!invoice) {
      return res.status(404).json({ message: "Invoice not found" });
    }

    if (!invoice.order_id?.patient_id) {
      return res.status(400).json({ message: "Patient information not found for this invoice" });
    }

    const patient = invoice.order_id.patient_id;
    const labName = invoice.owner_id?.lab_name || 'Medical Lab';

    // Create invoice URL for online viewing
    const invoiceUrl = `${process.env.FRONTEND_URL || 'http://localhost:8080'}/patient-dashboard/invoice/${invoice._id}`;

    // Prepare invoice data for PDF generation
    const invoiceData = {
      invoice_id: invoice.invoice_id,
      created_at: invoice.created_at,
      status: invoice.status,
      subtotal: invoice.subtotal || 0,
      discount: invoice.discount || 0,
      total_amount: invoice.total_amount || 0,
      lab: {
        name: labName,
        address: invoice.owner_id?.address || 'N/A',
        phone_number: invoice.owner_id?.phone_number || 'N/A'
      },
      patient: {
        name: `${patient.full_name?.first || ''} ${patient.full_name?.last || ''}`.trim(),
        patient_id: patient.patient_id
      },
      tests: invoice.items?.map(item => ({
        test_name: item.test_id?.test_name || 'Unknown Test',
        price: item.price || 0,
        quantity: item.quantity || 1
      })) || [],
      payments: invoice.payments || []
    };

    // Import the notification utility
    const { sendInvoiceReport: sendInvoiceNotification } = require('../utils/sendNotification');

    // Send the invoice report
    const notificationResult = await sendInvoiceNotification(
      patient,
      invoiceData,
      invoiceUrl,
      labName
    );

    // Log the action
    const Staff = require('../models/Staff');
    const loggingStaff = await Staff.findById(req.user?._id).select('username');
    await logAction(req.user?._id, loggingStaff.username, `Sent invoice report ${invoice.invoice_id} to patient ${patient.full_name?.first} ${patient.full_name?.last}`);

    res.json({
      message: "Invoice report sent successfully",
      notification: notificationResult
    });

  } catch (error) {
    console.error("Error sending invoice report:", error);
    res.status(500).json({ message: error.message });
  }
};

const Patient = require('../models/Patient');
const Order = require('../models/Order');
const OrderDetails = require('../models/OrderDetails');
const Result = require('../models/Result');
const Test = require('../models/Test');
const Notification = require('../models/Notification');
const Invoice = require('../models/Invoices');
const Feedback = require('../models/Feedback');
const LabOwner = require('../models/Owner');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const sendEmail = require('../utils/sendEmail');
const sendSMS = require('../utils/sendSMS');

// ==================== AUTHENTICATION ====================

/**
 * @desc    Patient Login
 * @route   POST /api/patient/login
 * @access  Public
 */
exports.login = async (req, res, next) => {
  try {
    const { username, password } = req.body;

    // Validate input
    if (!username || !password) {
      return res.status(400).json({ message: '⚠️ Username and password are required' });
    }

    // Find patient by username or email
    const patient = await Patient.findOne({
      $or: [{ username }, { email: username }]
    });

    if (!patient) {
      return res.status(401).json({ message: '❌ Invalid credentials' });
    }

    // Compare password
    const isMatch = await patient.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ message: '❌ Invalid credentials' });
    }

    // Update last login
    patient.last_login = new Date();
    await patient.save();

    // Generate JWT token
    const token = jwt.sign(
      { 
        _id: patient._id, 
        patient_id: patient.patient_id,
        role: 'patient',
        username: patient.username 
      },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      message: '✅ Login successful',
      token,
      patient: {
        _id: patient._id,
        patient_id: patient.patient_id,
        full_name: patient.full_name,
        identity_number: patient.identity_number,
        birthday: patient.birthday,
        gender: patient.gender,
        insurance_provider: patient.insurance_provider,
        insurance_number: patient.insurance_number,
        email: patient.email,
        username: patient.username
      }
    });
  } catch (err) {
    next(err);
  }
};

// ==================== PROFILE MANAGEMENT ====================

/**
 * @desc    Get Patient Profile
 * @route   GET /api/patient/profile
 * @access  Private (Patient)
 */
exports.getProfile = async (req, res, next) => {
  try {
    const patient = await Patient.findById(req.user._id).select('-password');
    
    if (!patient) {
      return res.status(404).json({ message: '❌ Patient not found' });
    }

    res.json(patient);
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update Patient Profile
 * @route   PUT /api/patient/profile
 * @access  Private (Patient)
 */
exports.updateProfile = async (req, res, next) => {
  try {
    const {
      name,
      phone_number,
      address,
      email,
      identity_number,
      social_status,
      insurance_provider,
      insurance_number
    } = req.body;

    const patient = await Patient.findById(req.user._id);
    if (!patient) {
      return res.status(404).json({ message: '❌ Patient not found' });
    }

    // Update allowed fields
    if (name) {
      patient.full_name = {
        first: name.first || patient.full_name.first,
        middle: name.middle || patient.full_name.middle,
        last: name.last || patient.full_name.last
      };
    }
    if (phone_number) patient.phone_number = phone_number;
    if (address) {
      // Ensure only schema fields are used
      patient.address = {
        street: address.street || patient.address?.street || '',
        city: address.city || patient.address?.city || '',
        country: address.country || patient.address?.country || 'Palestine'
      };
    }
    if (email) patient.email = email;
    if (identity_number) patient.identity_number = identity_number;
    if (social_status) patient.social_status = social_status;
    if (insurance_provider) patient.insurance_provider = insurance_provider;
    if (insurance_number) patient.insurance_number = insurance_number;

    await patient.save();

    res.json({ 
      message: '✅ Profile updated successfully', 
      patient: await Patient.findById(patient._id).select('-password')
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Change Password
 * @route   PUT /api/patient/change-password
 * @access  Private (Patient)
 */
exports.changePassword = async (req, res, next) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ message: '⚠️ Current password and new password are required' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ message: '⚠️ New password must be at least 6 characters' });
    }

    const patient = await Patient.findById(req.user._id);
    if (!patient) {
      return res.status(404).json({ message: '❌ Patient not found' });
    }

    // Verify current password
    const isMatch = await patient.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(401).json({ message: '❌ Current password is incorrect' });
    }

    // Update password
    patient.password = newPassword;
    await patient.save();

    res.json({ message: '✅ Password changed successfully' });
  } catch (err) {
    next(err);
  }
};

// ==================== TEST ORDERS ====================

/**
 * @desc    Get All Patient Orders
 * @route   GET /api/patient/orders
 * @access  Private (Patient)
 */
exports.getMyOrders = async (req, res, next) => {
  try {
    const { status } = req.query;

    const query = { patient_id: req.user._id };
    if (status) {
      query.status = status;
    }

    const orders = await Order.find(query)
      .populate('requested_by', 'full_name employee_number')
      .populate('doctor_id', 'name')
      .populate('owner_id', 'name')
      .sort({ order_date: -1 });

    // Get order details for each order
    const ordersWithDetails = await Promise.all(
      orders.map(async (order) => {
        const details = await OrderDetails.find({ order_id: order._id })
          .populate('test_id', 'test_name test_code price')
          .populate('staff_id', 'full_name');
        
        return {
          ...order.toObject(),
          details
        };
      })
    );

    res.json({ count: ordersWithDetails.length, orders: ordersWithDetails });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Order Details
 * @route   GET /api/patient/orders/:orderId
 * @access  Private (Patient)
 */
exports.getOrderById = async (req, res, next) => {
  try {
    const order = await Order.findOne({
      _id: req.params.orderId,
      patient_id: req.user._id
    })
      .populate('requested_by', 'full_name employee_number')
      .populate('doctor_id', 'name')
      .populate('owner_id', 'name');

    if (!order) {
      return res.status(404).json({ message: '❌ Order not found' });
    }

    // Get order details
    const details = await OrderDetails.find({ order_id: order._id })
      .populate('test_id', 'test_name test_code price sample_type')
      .populate('staff_id', 'full_name');

    // Get invoice - try multiple ways to find it
    let invoice = await Invoice.findOne({ order_id: order._id });
    
    // If not found, try with string comparison
    if (!invoice) {
      invoice = await Invoice.findOne({ order_id: order._id.toString() });
    }
    
    // If still not found, try finding any invoice for this patient that might be related
    if (!invoice) {
      const allInvoices = await Invoice.find({}).populate('order_id');
      invoice = allInvoices.find(inv => inv.order_id && inv.order_id._id.toString() === order._id.toString());
    }

    res.json({
      order,
      details,
      invoice
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Request New Tests (Self-Request)
 * @route   POST /api/patient/request-tests
 * @access  Private (Patient)
 */
exports.requestTests = async (req, res, next) => {
  const mongoose = require('mongoose');
  const session = await mongoose.startSession();
  
  try {
    // Start transaction to ensure atomicity
    session.startTransaction();
    
    const { owner_id, test_ids, remarks, doctor_id } = req.body;

    // Validate input
    if (!owner_id || !test_ids || test_ids.length === 0) {
      await session.abortTransaction();
      return res.status(400).json({ message: '⚠️ Lab and tests are required' });
    }

    // Verify tests exist and belong to the specified lab
    const tests = await Test.find({ 
      _id: { $in: test_ids },
      owner_id: owner_id 
    }).session(session);

    if (tests.length !== test_ids.length) {
      await session.abortTransaction();
      return res.status(400).json({ message: '⚠️ Some tests are invalid or not available in this lab' });
    }

    // If doctor_id provided, verify doctor exists
    let doctor = null;
    if (doctor_id) {
      const Doctor = require('../models/Doctor');
      doctor = await Doctor.findById(doctor_id).session(session);
      if (!doctor) {
        await session.abortTransaction();
        return res.status(404).json({ message: '⚠️ Selected doctor not found' });
      }
    }

    // Create order (within transaction)
    const [newOrder] = await Order.create([{
      patient_id: req.user._id,
      requested_by: req.user._id, // Self-requested by patient
      requested_by_model: 'Patient',
      doctor_id: doctor_id || null, // Link to doctor if provided
      order_date: new Date(),
      status: 'processing',
      remarks: remarks,
      owner_id,
      is_patient_registered: true
    }], { session });

    // Create order details for each test (within transaction)
    const orderDetails = test_ids.map(test_id => ({
      order_id: newOrder._id,
      test_id,
      status: 'pending',
      sample_collected: false
    }));

    await OrderDetails.insertMany(orderDetails, { session });

    // Calculate invoice
    const subtotal = tests.reduce((sum, test) => sum + (test.price || 0), 0);
    
    // Generate invoice ID
    const invoiceCount = await Invoice.countDocuments();
    const invoiceId = `INV-${String(invoiceCount + 1).padStart(6, '0')}`;
    
    // Create invoice (within transaction)
    const [invoice] = await Invoice.create([{
      invoice_id: invoiceId,
      order_id: newOrder._id,
      invoice_date: new Date(),
      subtotal,
      discount: 0,
      total_amount: subtotal,
      payment_status: 'paid', // Mark as paid initially
      payment_method: 'cash', // Default payment method
      payment_date: new Date(),
      paid_by: req.user._id,
      owner_id,
      items: tests.map(t => ({
        test_id: t._id,
        test_name: t.test_name,
        price: t.price,
        quantity: 1
      }))
    }], { session });

    // Send invoice notification to patient
    await Notification.create([{
      sender_id: req.user._id,
      sender_model: 'Patient',
      receiver_id: req.user._id,
      receiver_model: 'Patient',
      type: 'payment',
      title: 'Invoice Generated',
      message: `Your invoice for order has been generated. Total: ${subtotal} ILS. Payment status: Paid.`
    }], { session });

    // Send notification to lab owner (within transaction)
    await Notification.create([{
      sender_id: req.user._id,
      sender_model: 'Patient',
      receiver_id: owner_id,
      receiver_model: 'Owner',
      type: 'system',
      title: 'New Test Request',
      message: `Patient ${req.user.full_name.first} ${req.user.full_name.last} has requested ${test_ids.length} test(s).`
    }], { session });

    // If doctor is linked to this order, notify them too
    if (doctor_id) {
      await Notification.create([{
        sender_id: req.user._id,
        sender_model: 'Patient',
        receiver_id: doctor_id,
        receiver_model: 'Doctor',
        type: 'system',
        title: 'Patient Test Request',
        message: `${req.user.full_name.first} ${req.user.full_name.last} has requested ${test_ids.length} test(s).`
      }], { session });
    }

    // Notify the patient that their order has been created
    await Notification.create([{
      sender_id: owner_id,
      sender_model: 'Owner',
      receiver_id: req.user._id,
      receiver_model: 'Patient',
      type: 'order_created',
      title: 'Order Created Successfully',
      message: `Your test order has been created at ${lab.lab_name}. ${test_ids.length} test(s) are now being processed.`
    }], { session });

    // Commit transaction - all operations succeeded
    await session.commitTransaction();

    // Get lab and patient details for email
    const LabOwner = require('../models/Owner');
    const lab = await LabOwner.findById(owner_id);
    const patient = await Patient.findById(req.user._id);

    // Send confirmation email and SMS
    const emailSubject = `Test Order Confirmation - ${lab.lab_name}`;
    const emailMessage = `
Hello ${patient.full_name.first},

Your test order has been submitted successfully!

Lab: ${lab.lab_name}
Tests: ${tests.map(t => t.test_name).join(', ')}
Total Cost: ${subtotal} ILS

Next Steps:
1. Visit ${lab.lab_name} for sample collection
2. Bring your ID for verification
3. Results will be available in your account after processing

Lab Contact: ${lab.phone_number}

Best regards,
MedLab System
    `;

    await sendEmail(patient.email, emailSubject, emailMessage);
    await sendSMS(patient.phone_number, `Your test order at ${lab.lab_name} is confirmed. ${tests.length} test(s), Total: ${subtotal} ILS. Visit lab for sample collection.`);

    res.status(201).json({
      message: `✅ Test request submitted successfully. Confirmation sent to your email and phone.`,
      order: await Order.findById(newOrder._id).populate('owner_id', 'lab_name').populate('doctor_id', 'name'),
      invoice,
      doctor_notified: doctor_id ? true : false
    });
  } catch (err) {
    // Rollback transaction on error
    await session.abortTransaction();
    next(err);
  } finally {
    // End session
    session.endSession();
  }
};

// ==================== TEST RESULTS ====================

/**
 * @desc    Get Order Summaries with Results
 * @route   GET /api/patient/orders-with-results
 * @access  Private (Patient)
 */
exports.getOrdersWithResults = async (req, res, next) => {
  try {
    // Get all patient's orders
    const orders = await Order.find({ patient_id: req.user._id })
      .populate('doctor_id', 'name')
      .sort({ order_date: -1 });

    // Get order summaries with test count and status
    const orderSummaries = await Promise.all(
      orders.map(async (order) => {
        const details = await OrderDetails.find({ order_id: order._id })
          .populate('test_id', 'test_name');

        const completedCount = details.filter(d => d.status === 'completed').length;
        const inProgressCount = details.filter(d => d.status === 'in_progress').length;
        const pendingCount = details.filter(d => d.status === 'pending').length;

        // Get doctor name if available
        const doctorName = order.doctor_id?.name
          ? `Dr. ${order.doctor_id.name.first} ${order.doctor_id.name.middle || ''} ${order.doctor_id.name.last}`.trim()
          : null;

        return {
          order_id: order._id,
          order_date: order.order_date,
          doctor_name: doctorName,
          test_count: details.length,
          completed_tests: completedCount,
          in_progress_tests: inProgressCount,
          pending_tests: pendingCount,
          status: order.status,
          has_results: completedCount > 0
        };
      })
    );

    res.json({ count: orderSummaries.length, orders: orderSummaries });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get All Test Results for Specific Order
 * @route   GET /api/patient/orders/:orderId/results
 * @access  Private (Patient)
 */
exports.getOrderResults = async (req, res, next) => {
  try {
    // Verify order belongs to patient
    const order = await Order.findOne({
      _id: req.params.orderId,
      patient_id: req.user._id
    })
      .populate('doctor_id', 'name')
      .populate('owner_id', 'lab_name name address phone_number');

    if (!order) {
      return res.status(404).json({ message: '❌ Order not found' });
    }

    // Get order details with results
    const details = await OrderDetails.find({ order_id: order._id })
      .populate('test_id', 'test_name test_code reference_range units')
      .populate('staff_id', 'full_name')
      .sort({ createdAt: 1 });

    // Get results for completed tests
    const detailIds = details
      .filter(d => d.status === 'completed')
      .map(d => d._id);
    const results = await Result.find({ detail_id: { $in: detailIds } });

    // Get components for tests that have them
    const resultsWithComponents = results.filter(r => r.has_components);
    const resultIds = resultsWithComponents.map(r => r._id);
    const ResultComponent = require('../models/ResultComponent');
    const components = await ResultComponent.find({ result_id: { $in: resultIds } })
      .populate('component_id')
      .sort({ 'component_id.display_order': 1 });

    // Combine details with results and components
    const resultsWithDetails = details.map(detail => {
      const result = detail.status === 'completed' 
        ? results.find(r => r.detail_id.toString() === detail._id.toString())
        : null;
      
      let componentsForTest = [];
      if (result && result.has_components) {
        componentsForTest = components
          .filter(c => c.result_id.toString() === result._id.toString())
          .map(c => ({
            component_name: c.component_name,
            component_value: c.component_value,
            units: c.units,
            reference_range: c.reference_range,
            is_abnormal: c.is_abnormal,
            remarks: c.remarks
          }));
      }
      
      return {
        detail_id: detail._id,
        test_name: detail.test_id?.test_name || 'Unknown Test',
        test_code: detail.test_id?.test_code || 'N/A',
        status: detail.status,
        test_result: result?.result_value || (detail.status === 'in_progress' ? 'In Progress' : 'Pending'),
        units: result?.units || detail.test_id?.units || 'N/A',
        reference_range: detail.test_id?.reference_range || 'N/A',
        remarks: result?.remarks || null,
        createdAt: result?.createdAt || detail.createdAt,
        staff: detail.staff_id,
        result: result || null,
        has_components: result?.has_components || false,
        components: componentsForTest
      };
    });

    // Get doctor name if available
    const doctorName = order.doctor_id?.name
      ? `Dr. ${order.doctor_id.name.first} ${order.doctor_id.name.middle || ''} ${order.doctor_id.name.last}`.trim()
      : null;

    // Get lab name and address if available
    const labName = order.owner_id?.lab_name || 'Medical Laboratory';
    const labAddress = order.owner_id?.address
      ? `${order.owner_id.address.street || ''}, ${order.owner_id.address.city || ''}, ${order.owner_id.address.state || ''} ${order.owner_id.address.postal_code || ''}`.trim().replace(/^,\s*/, '').replace(/,\s*$/, '')
      : null;
    const labPhone = order.owner_id?.phone_number || null;

    res.json({
      order: {
        order_id: order._id,
        order_date: order.order_date,
        doctor_name: doctorName,
        lab_name: labName,
        lab_address: labAddress,
        lab_phone: labPhone,
        status: order.status
      },
      results: resultsWithDetails,
      count: resultsWithDetails.length
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get All Test Results (Legacy - for backward compatibility)
 * @route   GET /api/patient/results
 * @access  Private (Patient)
 */
exports.getMyResults = async (req, res, next) => {
  try {
    const ResultComponent = require('../models/ResultComponent');
    
    // Get all patient's orders
    const orders = await Order.find({ patient_id: req.user._id });
    const orderIds = orders.map(o => o._id);

    // Get completed and in-progress order details
    const activeDetails = await OrderDetails.find({
      order_id: { $in: orderIds },
      status: { $in: ['in_progress', 'completed'] }
    })
      .populate({
        path: 'order_id',
        populate: { path: 'doctor_id', select: 'name' }
      })
      .populate('test_id', 'test_name test_code reference_range units')
      .populate('staff_id', 'full_name')
      .sort({ 'order_id.order_date': -1 });

    // Get results for these details (only for completed tests)
    const detailIds = activeDetails
      .filter(d => d.status === 'completed')
      .map(d => d._id);
    const results = await Result.find({ detail_id: { $in: detailIds } })
      .populate('detail_id');

    // Get all result IDs for component lookup
    const resultIds = results.map(r => r._id);
    const componentCounts = await ResultComponent.aggregate([
      { $match: { result_id: { $in: resultIds } } },
      { $group: { _id: '$result_id', count: { $sum: 1 }, abnormalCount: { $sum: { $cond: ['$is_abnormal', 1, 0] } } } }
    ]);
    const componentCountMap = new Map(componentCounts.map(c => [c._id.toString(), c]));

    // Combine details with results
    const resultsWithDetails = activeDetails.map(detail => {
      const result = detail.status === 'completed' 
        ? results.find(r => r.detail_id._id.toString() === detail._id.toString())
        : null;
      
      // Get doctor name if available
      const doctorName = detail.order_id?.doctor_id?.name
        ? `Dr. ${detail.order_id.doctor_id.name.first} ${detail.order_id.doctor_id.name.middle || ''} ${detail.order_id.doctor_id.name.last}`.trim()
        : null;
      
      const componentInfo = result ? componentCountMap.get(result._id.toString()) : null;
      
      return {
        order_id: detail.order_id._id,
        order_date: detail.order_id.order_date,
        doctor_name: doctorName,
        test_name: detail.test_id?.test_name || 'Unknown Test',
        test_code: detail.test_id?.test_code || 'N/A',
        status: detail.status,
        has_components: result?.has_components || false,
        component_count: componentInfo?.count || 0,
        abnormal_component_count: componentInfo?.abnormalCount || 0,
        test_result: result?.result_value || (detail.status === 'in_progress' ? 'In Progress' : 'N/A'),
        units: result?.units || detail.test_id?.units || 'N/A',
        reference_range: detail.test_id?.reference_range || 'N/A',
        remarks: result?.remarks || null,
        createdAt: result?.createdAt || detail.order_id.order_date,
        staff: detail.staff_id,
        result: result || null
      };
    });

    res.json({ count: resultsWithDetails.length, results: resultsWithDetails });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Result for Specific Test in Order
 * @route   GET /api/patient/results/:detailId
 * @access  Private (Patient)
 */
exports.getResultById = async (req, res, next) => {
  try {
    const detail = await OrderDetails.findById(req.params.detailId)
      .populate({
        path: 'order_id',
        match: { patient_id: req.user._id }
      })
      .populate('test_id')
      .populate('staff_id', 'full_name');

    if (!detail || !detail.order_id) {
      return res.status(404).json({ message: '❌ Result not found or access denied' });
    }

    if (detail.status !== 'completed') {
      return res.status(400).json({ message: '⚠️ Test is not yet completed' });
    }

    const result = await Result.findOne({ detail_id: detail._id });

    if (!result) {
      return res.status(404).json({ message: '❌ Result not available yet' });
    }

    // If result has components, fetch them
    let components = [];
    if (result.has_components) {
      const ResultComponent = require('../models/ResultComponent');
      components = await ResultComponent.find({ result_id: result._id })
        .populate('component_id')
        .sort({ 'component_id.display_order': 1 });
    }

    res.json({
      order: detail.order_id,
      test: detail.test_id,
      staff: detail.staff_id,
      result,
      components: components.map(c => ({
        component_name: c.component_name,
        component_value: c.component_value,
        units: c.units,
        reference_range: c.reference_range,
        is_abnormal: c.is_abnormal,
        remarks: c.remarks
      }))
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Download Result (as JSON - can be extended for PDF)
 * @route   GET /api/patient/results/:detailId/download
 * @access  Private (Patient)
 */
exports.downloadResult = async (req, res, next) => {
  try {
    const detail = await OrderDetails.findById(req.params.detailId)
      .populate({
        path: 'order_id',
        match: { patient_id: req.user._id },
        populate: { path: 'owner_id', select: 'name address phone_number' }
      })
      .populate('test_id')
      .populate('staff_id', 'full_name');

    if (!detail || !detail.order_id) {
      return res.status(404).json({ message: '❌ Result not found or access denied' });
    }

    const result = await Result.findOne({ detail_id: detail._id });
    if (!result) {
      return res.status(404).json({ message: '❌ Result not available yet' });
    }

    const patient = await Patient.findById(req.user._id).select('-password');

    const report = {
      lab: detail.order_id.owner_id,
      patient: {
        name: `${patient.full_name.first} ${patient.full_name.middle || ''} ${patient.full_name.last}`,
        patient_id: patient.patient_id,
        age: patient.birthday ? Math.floor((new Date() - new Date(patient.birthday)) / 31557600000) : null,
        gender: patient.gender
      },
      order: {
        date: detail.order_id.order_date
      },
      test: {
        name: detail.test_id.test_name,
        code: detail.test_id.test_code
      },
      result: {
        value: result.result_value,
        units: result.units,
        reference_range: result.reference_range,
        remarks: result.remarks
      },
      technician: detail.staff_id ? `${detail.staff_id.full_name.first} ${detail.staff_id.full_name.last}` : null,
      report_date: new Date()
    };

    res.json(report);
  } catch (err) {
    next(err);
  }
};

// ==================== MEDICAL HISTORY ====================

/**
 * @desc    Get Medical Test History
 * @route   GET /api/patient/history
 * @access  Private (Patient)
 */
exports.getTestHistory = async (req, res, next) => {
  try {
    const { startDate, endDate, lab_id } = req.query;

    const query = { patient_id: req.user._id };

    if (startDate || endDate) {
      query.order_date = {};
      if (startDate) query.order_date.$gte = new Date(startDate);
      if (endDate) query.order_date.$lte = new Date(endDate);
    }

    if (lab_id) {
      query.owner_id = lab_id;
    }

    const orders = await Order.find(query)
      .populate('owner_id', 'name address')
      .populate('doctor_id', 'name')
      .sort({ order_date: -1 });

    // Get all details and results
    const history = await Promise.all(
      orders.map(async (order) => {
        const details = await OrderDetails.find({ order_id: order._id })
          .populate('test_id', 'test_name test_code')
          .populate('staff_id', 'full_name');

        const detailsWithResults = await Promise.all(
          details.map(async (detail) => {
            if (detail.status === 'completed') {
              const result = await Result.findOne({ detail_id: detail._id });
              return { ...detail.toObject(), result };
            }
            return detail.toObject();
          })
        );

        return {
          ...order.toObject(),
          tests: detailsWithResults
        };
      })
    );

    res.json({ count: history.length, history });
  } catch (err) {
    next(err);
  }
};

// ==================== NOTIFICATIONS ====================

/**
 * @desc    Get All Notifications
 * @route   GET /api/patient/notifications
 * @access  Private (Patient)
 */
exports.getNotifications = async (req, res, next) => {
  try {
    const { unreadOnly } = req.query;
    
    const query = {
      receiver_id: req.user._id,
      receiver_model: 'Patient'
    };

    if (unreadOnly === 'true') {
      query.is_read = false;
    }

    const notifications = await Notification.find(query)
      .sort({ createdAt: -1 })
      .populate('sender_id', 'name username full_name');

    res.json({ count: notifications.length, notifications });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Mark Notification as Read
 * @route   PUT /api/patient/notifications/:notificationId/read
 * @access  Private (Patient)
 */
exports.markNotificationAsRead = async (req, res, next) => {
  try {
    const notification = await Notification.findOne({
      _id: req.params.notificationId,
      receiver_id: req.user._id,
      receiver_model: 'Patient'
    });

    if (!notification) {
      return res.status(404).json({ message: '❌ Notification not found' });
    }

    notification.is_read = true;
    await notification.save();

    res.json({ message: '✅ Notification marked as read' });
  } catch (err) {
    next(err);
  }
};

// ==================== INVOICES ====================

/**
 * @desc    Get All Invoices
 * @route   GET /api/patient/invoices
 * @access  Private (Patient)
 */
exports.getMyInvoices = async (req, res, next) => {
  try {
    const { payment_status } = req.query;

    // Get patient's orders
    const orders = await Order.find({ patient_id: req.user._id });
    const orderIds = orders.map(o => o._id);

    const query = { order_id: { $in: orderIds } };
    if (payment_status) {
      query.payment_status = payment_status;
    }

    const invoices = await Invoice.find(query)
      .populate({
        path: 'order_id',
        populate: { path: 'owner_id', select: 'name address phone_number' }
      })
      .sort({ invoice_date: -1 });

    // Add test_count to each invoice's order
    const invoicesWithTestCount = await Promise.all(
      invoices.map(async (invoice) => {
        const details = await OrderDetails.find({ order_id: invoice.order_id._id });
        invoice.order_id.test_count = details.length;
        return invoice;
      })
    );

    res.json({ count: invoicesWithTestCount.length, invoices: invoicesWithTestCount });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Invoice
 * @route   GET /api/patient/invoices/:invoiceId
 * @access  Private (Patient)
 */
exports.getInvoiceById = async (req, res, next) => {
  try {
    const invoice = await Invoice.findById(req.params.invoiceId)
      .populate({
        path: 'order_id',
        match: { patient_id: req.user._id },
        populate: { path: 'owner_id', select: 'name address phone_number' }
      });

    if (!invoice || !invoice.order_id) {
      return res.status(404).json({ message: '❌ Invoice not found or access denied' });
    }

    // Get order details
    const details = await OrderDetails.find({ order_id: invoice.order_id._id })
      .populate('test_id', 'test_name test_code price');

    res.json({
      invoice,
      tests: details
    });
  } catch (err) {
    next(err);
  }
};

// ==================== AVAILABLE LABS & TESTS & DOCTORS ====================

/**
 * @desc    Get Available Doctors (for linking to test orders)
 * @route   GET /api/patient/doctors
 * @access  Private (Patient)
 */
exports.getAvailableDoctors = async (req, res, next) => {
  try {
    const Doctor = require('../models/Doctor');
    const { search } = req.query;
    
    const query = { is_active: true };
    
    // If search term provided, search by name
    if (search && search.length >= 2) {
      query.$or = [
        { 'name.first': { $regex: search, $options: 'i' } },
        { 'name.last': { $regex: search, $options: 'i' } },
        { specialty: { $regex: search, $options: 'i' } }
      ];
    }
    
    const doctors = await Doctor.find(query)
      .select('name specialty phone_number email')
      .limit(50);

    res.json({ 
      count: doctors.length, 
      doctors: doctors.map(doc => ({
        _id: doc._id,
        name: `Dr. ${doc.name.first} ${doc.name.middle || ''} ${doc.name.last}`.trim(),
        specialty: doc.specialty,
        phone: doc.phone_number,
        email: doc.email
      }))
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Available Labs
 * @route   GET /api/patient/labs
 * @access  Private (Patient)
 */
exports.getAvailableLabs = async (req, res, next) => {
  try {
    const LabOwner = require('../models/Owner');
    
    const labs = await LabOwner.find({ 
      status: 'approved',
      is_active: true 
    }).select('name address phone_number email');

    res.json({ count: labs.length, labs });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Available Tests for a Lab
 * @route   GET /api/patient/labs/:labId/tests
 * @access  Private (Patient)
 */
exports.getLabTests = async (req, res, next) => {
  try {
    const tests = await Test.find({ 
      owner_id: req.params.labId,
      is_active: true 
    }).select('test_name test_code price sample_type turnaround_time');

    res.json({ count: tests.length, tests });
  } catch (err) {
    next(err);
  }
};

// ==================== DASHBOARD ====================

/**
 * @desc    Get Patient Dashboard
 * @route   GET /api/patient/dashboard
 * @access  Private (Patient)
 */
exports.getDashboard = async (req, res, next) => {
  try {
    // Get total orders
    const totalOrders = await Order.countDocuments({ patient_id: req.user._id });
    const processingOrders = await Order.countDocuments({ patient_id: req.user._id, status: 'processing' });
    const completedOrders = await Order.countDocuments({ patient_id: req.user._id, status: 'completed' });

    // Get orders
    const orders = await Order.find({ patient_id: req.user._id });
    const orderIds = orders.map(o => o._id);

    // Get test statistics
    const allDetails = await OrderDetails.find({ order_id: { $in: orderIds } });
    const pendingTests = allDetails.filter(d => d.status === 'pending').length;
    const inProgressTests = allDetails.filter(d => d.status === 'in_progress').length;
    const completedTests = allDetails.filter(d => d.status === 'completed').length;

    // Get recent results (last 5)
    const recentCompletedDetails = await OrderDetails.find({
      order_id: { $in: orderIds },
      status: 'completed'
    })
      .populate('test_id', 'test_name')
      .populate('order_id', 'order_date')
      .sort({ '-order_id.order_date': -1 })
      .limit(5);

    const recentResults = await Promise.all(
      recentCompletedDetails.map(async (detail) => {
        const result = await Result.findOne({ detail_id: detail._id });
        return {
          test_name: detail.test_id?.test_name,
          order_date: detail.order_id?.order_date,
          has_result: !!result
        };
      })
    );

    // Get invoices
    const invoices = await Invoice.find({ order_id: { $in: orderIds } });
    const pendingInvoices = invoices.filter(inv => inv.payment_status === 'pending').length;
    const paidInvoices = invoices.filter(inv => inv.payment_status === 'paid').length;
    const totalAmount = invoices.reduce((sum, inv) => sum + (inv.total_amount || 0), 0);
    const paidAmount = invoices
      .filter(inv => inv.payment_status === 'paid')
      .reduce((sum, inv) => sum + (inv.total_amount || 0), 0);

    // Get notifications
    const unreadNotifications = await Notification.countDocuments({
      receiver_id: req.user._id,
      receiver_model: 'Patient',
      is_read: false
    });

    const recentNotifications = await Notification.find({
      receiver_id: req.user._id,
      receiver_model: 'Patient'
    })
      .sort({ createdAt: -1 })
      .limit(5);

    res.json({
      orders: {
        total: totalOrders,
        processing: processingOrders,
        completed: completedOrders
      },
      tests: {
        pending: pendingTests,
        inProgress: inProgressTests,
        completed: completedTests,
        visibleInResults: inProgressTests + completedTests // Tests patient can see in results tab
      },
      recentResults,
      invoices: {
        pending: pendingInvoices,
        paid: paidInvoices,
        totalAmount,
        paidAmount,
        pendingAmount: totalAmount - paidAmount
      },
      notifications: {
        unread: unreadNotifications,
        recent: recentNotifications
      }
    });
  } catch (err) {
    next(err);
  }
};

// ==================== FEEDBACK ====================

/**
 * @desc    Provide Feedback on Lab, Test, or Order
 * @route   POST /api/patient/feedback
 * @access  Private (Patient)
 */
exports.provideFeedback = async (req, res, next) => {
  try {
    const { target_type, target_id, rating, message, is_anonymous } = req.body;

    // Validate required fields
    if (!target_type || !rating) {
      return res.status(400).json({ message: '⚠️ Target type and rating are required' });
    }

    // Validate target_type
    const validTargetTypes = ['lab', 'test', 'order', 'system', 'service'];
    if (!validTargetTypes.includes(target_type)) {
      return res.status(400).json({ message: '⚠️ Invalid target type. Must be lab, test, order, system, or service' });
    }

    // For non-system feedback, target_id is required
    if (target_type !== 'system' && !target_id) {
      return res.status(400).json({ message: '⚠️ Target ID is required for non-system feedback' });
    }

    // Validate rating (1-5)
    if (rating < 1 || rating > 5) {
      return res.status(400).json({ message: '⚠️ Rating must be between 1 and 5' });
    }

    // Validate target exists and patient has access (skip for system feedback)
    let targetExists = target_type === 'system';
    let targetOwnerId = null;

    if (target_type !== 'system') {
      switch (target_type) {
        case 'lab':
          const Owner = require('../models/Owner');
          const lab = await Owner.findById(target_id);
          if (lab) {
            targetExists = true;
            targetOwnerId = lab._id;
          }
          break;
        case 'test':
          const test = await Test.findById(target_id);
          if (test) {
            targetExists = true;
            targetOwnerId = test.owner_id;
          }
          break;
        case 'order':
          const order = await Order.findOne({
            _id: target_id,
            patient_id: req.user._id
          });
          if (order) {
            targetExists = true;
            targetOwnerId = order.owner_id;
          }
          break;
      }

      if (!targetExists) {
        return res.status(404).json({ message: '❌ Target not found or access denied' });
      }
    }

    // Check for 28-day cooldown (users can submit feedback every 4 weeks)
    const twentyEightDaysAgo = new Date(Date.now() - 28 * 24 * 60 * 60 * 1000);
    const lastFeedback = await Feedback.findOne({
      user_id: req.user._id,
      createdAt: { $gte: twentyEightDaysAgo }
    }).sort({ createdAt: -1 });

    if (lastFeedback) {
      const daysUntilNext = Math.ceil((lastFeedback.createdAt.getTime() + 28 * 24 * 60 * 60 * 1000 - Date.now()) / (24 * 60 * 60 * 1000));
      return res.status(429).json({
        message: `⏳ You can submit feedback again in ${daysUntilNext} days. Feedback is limited to once every 4 weeks.`
      });
    }

    // Determine target model for refPath
    let target_model = null;
    if (!['system', 'service'].includes(target_type)) {
      switch (target_type) {
        case 'lab':
          target_model = 'Owner';
          break;
        case 'test':
          target_model = 'Test';
          break;
        case 'order':
          target_model = 'Order';
          break;
      }
    }

    // Create feedback
    const feedback = new Feedback({
      user_id: req.user._id,
      user_model: 'Patient',
      target_type,
      target_id: target_type === 'system' ? null : target_id,
      target_model,
      rating,
      message: message || '',
      is_anonymous: is_anonymous || false
    });

    await feedback.save();

    // Send notification to lab owner (skip for system feedback)
    if (targetOwnerId) {
      await Notification.create({
        sender_id: req.user._id,
        sender_model: 'Patient',
        receiver_id: targetOwnerId,
        receiver_model: 'Owner',
        type: 'feedback',
        title: '⭐ New Feedback Received',
        message: `Patient ${req.user.full_name.first} ${req.user.full_name.last} provided ${rating}-star feedback on your ${target_type}`
      });
    }

    res.status(201).json({
      message: '✅ Feedback submitted successfully',
      feedback: {
        _id: feedback._id,
        rating: feedback.rating,
        message: feedback.message,
        is_anonymous: feedback.is_anonymous,
        createdAt: feedback.createdAt
      }
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get My Feedback History
 * @route   GET /api/patient/feedback
 * @access  Private (Patient)
 */
exports.getMyFeedback = async (req, res, next) => {
  try {
    const { page = 1, limit = 10, target_type } = req.query;

    const query = {
      user_id: req.user._id,
      user_model: 'Patient'
    };

    if (target_type) {
      query.target_type = target_type;
    }

    const feedback = await Feedback.find(query)
      .populate({
        path: 'target_id',
        select: 'name lab_name test_name'
      })
      .sort({ createdAt: -1 })
      .limit(limit * 1)
      .skip((page - 1) * limit);

    const total = await Feedback.countDocuments(query);

    res.json({
      success: true,
      feedbacks: feedback,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Request Invoice Report (Patient requests PDF via email/WhatsApp)
 * @route   POST /api/patient/invoices/:invoiceId/send-report
 * @access  Private (Patient)
 */
exports.requestInvoiceReport = async (req, res, next) => {
  try {
    const invoiceId = req.params.invoiceId;

    // Find invoice belonging to the patient
    const invoice = await Invoice.findOne({
      _id: invoiceId,
      order_id: { $exists: true }
    })
    .populate({
      path: 'order_id',
      match: { patient_id: req.user._id },
      populate: {
        path: 'owner_id',
        select: 'lab_name address phone_number'
      }
    })
    .populate({
      path: 'items.test_id',
      select: 'test_name price'
    });

    if (!invoice || !invoice.order_id) {
      return res.status(404).json({ message: '❌ Invoice not found or access denied' });
    }

    const patient = await Patient.findById(req.user._id);
    const labName = invoice.order_id.owner_id?.lab_name || 'Medical Lab';

    // Create invoice URL for online viewing
    const invoiceUrl = `${process.env.FRONTEND_URL || 'http://localhost:8080'}/patient-dashboard/bill-details/${invoice.order_id._id}`;

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
        address: invoice.order_id.owner_id?.address || 'N/A',
        phone_number: invoice.order_id.owner_id?.phone_number || 'N/A'
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
    const { sendInvoiceReport } = require('../utils/sendNotification');

    // Send the invoice report
    const notificationResult = await sendInvoiceReport(
      patient,
      invoiceData,
      invoiceUrl,
      labName
    );

    res.json({
      message: "✅ Invoice report sent successfully to your email and WhatsApp",
      notification: notificationResult
    });

  } catch (err) {
    next(err);
  }
};

exports.downloadInvoicePDF = async (req, res, next) => {
  try {
    const invoiceId = req.params.invoiceId;

    // Find invoice belonging to the patient
    const invoice = await Invoice.findOne({
      _id: invoiceId,
      order_id: { $exists: true }
    })
    .populate({
      path: 'order_id',
      match: { patient_id: req.user._id },
      populate: {
        path: 'owner_id',
        select: 'lab_name address phone_number'
      }
    })
    .populate({
      path: 'items.test_id',
      select: 'test_name price test_code'
    });

    if (!invoice || !invoice.order_id) {
      return res.status(404).json({ message: '❌ Invoice not found or access denied' });
    }

    const patient = await Patient.findById(req.user._id);
    const labName = invoice.order_id.owner_id?.lab_name || 'Medical Lab';

    // Prepare invoice data for PDF generation
    const invoiceData = {
      invoice_id: invoice.invoice_id,
      created_at: invoice.created_at,
      status: invoice.status,
      subtotal: invoice.subtotal || 0,
      discount: invoice.discount || 0,
      tax: invoice.tax || 0,
      total_amount: invoice.total_amount || 0,
      lab: {
        name: labName,
        address: invoice.order_id.owner_id?.address || 'N/A',
        phone_number: invoice.order_id.owner_id?.phone_number || 'N/A'
      },
      patient: {
        name: `${patient.full_name?.first || ''} ${patient.full_name?.last || ''}`.trim(),
        patient_id: patient.patient_id,
        identity_number: patient.identity_number
      },
      tests: invoice.items?.map(item => ({
        test_name: item.test_id?.test_name || 'Unknown Test',
        test_code: item.test_id?.test_code || '',
        price: item.price || 0,
        quantity: item.quantity || 1
      })) || [],
      payments: invoice.payments || []
    };

    // Import the PDF generator
    const { generateInvoicePDF, cleanupPDFFile } = require('../utils/pdfGenerator');

    try {
      // Generate PDF
      const pdfPath = await generateInvoicePDF(invoiceData);

      // Set headers for file download
      const fileName = `invoice_${invoice.invoice_id}_${Date.now()}.pdf`;
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);

      // Send the PDF file
      res.sendFile(pdfPath, async (err) => {
        if (err) {
          console.error('❌ Error sending PDF file:', err);
          return res.status(500).json({ message: '❌ Error downloading PDF' });
        }

        // Clean up the temporary PDF file after sending
        try {
          await cleanupPDFFile(pdfPath);
        } catch (cleanupErr) {
          console.warn('⚠️ Warning: Could not cleanup PDF file:', cleanupErr.message);
        }
      });

    } catch (pdfErr) {
      console.error('❌ Error generating PDF:', pdfErr);
      return res.status(500).json({ message: '❌ Error generating PDF' });
    }

  } catch (err) {
    next(err);
  }
};

module.exports = exports;
// Helper: Calculate tiered subscription fee
async function calculateTieredFee(ownerId) {
  const patientCount = await Patient.countDocuments({ owner_id: ownerId });

  // Patient fee
  let patientFee = 0;
  if (patientCount <= 500) patientFee = 50;
  else if (patientCount > 500 && patientCount <= 2000) patientFee = 100;
  else if (patientCount > 2000) patientFee = 200;

  return {
    total: patientFee,
    patientFee,
    patientCount
  };
}
const LabOwner = require('../models/Owner');
const Staff = require('../models/Staff');
const Patient = require('../models/Patient');
const Device = require('../models/Device');
const Admin = require('../models/Admin');
const Test = require('../models/Test');
const TestComponent = require('../models/TestComponent');
const Order = require('../models/Order');
const OrderDetails = require('../models/OrderDetails');
const Result = require('../models/Result');
const ResultComponent = require('../models/ResultComponent');
const Invoice = require('../models/Invoices');
const Notification = require('../models/Notification');
const AuditLog = require('../models/AuditLog');
const logAction = require('../utils/logAction');
const Feedback = require('../models/Feedback');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { sendWhatsAppMessage } = require('../utils/sendWhatsApp');
const mongoose = require('mongoose');
const { sendPushNotificationToOwner, sendPushNotificationToAdmin } = require('./notificationController');

// ==================== AUTHENTICATION ====================

/**
 * @desc    Lab Owner Login
 * @route   POST /api/owner/login
 * @access  Public
 */
exports.login = async (req, res, next) => {
  try {
    let { username, password } = req.body;

    // Validate input
    if (!username || !password) {
      return res.status(400).json({ success: false, error: '⚠️ Username and password are required' });
    }

    // Normalize username (remove spaces, convert to lowercase)
    const normalizedUsername = username.replace(/\s+/g, '.').toLowerCase().trim();

    // Find owner by username or email
    const owner = await LabOwner.findOne({ $or: [{ username: normalizedUsername }, { email: username }] });
    if (!owner) {
      return res.status(401).json({ success: false, error: '❌ Invalid credentials' });
    }

    // Check if owner is approved and active
    if (owner.status !== 'approved') {
      return res.status(403).json({ success: false, error: '⚠️ Account is not approved yet. Please wait for admin approval.' });
    }

    if (!owner.is_active) {
      return res.status(403).json({ success: false, error: '⚠️ Account is inactive. Please contact support.' });
    }

    // Compare password
    const isMatch = await owner.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ success: false, error: '❌ Invalid credentials' });
    }

    // Check subscription status and calculate days remaining
    let subscriptionWarning = null;
    let subscriptionExpired = false;
    
    if (owner.subscription_end) {
      const today = new Date();
      const endDate = new Date(owner.subscription_end);
      const daysRemaining = Math.ceil((endDate - today) / (1000 * 60 * 60 * 24));

      if (daysRemaining < 0) {
        subscriptionExpired = true;
        subscriptionWarning = `⚠️ Your subscription expired ${Math.abs(daysRemaining)} days ago. Limited access - please renew immediately.`;
      } else if (daysRemaining <= 7) {
        subscriptionWarning = `⚠️ Your subscription expires in ${daysRemaining} day(s). Please renew soon to avoid service interruption.`;
      } else if (daysRemaining <= 30) {
        subscriptionWarning = `ℹ️ Your subscription expires in ${daysRemaining} days.`;
      }
    }

    // Generate JWT token
    const token = jwt.sign(
      { 
        _id: owner._id, 
        owner_id: owner.owner_id,
        role: 'owner',
        username: owner.username,
        subscription_expired: subscriptionExpired
      },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    // Calculate dynamic fee
    const feeInfo = await calculateTieredFee(owner._id);
    
    // Log successful login
    await logAction(null, owner.username, 'Login', 'Owner', null, owner._id);
    
    res.json({
      success: true,
      message: subscriptionExpired 
        ? '⚠️ Login successful - SUBSCRIPTION EXPIRED' 
        : '✅ Login successful',
      token,
      owner: {
        _id: owner._id,
        owner_id: owner.owner_id,
        name: owner.name,
        lab_name: owner.lab_name,
        email: owner.email,
        username: owner.username,
        subscription_end: owner.subscription_end,
        subscription_expired: subscriptionExpired,
        subscriptionFee: feeInfo.total,
        feeBreakdown: feeInfo
      },
      ...(subscriptionWarning && { warning: subscriptionWarning })
    });

  } catch (err) {
    next(err);
  }
};

// ==================== REQUEST ACCESS ====================
/**
 * @desc    Lab Owner requests access to use the system
 * @route   POST /api/owner/request-access
 * @access  Public
 */
exports.requestAccess = async (req, res, next) => {
  try {
    const { first_name, middle_name, last_name, identity_number, birthday, gender, social_status, phone, address, qualification, profession_license, bank_iban, email, selected_plan } = req.body;

    if (!first_name || !last_name || !identity_number || !email)
      return res.status(400).json({ success: false, error: '⚠️ Missing required fields' });

    const existingOwner = await LabOwner.findOne({ $or: [{ email }, { identity_number }] });
    if (existingOwner) return res.status(400).json({ success: false, error: '⚠️ Lab Owner with provided email or ID already exists' });

    // Get default admin (first admin) to assign to this owner
    const defaultAdmin = await Admin.findOne().sort({ createdAt: 1 });
    if (!defaultAdmin) {
      return res.status(500).json({ success: false, error: 'System not properly configured. No admin found.' });
    }

    // Parse address string into address object
    let addressObject = {};
    if (address && typeof address === 'string') {
      // Parse address string like "Nablus, Rafidia, 2" into structured format
      const addressParts = address.split(',').map(part => part.trim());
      addressObject = {
        street: addressParts[2] || addressParts[0] || '', // Use last part as street, or first part if only one
        city: addressParts[1] || addressParts[0] || '', // Use middle part as city, or first part if only one
        country: 'Palestine' // Default country
      };
    } else if (address && typeof address === 'object') {
      addressObject = address;
    }

    // Set subscription fee based on selected plan
    let subscriptionFee = 50; // Default starter plan
    if (selected_plan === 'professional') subscriptionFee = 100;
    else if (selected_plan === 'enterprise') subscriptionFee = 200;

    const owner_id = `OWN-${Date.now()}`;

    const newRequest = await LabOwner.create({
      name: { first: first_name, middle: middle_name || '', last: last_name },
      identity_number,
      birthday,
      gender,
      social_status,
      phone_number: phone,
      address: addressObject,
      qualification,
      profession_license,
      bank_iban,
      email,
      owner_id,
      date_subscription: null,
      status: 'pending',
      admin_id: defaultAdmin._id,
      is_active: false,
      subscriptionFee
    });

    const admins = await Admin.find({});
    const notifications = admins.map(admin => ({
      sender_id: newRequest._id,
      sender_model: 'Owner',
      receiver_id: admin._id,
      receiver_model: 'Admin',
      type: 'system',
      title: 'New Lab Owner Request',
      message: `Lab Owner ${first_name} ${last_name} has requested access to the system.${selected_plan ? ` Selected Plan: ${selected_plan} (\$${subscriptionFee}/month)` : ''}`
    }));
    await Notification.insertMany(notifications);

    res.status(201).json({
      success: true,
      message: '✅ Lab Owner request submitted successfully. Waiting for admin approval.',
      labOwner: newRequest
    });

  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Owner Profile
 * @route   GET /api/owner/profile
 * @access  Private (Owner)
 */
exports.getProfile = async (req, res, next) => {
  try {
    const owner = await LabOwner.findById(req.user._id).select('-password');
    
    if (!owner) {
      return res.status(404).json({ message: '❌ Owner not found' });
    }

    // Calculate days until subscription expires
    let subscriptionStatus = null;
    if (owner.subscription_end) {
      const today = new Date();
      const endDate = new Date(owner.subscription_end);
      const daysRemaining = Math.ceil((endDate - today) / (1000 * 60 * 60 * 24));

      if (daysRemaining < 0) {
        subscriptionStatus = {
          status: 'expired',
          daysRemaining: 0,
          expiredDays: Math.abs(daysRemaining),
          message: `⚠️ Your subscription expired ${Math.abs(daysRemaining)} days ago. Please contact admin to renew.`
        };
      } else if (daysRemaining <= 7) {
        subscriptionStatus = {
          status: 'expiring_soon',
          daysRemaining,
          message: `⚠️ Your subscription will expire in ${daysRemaining} day(s). Please contact admin to renew.`
        };
      } else if (daysRemaining <= 30) {
        subscriptionStatus = {
          status: 'expiring_within_month',
          daysRemaining,
          message: `ℹ️ Your subscription will expire in ${daysRemaining} days.`
        };
      } else {
        subscriptionStatus = {
          status: 'active',
          daysRemaining,
          message: `✅ Your subscription is active until ${endDate.toDateString()}.`
        };
      }
    }

    // Calculate dynamic fee
    const feeInfo = await calculateTieredFee(owner._id);
    res.json({
      ...owner.toObject(),
      subscriptionStatus,
      subscriptionFee: feeInfo.total,
      feeBreakdown: feeInfo
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update Owner Profile
 * @route   PUT /api/owner/profile
 * @access  Private (Owner)
 */
exports.updateProfile = async (req, res, next) => {
  try {
    const { phone_number, address, email, bank_iban, username, office_hours } = req.body;

    const owner = await LabOwner.findById(req.user._id);
    if (!owner) {
      return res.status(404).json({ message: '❌ Owner not found' });
    }

    // Check username uniqueness if being updated
    if (username && username !== owner.username) {
      // Validate username format
      if (!/^[a-z0-9._-]+$/.test(username)) {
        return res.status(400).json({ message: '❌ Username can only contain lowercase letters, numbers, dots, underscores, and hyphens' });
      }

      // Check uniqueness across all user collections
      const existingUsers = await Promise.all([
        mongoose.model('Patient').findOne({ username }),
        mongoose.model('Doctor').findOne({ username }),
        mongoose.model('Staff').findOne({ username }),
        mongoose.model('Admin').findOne({ username }),
        mongoose.model('LabOwner').findOne({ username, _id: { $ne: owner._id } })
      ]);

      if (existingUsers.some(user => user !== null)) {
        return res.status(400).json({ message: '❌ Username already exists' });
      }

      owner.username = username;
    }

    // Update allowed fields
    if (phone_number) owner.phone_number = phone_number;
    if (address) {
      // Convert string address to proper format matching addressSchema.js
      if (typeof address === 'string') {
        const addressParts = address.split(',').map(part => part.trim());
        owner.address = {
          street: addressParts[0] || '',
          city: addressParts[1] || '',
          country: addressParts[2] || 'Palestine'
        };
      } else {
        // Ensure only schema fields are used
        owner.address = {
          street: address.street || '',
          city: address.city || '',
          country: address.country || 'Palestine'
        };
      }
    }
    if (email) owner.email = email;
    if (bank_iban) owner.bank_iban = bank_iban;
    if (office_hours !== undefined) owner.office_hours = office_hours;

    await owner.save();

    res.json({ 
      message: '✅ Profile updated successfully', 
      owner: await LabOwner.findById(owner._id).select('-password')
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Change Password
 * @route   PUT /api/owner/change-password
 * @access  Private (Owner)
 */
exports.changePassword = async (req, res, next) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ success: false, error: '⚠️ Current password and new password are required' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ success: false, error: '⚠️ New password must be at least 6 characters' });
    }

    const owner = await LabOwner.findById(req.user._id);
    if (!owner) {
      return res.status(404).json({ message: '❌ Owner not found' });
    }

    // Verify current password
    const isMatch = await owner.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(401).json({ success: false, error: '❌ Current password is incorrect' });
    }

    // Update password
    owner.password = await bcrypt.hash(newPassword, 10);
    await owner.save();

    res.json({ success: true, message: '✅ Password changed successfully' });
  } catch (err) {
    next(err);
  }
};

// ==================== STAFF MANAGEMENT ====================

/**
 * @desc    Get All Staff Members
 * @route   GET /api/owner/staff
 * @access  Private (Owner)
 */
exports.getAllStaff = async (req, res, next) => {
  try {
    const staff = await Staff.find({ owner_id: req.user._id }).select('-password');
    res.json({ count: staff.length, staff });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Staff Member
 * @route   GET /api/owner/staff/:staffId
 * @access  Private (Owner)
 */
exports.getStaffById = async (req, res, next) => {
  try {
    const staff = await Staff.findOne({ 
      _id: req.params.staffId, 
      owner_id: req.user._id 
    }).select('-password');

    if (!staff) {
      return res.status(404).json({ message: '❌ Staff member not found' });
    }

    res.json(staff);
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Add New Staff Member
 * @route   POST /api/owner/staff
 * @access  Private (Owner)
 */
exports.addStaff = async (req, res, next) => {
  try {
    const {
      full_name,
      identity_number,
      birthday,
      gender,
      social_status,
      phone_number,
      address,
      qualification,
      profession_license,
      employee_number,
      bank_iban,
      salary,
      email,
      username,
      password
    } = req.body;

    // Validate required fields
    if (!full_name?.first || !full_name?.last || !identity_number || !birthday || !gender || !phone_number || !email || !username || !password) {
      return res.status(400).json({ message: '⚠️ Please provide all required fields' });
    }

    // Check if identity number, email, or username already exists
    const existingStaff = await Staff.findOne({
      $or: [
        { identity_number },
        { email },
        { username },
        { employee_number: employee_number || null }
      ]
    });

    if (existingStaff) {
      return res.status(400).json({ message: '⚠️ Staff with this identity number, email, username, or employee number already exists' });
    }

    // Process address - handle both string and object formats
    let processedAddress = address;
    if (typeof address === 'string') {
      // Parse address string like "Ramallah, Palestine"
      const addressParts = address.split(',').map(part => part.trim());
      processedAddress = {
        street: '',
        city: addressParts[0] || '',
        country: addressParts[1] || 'Palestine'
      };
    }

    // Create new staff
    const newStaff = new Staff({
      full_name,
      identity_number,
      birthday,
      gender,
      social_status,
      phone_number,
      address: processedAddress,
      qualification,
      profession_license,
      employee_number: employee_number || `EMP-${Date.now()}`,
      bank_iban,
      salary: salary || 0,
      email,
      username,
      password,
      owner_id: req.user._id,
      date_hired: new Date()
    });

    await newStaff.save();

    // Log staff creation
    await logAction(null, req.user.username || 'Owner', 'Create Staff', 'Staff', newStaff._id, req.user._id);

    // Send notification to staff
    await Notification.create({
      sender_id: req.user._id,
      sender_model: 'Owner',
      receiver_id: newStaff._id,
      receiver_model: 'Staff',
      type: 'system',
      title: 'Welcome to the Team',
      message: `Your account has been created. Username: ${username}. Please login and change your password.`
    });

    // Send account activation notification (both WhatsApp and Email)
    try {
      const { sendStaffDoctorActivation } = require('../utils/sendNotification');
      const owner = await require('../models/Owner').findById(req.user._id);
      const notificationSuccess = await sendStaffDoctorActivation(
        newStaff,
        username,
        password,
        'Staff',
        owner.lab_name
      );

      if (notificationSuccess) {
        // Notification sent successfully
      }
    } catch (notificationError) {
      console.error('Failed to send staff account activation notification:', notificationError);
      // Continue with the response - don't fail the staff creation
    }

    res.status(201).json({ 
      message: '✅ Staff member added successfully. Credentials sent via WhatsApp and email.', 
      staff: await Staff.findById(newStaff._id).select('-password')
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update Staff Member
 * @route   PUT /api/owner/staff/:staffId
 * @access  Private (Owner)
 */
exports.updateStaff = async (req, res, next) => {
  try {
    const staff = await Staff.findOne({ 
      _id: req.params.staffId, 
      owner_id: req.user._id 
    });

    if (!staff) {
      return res.status(404).json({ message: '❌ Staff member not found' });
    }

    const {
      full_name,
      phone_number,
      address,
      qualification,
      profession_license,
      bank_iban,
      salary,
      employee_evaluation,
      email
    } = req.body;

    // Update allowed fields
    if (full_name) staff.full_name = full_name;
    if (phone_number) staff.phone_number = phone_number;
    if (address) {
      // Process address - handle both string and object formats
      if (typeof address === 'string') {
        const addressParts = address.split(',').map(part => part.trim());
        staff.address = {
          street: '',
          city: addressParts[0] || '',
          country: addressParts[1] || 'Palestine'
        };
      } else {
        staff.address = address;
      }
    }
    if (qualification) staff.qualification = qualification;
    if (profession_license) staff.profession_license = profession_license;
    if (bank_iban) staff.bank_iban = bank_iban;
    if (salary !== undefined) staff.salary = salary;
    if (employee_evaluation) staff.employee_evaluation = employee_evaluation;
    if (email) staff.email = email;

    await staff.save();

    // Log staff update
    await logAction(null, req.user.username || 'Owner', 'Update Staff', 'Staff', staff._id, req.user._id);

    res.json({ 
      message: '✅ Staff member updated successfully', 
      staff: await Staff.findById(staff._id).select('-password')
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Delete Staff Member
 * @route   DELETE /api/owner/staff/:staffId
 * @access  Private (Owner)
 */
exports.deleteStaff = async (req, res, next) => {
  try {
    const staff = await Staff.findOne({ 
      _id: req.params.staffId, 
      owner_id: req.user._id 
    });

    if (!staff) {
      return res.status(404).json({ message: '❌ Staff member not found' });
    }

    // Log staff deletion
    await logAction(null, req.user.username || 'Owner', 'Delete Staff', 'Staff', staff._id, req.user._id);

    await Staff.findByIdAndDelete(staff._id);

    res.json({ message: '✅ Staff member deleted successfully' });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get All Doctors
 * @route   GET /api/owner/doctors
 * @access  Private (Owner)
 */
exports.getAllDoctors = async (req, res, next) => {
  try {
    const Doctor = require('../models/Doctor');
    // Doctors are global - return all doctors (not filtered by owner_id)
    const doctors = await Doctor.find({}).select('-password');
    res.json({ count: doctors.length, doctors });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Doctor
 * @route   GET /api/owner/doctors/:doctorId
 * @access  Private (Owner)
 */
exports.getDoctorById = async (req, res, next) => {
  try {
    const Doctor = require('../models/Doctor');
    const doctor = await Doctor.findById(req.params.doctorId).select('-password');

    if (!doctor) {
      return res.status(404).json({ message: '❌ Doctor not found' });
    }

    res.json(doctor);
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Add New Doctor
 * @route   POST /api/owner/doctors
 * @access  Private (Owner)
 */
exports.addDoctor = async (req, res, next) => {
  try {
    const Doctor = require('../models/Doctor');
    const {
      full_name,
      identity_number,
      birthday,
      gender,
      phone,
      email,
      username,
      password
    } = req.body;

    // Validate required fields
    if (!full_name?.first || !full_name?.last || !email || !username || !identity_number || !birthday || !gender) {
      return res.status(400).json({ message: '⚠️ Required fields: first name, last name, email, username, identity number, birthday, and gender' });
    }

    // Check if email already exists
    const existingDoctor = await Doctor.findOne({ email });
    if (existingDoctor) {
      return res.status(400).json({ message: '⚠️ Doctor with this email already exists' });
    }

    // Check if identity_number already exists
    const existingIdentity = await Doctor.findOne({ identity_number });
    if (existingIdentity) {
      return res.status(400).json({ message: '⚠️ Doctor with this identity number already exists' });
    }

    // Generate unique doctor_id
    const lastDoctor = await Doctor.findOne().sort({ doctor_id: -1 });
    const doctor_id = lastDoctor ? lastDoctor.doctor_id + 1 : 1;

    const newDoctor = new Doctor({
      doctor_id,
      name: full_name,
      identity_number,
      birthday: new Date(birthday),
      gender,
      phone_number: phone,
      email,
      username,
      password: password || 'Doctor@123' // Default password if not provided
    });

    await newDoctor.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'CREATE_DOCTOR',
      table_name: 'Doctor',
      record_id: newDoctor._id,
      owner_id: req.user._id
    });

    // Send account activation notification (both WhatsApp and Email)
    try {
      const { sendStaffDoctorActivation } = require('../utils/sendNotification');
      const owner = await require('../models/Owner').findById(req.user._id);
      const notificationSuccess = await sendStaffDoctorActivation(
        newDoctor,
        username,
        password || 'Doctor@123',
        'Doctor',
        owner.lab_name
      );

      if (notificationSuccess) {
        // Notification sent successfully
      }
    } catch (notificationError) {
      console.error('Failed to send doctor account activation notification:', notificationError);
      // Continue with the response - don't fail the doctor creation
    }

    res.status(201).json({ 
      message: '✅ Doctor added successfully. Credentials sent via WhatsApp and email.', 
      doctor: newDoctor
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update Doctor
 * @route   PUT /api/owner/doctors/:doctorId
 * @access  Private (Owner)
 */
exports.updateDoctor = async (req, res, next) => {
  try {
    const Doctor = require('../models/Doctor');
    const doctor = await Doctor.findById(req.params.doctorId);

    if (!doctor) {
      return res.status(404).json({ message: '❌ Doctor not found' });
    }

    const {
      name,
      phone_number,
      email,
      identity_number,
      birthday,
      gender,
      username
    } = req.body;

    // Update fields
    if (name) doctor.name = name;
    if (phone_number) doctor.phone_number = phone_number;
    if (email) doctor.email = email;
    if (identity_number) doctor.identity_number = identity_number;
    if (birthday) doctor.birthday = new Date(birthday);
    if (gender) doctor.gender = gender;
    if (username) doctor.username = username;

    await doctor.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'UPDATE_DOCTOR',
      table_name: 'Doctor',
      record_id: doctor._id,
      owner_id: req.user._id
    });

    res.json({ 
      message: '✅ Doctor updated successfully', 
      doctor
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Delete Doctor
 * @route   DELETE /api/owner/doctors/:doctorId
 * @access  Private (Owner)
 */
exports.deleteDoctor = async (req, res, next) => {
  try {
    const Doctor = require('../models/Doctor');
    const doctor = await Doctor.findById(req.params.doctorId);

    if (!doctor) {
      return res.status(404).json({ message: '❌ Doctor not found' });
    }

    // Check if doctor is referenced in any orders
    const ordersUsingDoctor = await Order.find({ doctor_id: doctor._id });
    if (ordersUsingDoctor.length > 0) {
      return res.status(400).json({ message: '⚠️ Cannot delete doctor. They are referenced in existing orders.' });
    }

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'DELETE_DOCTOR',
      table_name: 'Doctor',
      record_id: doctor._id,
      owner_id: req.user._id
    });

    await Doctor.findByIdAndDelete(doctor._id);

    res.json({ message: '✅ Doctor deleted successfully' });
  } catch (err) {
    next(err);
  }
};

// ==================== DEVICE MANAGEMENT ====================

/**
 * @desc    Get All Devices
 * @route   GET /api/owner/devices
 * @access  Private (Owner)
 */
exports.getAllDevices = async (req, res, next) => {
  try {
    const devices = await Device.find({ owner_id: req.user._id }).populate('staff_id');
    res.json({ count: devices.length, devices });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Device
 * @route   GET /api/owner/devices/:deviceId
 * @access  Private (Owner)
 */
exports.getDeviceById = async (req, res, next) => {
  try {
    const device = await Device.findOne({
      _id: req.params.deviceId,
      owner_id: req.user._id
    }).populate('staff_id');

    if (!device) {
      return res.status(404).json({ message: '❌ Device not found' });
    }

    res.json(device);
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Add New Device
 * @route   POST /api/owner/devices
 * @access  Private (Owner)
 */
exports.addDevice = async (req, res, next) => {
  try {
    const {
      name,
      serial_number,
      cleaning_reagent,
      manufacturer,
      status,
      staff_id,
      capacity_of_sample,
      maintenance_schedule
    } = req.body;

    // Validate required fields
    if (!name || !serial_number) {
      return res.status(400).json({ message: '⚠️ Device name and serial number are required' });
    }

    // Check if serial number already exists
    const existingDevice = await Device.findOne({ serial_number });
    if (existingDevice) {
      return res.status(400).json({ message: '⚠️ Device with this serial number already exists' });
    }

    // Verify staff belongs to this owner if staff_id is provided
    if (staff_id) {
      const staff = await Staff.findOne({ _id: staff_id, owner_id: req.user._id });
      if (!staff) {
        return res.status(400).json({ message: '⚠️ Invalid staff member' });
      }
    }

    const newDevice = new Device({
      name,
      serial_number,
      cleaning_reagent,
      manufacturer,
      status: status || 'active',
      staff_id,
      capacity_of_sample,
      maintenance_schedule,
      owner_id: req.user._id
    });

    await newDevice.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'CREATE_DEVICE',
      table_name: 'Device',
      record_id: newDevice._id,
      owner_id: req.user._id
    });

    res.status(201).json({ 
      message: '✅ Device added successfully', 
      device: await Device.findById(newDevice._id).populate('staff_id')
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update Device
 * @route   PUT /api/owner/devices/:deviceId
 * @access  Private (Owner)
 */
exports.updateDevice = async (req, res, next) => {
  try {
    const device = await Device.findOne({ 
      _id: req.params.deviceId, 
      owner_id: req.user._id 
    });

    if (!device) {
      return res.status(404).json({ message: '❌ Device not found' });
    }

    const {
      name,
      cleaning_reagent,
      manufacturer,
      status,
      staff_id,
      capacity_of_sample,
      maintenance_schedule
    } = req.body;

    // Verify staff belongs to this owner if staff_id is provided
    if (staff_id) {
      const staff = await Staff.findOne({ _id: staff_id, owner_id: req.user._id });
      if (!staff) {
        return res.status(400).json({ message: '⚠️ Invalid staff member' });
      }
    }

    // Update fields
    if (name) device.name = name;
    if (cleaning_reagent) device.cleaning_reagent = cleaning_reagent;
    if (manufacturer) device.manufacturer = manufacturer;
    if (status) device.status = status;
    if (staff_id !== undefined) device.staff_id = staff_id;
    if (capacity_of_sample) device.capacity_of_sample = capacity_of_sample;
    if (maintenance_schedule) device.maintenance_schedule = maintenance_schedule;

    await device.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'UPDATE_DEVICE',
      table_name: 'Device',
      record_id: device._id,
      owner_id: req.user._id
    });

    res.json({ 
      message: '✅ Device updated successfully', 
      device: await Device.findById(device._id).populate('staff_id')
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Assign Staff to Device
 * @route   POST /api/owner/assign-staff-to-device
 * @access  Private (Owner)
 */
exports.assignStaffToDevice = async (req, res, next) => {
  try {
    const { device_id, staff_id } = req.body;

    if (!device_id) {
      return res.status(400).json({ message: '⚠️ Device ID is required' });
    }

    // Find device and verify ownership
    const device = await Device.findOne({ 
      _id: device_id, 
      owner_id: req.user._id 
    });

    if (!device) {
      return res.status(404).json({ message: '❌ Device not found' });
    }

    // If staff_id is provided, verify it belongs to this owner
    if (staff_id) {
      const staff = await Staff.findOne({ 
        _id: staff_id, 
        owner_id: req.user._id 
      });

      if (!staff) {
        return res.status(400).json({ 
          message: '⚠️ Staff member not found or does not belong to your lab' 
        });
      }

      // Assign staff to device
      device.staff_id = staff_id;

      // Send notification to staff
      await Notification.create({
        sender_id: req.user._id,
        sender_model: 'Owner',
        receiver_id: staff_id,
        receiver_model: 'Staff',
        type: 'system',
        title: 'Device Assigned',
        message: `You have been assigned to operate ${device.name} (${device.serial_number || 'N/A'})`
      });
    } else {
      // Unassign staff (set to null)
      device.staff_id = null;
    }

    await device.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: staff_id ? 'ASSIGN_STAFF_TO_DEVICE' : 'UNASSIGN_STAFF_FROM_DEVICE',
      table_name: 'Device',
      record_id: device._id,
      owner_id: req.user._id
    });

    const populatedDevice = await Device.findById(device._id)
      .populate('staff_id');

    res.json({ 
      success: true,
      message: staff_id 
        ? '✅ Staff assigned to device successfully' 
        : '✅ Staff unassigned from device',
      device: {
        _id: populatedDevice._id,
        name: populatedDevice.name,
        serial_number: populatedDevice.serial_number,
        status: populatedDevice.status,
        assigned_staff: populatedDevice.staff_id ? {
          _id: populatedDevice.staff_id._id,
          name: `${populatedDevice.staff_id.full_name.first} ${populatedDevice.staff_id.full_name.last}`,
          employee_number: populatedDevice.staff_id.employee_number,
          username: populatedDevice.staff_id.username
        } : null
      }
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Delete Device
 * @route   DELETE /api/owner/devices/:deviceId
 * @access  Private (Owner)
 */
exports.deleteDevice = async (req, res, next) => {
  try {
    const device = await Device.findOne({ 
      _id: req.params.deviceId, 
      owner_id: req.user._id 
    });

    if (!device) {
      return res.status(404).json({ message: '❌ Device not found' });
    }

    // Check if device is assigned to any tests
    const testsUsingDevice = await Test.find({ device_id: device._id });
    if (testsUsingDevice.length > 0) {
      return res.status(400).json({ message: '⚠️ Cannot delete device. It is assigned to active tests.' });
    }

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'DELETE_DEVICE',
      table_name: 'Device',
      record_id: device._id,
      owner_id: req.user._id
    });

    await Device.findByIdAndDelete(device._id);

    res.json({ message: '✅ Device deleted successfully' });
  } catch (err) {
    next(err);
  }
};

// ==================== TEST MANAGEMENT ====================

/**
 * @desc    Get All Tests
 * @route   GET /api/owner/tests
 * @access  Private (Owner)
 */
exports.getAllTests = async (req, res, next) => {
  try {
    const tests = await Test.find({ owner_id: req.user._id }).populate('device_id', 'name serial_number');
    res.json({ count: tests.length, tests });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Test
 * @route   GET /api/owner/tests/:testId
 * @access  Private (Owner)
 */
exports.getTestById = async (req, res, next) => {
  try {
    const test = await Test.findOne({
      _id: req.params.testId,
      owner_id: req.user._id
    }).populate('device_id', 'name serial_number');

    if (!test) {
      return res.status(404).json({ message: '❌ Test not found' });
    }

    res.json(test);
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Add New Test
 * @route   POST /api/owner/tests
 * @access  Private (Owner)
 */
exports.addTest = async (req, res, next) => {
  try {
    const {
      test_code,
      test_name,
      sample_type,
      tube_type,
      is_active,
      device_id,
      method,
      units,
      reference_range,
      price,
      turnaround_time,
      collection_time,
      reagent
    } = req.body;

    // Validate required fields
    if (!test_code || !test_name) {
      return res.status(400).json({ message: '⚠️ Test code and test name are required' });
    }

    // Check if test code already exists for this owner
    const existingTest = await Test.findOne({ test_code, owner_id: req.user._id });
    if (existingTest) {
      return res.status(400).json({ message: '⚠️ Test with this code already exists in your lab' });
    }

    // Verify device belongs to this owner if device_id is provided
    if (device_id) {
      const device = await Device.findOne({ _id: device_id, owner_id: req.user._id });
      if (!device) {
        return res.status(400).json({ message: '⚠️ Invalid device' });
      }
    }

    const newTest = new Test({
      test_code,
      test_name,
      sample_type,
      tube_type,
      is_active: is_active !== undefined ? is_active : true,
      device_id,
      method,
      units,
      reference_range,
      price,
      owner_id: req.user._id,
      turnaround_time,
      collection_time,
      reagent
    });

    await newTest.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'CREATE_TEST',
      table_name: 'Test',
      record_id: newTest._id,
      owner_id: req.user._id
    });

    res.status(201).json({ 
      message: '✅ Test added successfully', 
      test: await Test.findById(newTest._id).populate('device_id', 'name')
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update Test
 * @route   PUT /api/owner/tests/:testId
 * @access  Private (Owner)
 */
exports.updateTest = async (req, res, next) => {
  try {
    const test = await Test.findOne({ 
      _id: req.params.testId, 
      owner_id: req.user._id 
    });

    if (!test) {
      return res.status(404).json({ message: '❌ Test not found' });
    }

    const {
      test_name,
      sample_type,
      tube_type,
      is_active,
      device_id,
      method,
      units,
      reference_range,
      price,
      turnaround_time,
      collection_time,
      reagent
    } = req.body;

    // Verify device belongs to this owner if device_id is provided
    if (device_id) {
      const device = await Device.findOne({ _id: device_id, owner_id: req.user._id });
      if (!device) {
        return res.status(400).json({ message: '⚠️ Invalid device' });
      }
    }

    // Update fields
    if (test_name) test.test_name = test_name;
    if (sample_type) test.sample_type = sample_type;
    if (tube_type) test.tube_type = tube_type;
    if (is_active !== undefined) test.is_active = is_active;
    if (device_id !== undefined) test.device_id = device_id;
    if (method) test.method = method;
    if (units) test.units = units;
    if (reference_range) test.reference_range = reference_range;
    if (price !== undefined) test.price = price;
    if (turnaround_time) test.turnaround_time = turnaround_time;
    if (collection_time) test.collection_time = collection_time;
    if (reagent) test.reagent = reagent;

    await test.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'UPDATE_TEST',
      table_name: 'Test',
      record_id: test._id,
      owner_id: req.user._id
    });

    res.json({ 
      message: '✅ Test updated successfully', 
      test: await Test.findById(test._id).populate('device_id', 'name')
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Delete Test
 * @route   DELETE /api/owner/tests/:testId
 * @access  Private (Owner)
 */
exports.deleteTest = async (req, res, next) => {
  try {
    const test = await Test.findOne({ 
      _id: req.params.testId, 
      owner_id: req.user._id 
    });

    if (!test) {
      return res.status(404).json({ message: '❌ Test not found' });
    }

    // Check if test is used in any orders
    const ordersUsingTest = await OrderDetails.find({ test_id: test._id });
    if (ordersUsingTest.length > 0) {
      return res.status(400).json({ message: '⚠️ Cannot delete test. It is used in existing orders.' });
    }

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'DELETE_TEST',
      table_name: 'Test',
      record_id: test._id,
      owner_id: req.user._id
    });

    await Test.findByIdAndDelete(test._id);

    res.json({ message: '✅ Test deleted successfully' });
  } catch (err) {
    next(err);
  }
};

// ==================== INVENTORY MANAGEMENT ====================

/**
 * @desc    Get All Inventory Items
 * @route   GET /api/owner/inventory
 * @access  Private (Owner)
 */
exports.getAllInventory = async (req, res, next) => {
  try {
    const { Inventory } = require('../models/Inventory');
    const items = await Inventory.find({ owner_id: req.user._id });
    
    // Check for low stock and expiring items
    const lowStock = items.filter(item => item.count <= item.critical_level);
    const expiringSoon = items.filter(item => {
      const daysUntilExpiry = Math.ceil((new Date(item.expiration_date) - new Date()) / (1000 * 60 * 60 * 24));
      return daysUntilExpiry <= 30 && daysUntilExpiry > 0;
    });

    res.json({ 
      count: items.length, 
      items,
      alerts: {
        lowStock: lowStock.length,
        expiringSoon: expiringSoon.length
      }
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Inventory Item
 * @route   GET /api/owner/inventory/:itemId
 * @access  Private (Owner)
 */
exports.getInventoryById = async (req, res, next) => {
  try {
    const { Inventory, StockInput, StockOutput } = require('../models/Inventory');
    
    const item = await Inventory.findOne({
      _id: req.params.itemId,
      owner_id: req.user._id
    });

    if (!item) {
      return res.status(404).json({ message: '❌ Inventory item not found' });
    }

    // Get transaction history
    const [inputs, outputs] = await Promise.all([
      StockInput.find({ item_id: item._id }).sort({ input_date: -1 }).limit(10),
      StockOutput.find({ item_id: item._id }).sort({ out_date: -1 }).limit(10)
    ]);

    res.json({ 
      item,
      history: {
        recentInputs: inputs,
        recentOutputs: outputs
      }
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Add Inventory Item
 * @route   POST /api/owner/inventory
 * @access  Private (Owner)
 */
exports.addInventoryItem = async (req, res, next) => {
  try {
    const { Inventory } = require('../models/Inventory');
    const {
      name,
      item_code,
      cost,
      expiration_date,
      critical_level,
      count
    } = req.body;

    // Validate required fields
    if (!name || !item_code) {
      return res.status(400).json({ message: '⚠️ Item name and code are required' });
    }

    // Check if item code already exists for this owner
    const existingItem = await Inventory.findOne({ item_code, owner_id: req.user._id });
    if (existingItem) {
      return res.status(400).json({ message: '⚠️ Item with this code already exists' });
    }

    const newItem = new Inventory({
      name,
      item_code,
      cost: cost || 0,
      expiration_date,
      critical_level: critical_level || 10,
      count: count || 0,
      balance: count || 0,
      owner_id: req.user._id
    });

    await newItem.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'CREATE_INVENTORY_ITEM',
      table_name: 'Inventory',
      record_id: newItem._id,
      owner_id: req.user._id
    });

    // Check if stock is low
    if (newItem.count <= newItem.critical_level) {
      await Notification.create({
        sender_id: req.user._id,
        sender_model: 'Owner',
        receiver_id: req.user._id,
        receiver_model: 'Owner',
        type: 'system',
        title: 'Low Stock Alert',
        message: `Inventory item "${name}" is at or below critical level (${newItem.count} units).`
      });
    }

    res.status(201).json({ 
      message: '✅ Inventory item added successfully', 
      item: newItem
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update Inventory Item
 * @route   PUT /api/owner/inventory/:itemId
 * @access  Private (Owner)
 */
exports.updateInventoryItem = async (req, res, next) => {
  try {
    const { Inventory } = require('../models/Inventory');
    const item = await Inventory.findOne({ 
      _id: req.params.itemId, 
      owner_id: req.user._id 
    });

    if (!item) {
      return res.status(404).json({ message: '❌ Inventory item not found' });
    }

    const {
      name,
      cost,
      expiration_date,
      critical_level,
      count
    } = req.body;

    // Update fields
    if (name) item.name = name;
    if (cost !== undefined) item.cost = cost;
    if (expiration_date) item.expiration_date = expiration_date;
    if (critical_level !== undefined) item.critical_level = critical_level;
    if (count !== undefined) {
      item.count = count;
      item.balance = count;
    }

    await item.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'UPDATE_INVENTORY_ITEM',
      table_name: 'Inventory',
      record_id: item._id,
      owner_id: req.user._id
    });

    // Check if stock is low
    if (item.count <= item.critical_level) {
      await Notification.create({
        sender_id: req.user._id,
        sender_model: 'Owner',
        receiver_id: req.user._id,
        receiver_model: 'Owner',
        type: 'system',
        title: 'Low Stock Alert',
        message: `Inventory item "${item.name}" is at or below critical level (${item.count} units).`
      });
    }

    res.json({ 
      message: '✅ Inventory item updated successfully', 
      item
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Delete Inventory Item
 * @route   DELETE /api/owner/inventory/:itemId
 * @access  Private (Owner)
 */
exports.deleteInventoryItem = async (req, res, next) => {
  try {
    const { Inventory } = require('../models/Inventory');
    const item = await Inventory.findOne({ 
      _id: req.params.itemId, 
      owner_id: req.user._id 
    });

    if (!item) {
      return res.status(404).json({ message: '❌ Inventory item not found' });
    }

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'DELETE_INVENTORY_ITEM',
      table_name: 'Inventory',
      record_id: item._id,
      owner_id: req.user._id
    });

    await Inventory.findByIdAndDelete(item._id);

    res.json({ message: '✅ Inventory item deleted successfully' });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Add Stock Input to Inventory Item
 * @route   POST /api/owner/inventory/input
 * @access  Private (Owner)
 */
exports.addStockInput = async (req, res, next) => {
  try {
    const { Inventory, StockInput } = require('../models/Inventory');
    const {
      item_id,
      quantity,
      supplier,
      batch_number,
      expiration_date,
      cost_per_unit,
      notes
    } = req.body;

    // Validate required fields
    if (!item_id || !quantity) {
      return res.status(400).json({ message: '⚠️ Item ID and quantity are required' });
    }

    // Find the inventory item
    const item = await Inventory.findOne({ 
      _id: item_id, 
      owner_id: req.user._id 
    });

    if (!item) {
      return res.status(404).json({ message: '❌ Inventory item not found' });
    }

    // Create stock input record
    const stockInput = new StockInput({
      item_id,
      quantity: parseInt(quantity),
      supplier,
      batch_number,
      expiration_date,
      cost_per_unit: cost_per_unit || 0,
      notes,
      input_date: new Date()
    });

    await stockInput.save();

    // Update inventory count
    item.count += parseInt(quantity);
    item.balance = item.count;
    if (expiration_date) {
      item.expiration_date = expiration_date;
    }
    await item.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      username: req.user.username,
      action: 'STOCK_INPUT',
      table_name: 'Inventory',
      record_id: item._id,
      owner_id: req.user._id,
      message: `Added ${quantity} units to ${item.name}`
    });

    // Check if stock is no longer low
    if (item.count > item.critical_level) {
      // Could send notification that stock is back to normal
    }

    res.status(201).json({ 
      message: '✅ Stock input added successfully', 
      item,
      stockInput
    });
  } catch (err) {
    next(err);
  }
};

// ==================== DASHBOARD & ANALYTICS ====================

/**
 * @desc    Get Dashboard Statistics
 * @route   GET /api/owner/dashboard
 * @access  Private (Owner)
 */
exports.getDashboard = async (req, res, next) => {
  try {
    // Get counts
    const [staffCount, deviceCount, testCount] = await Promise.all([
      Staff.countDocuments({ owner_id: req.user._id }),
      Device.countDocuments({ owner_id: req.user._id }),
      Test.countDocuments({ owner_id: req.user._id })
    ]);
    
    // Get unique patients who have orders with this lab
    const patientOrders = await Order.find({ owner_id: req.user._id }).distinct('patient_id');
    const patientCount = patientOrders.filter(id => id != null).length;
    
    const { Inventory } = require('../models/Inventory');
    const inventoryCount = await Inventory.countDocuments({ owner_id: req.user._id });

    // Get order statistics
    const totalOrders = await Order.countDocuments({ owner_id: req.user._id });
    const processingOrders = await Order.countDocuments({ owner_id: req.user._id, status: 'processing' });
    const completedOrders = await Order.countDocuments({ owner_id: req.user._id, status: 'completed' });

    // Get order details statistics
    const pendingTests = await OrderDetails.countDocuments({ status: 'pending' });
    const inProgressTests = await OrderDetails.countDocuments({ status: 'in_progress' });
    const completedTests = await OrderDetails.countDocuments({ status: 'completed' });

    // Get low stock items
    const inventoryItems = await Inventory.find({ owner_id: req.user._id });
    const lowStockItems = inventoryItems.filter(item => item.count <= item.critical_level);
    const expiringItems = inventoryItems.filter(item => {
      const daysUntilExpiry = Math.ceil((new Date(item.expiration_date) - new Date()) / (1000 * 60 * 60 * 24));
      return daysUntilExpiry <= 30 && daysUntilExpiry > 0;
    });

    // Get revenue statistics (current month)
    const startOfMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
    const invoices = await Invoice.find({ 
      owner_id: req.user._id,
      invoice_date: { $gte: startOfMonth }
    });
    
    const monthlyRevenue = invoices.reduce((sum, inv) => sum + (inv.total_amount || 0), 0);
    const paidInvoices = invoices.filter(inv => inv.payment_status === 'paid').length;
    const pendingInvoices = invoices.filter(inv => inv.payment_status === 'pending').length;

    // Get recent notifications
    const notifications = await Notification.find({ 
      receiver_id: req.user._id,
      receiver_model: 'Owner'
    })
    .sort({ createdAt: -1 })
    .limit(5);

    const unreadNotifications = await Notification.countDocuments({ 
      receiver_id: req.user._id,
      receiver_model: 'Owner',
      is_read: false
    });

    // Get subscription information
    const owner = await LabOwner.findById(req.user._id).select('subscription_end subscriptionFee lab_name');
    let subscriptionInfo = null;
    
    if (owner?.subscription_end) {
      const today = new Date();
      const endDate = new Date(owner.subscription_end);
      const daysRemaining = Math.ceil((endDate - today) / (1000 * 60 * 60 * 24));
      
      let status = 'active';
      let warning = null;
      
      if (daysRemaining < 0) {
        status = 'expired';
        warning = `⚠️ Your subscription expired ${Math.abs(daysRemaining)} days ago. Limited access - please renew immediately.`;
      } else if (daysRemaining <= 7) {
        status = 'expiring_soon';
        warning = `⚠️ Your subscription expires in ${daysRemaining} day(s). Please renew soon to avoid service interruption.`;
      } else if (daysRemaining <= 30) {
        status = 'expiring_within_month';
        warning = `ℹ️ Your subscription expires in ${daysRemaining} days.`;
      }
      
      subscriptionInfo = {
        endDate: owner.subscription_end,
        fee: owner.subscriptionFee || 0,
        labName: owner.lab_name,
        daysRemaining: Math.max(0, daysRemaining),
        status,
        warning,
        isExpiringSoon: daysRemaining <= 30,
        isExpired: daysRemaining < 0
      };
    }

    // Get renewal requests submitted by this owner with admin responses
    const renewalRequestsRaw = await Notification.find({
      sender_id: req.user._id,
      sender_model: 'Owner',
      type: 'renewal_request'
    })
    .sort({ createdAt: -1 })
    .limit(10);

    // Get admin responses to renewal requests
    const renewalRequestIds = renewalRequestsRaw.map(r => r._id);
    const adminResponses = await Notification.find({
      related_id: { $in: renewalRequestIds },
      receiver_model: 'Owner',
      type: { $in: ['subscription_approved', 'subscription_denied', 'subscription_renewal'] }
    }).sort({ createdAt: -1 });

    // Format renewal requests with responses
    const renewalRequests = renewalRequestsRaw.map(request => {
      const response = adminResponses.find(resp => 
        resp.related_id && resp.related_id.toString() === request._id.toString()
      );
      
      return {
        id: request._id,
        status: response ? (response.type === 'subscription_approved' ? 'approved' : 
                           response.type === 'subscription_denied' ? 'denied' : 'pending') : 'pending',
        requestedDate: request.createdAt,
        renewalPeriodMonths: request.metadata?.renewal_period_months || 1,
        renewalFee: request.metadata?.renewal_fee || 0,
        message: request.message,
        adminResponse: response ? {
          date: response.createdAt,
          message: response.message,
          type: response.type
        } : null
      };
    });

    res.json({
      resources: {
        staff: staffCount,
        devices: deviceCount,
        tests: testCount,
        patients: patientCount,
        inventory: inventoryCount
      },
      orders: {
        total: totalOrders,
        processing: processingOrders,
        completed: completedOrders
      },
      testDetails: {
        pending: pendingTests,
        inProgress: inProgressTests,
        completed: completedTests
      },
      inventory: {
        lowStock: lowStockItems.length,
        expiring: expiringItems.length,
        lowStockItems: lowStockItems.slice(0, 5),
        expiringItems: expiringItems.slice(0, 5)
      },
      financials: {
        monthlyRevenue,
        paidInvoices,
        pendingInvoices
      },
      notifications: {
        unread: unreadNotifications,
        recent: notifications
      },
      subscription: subscriptionInfo,
      renewalRequests: renewalRequests
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Performance Reports
 * @route   GET /api/owner/reports
 * @access  Private (Owner)
 */
/**
 * @desc    Get All Orders
 * @route   GET /api/owner/orders
 * @access  Private (Owner)
 */
exports.getAllOrders = async (req, res, next) => {
  try {
    const { status, startDate, endDate, page = 1, limit = 50 } = req.query;

    const query = { owner_id: req.user._id };
    
    // Filter by status if provided
    if (status) {
      query.status = status;
    }

    // Filter by date range if provided
    if (startDate || endDate) {
      query.order_date = {};
      if (startDate) query.order_date.$gte = new Date(startDate);
      if (endDate) query.order_date.$lte = new Date(endDate);
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const [orders, total] = await Promise.all([
      Order.find(query)
        .populate('patient_id', 'full_name patient_id phone_number email')
        .populate('doctor_id', 'name')
        .sort({ order_date: -1 })
        .skip(skip)
        .limit(parseInt(limit)),
      Order.countDocuments(query)
    ]);

    // Filter out orders where patient_id doesn't exist (deleted/invalid reference)
    // and where patient is not fully registered
    const validOrders = orders.filter(order => {
      // Include only if patient_id exists and populated successfully
      // OR if temp_patient_info exists (for orders awaiting patient registration)
      return order.patient_id || order.temp_patient_info?.full_name;
    });

    // OPTIMIZED: Fetch all order details and results in bulk (avoid N+1 queries)
    const orderIds = validOrders.map(o => o._id);
    
    // First, get all order details
    const allOrderDetails = await OrderDetails.find({ order_id: { $in: orderIds } })
      .populate('test_id', 'test_name test_code price')
      .populate('staff_id', 'full_name employee_number')
      .select('order_id test_id staff_id status')
      .lean();
    
    // Get all detail IDs
    const detailIds = allOrderDetails.map(d => d._id);
    
    // Get all results for these details
    const allResults = await Result.find({ detail_id: { $in: detailIds } }).lean();

    // Group order details by order_id for fast lookup
    const orderDetailsMap = {};
    allOrderDetails.forEach(detail => {
      const orderId = detail.order_id.toString();
      if (!orderDetailsMap[orderId]) {
        orderDetailsMap[orderId] = [];
      }
      orderDetailsMap[orderId].push(detail);
    });

    // Group results by detail_id for fast lookup
    const resultsMap = {};
    allResults.forEach(result => {
      resultsMap[result.detail_id.toString()] = result;
    });

    // Enrich orders with test details (now using in-memory data)
    const enrichedOrders = validOrders.map(order => {
      const orderObj = order.toObject();
      const orderId = order._id.toString();
      const orderDetails = orderDetailsMap[orderId] || [];
      
      // Add flattened patient and doctor names for easier access
      if (order.patient_id?.full_name) {
        orderObj.patient_name = `${order.patient_id.full_name.first || ''} ${order.patient_id.full_name.middle || ''} ${order.patient_id.full_name.last || ''}`.trim();
      } else if (order.temp_patient_info?.full_name) {
        orderObj.patient_name = `${order.temp_patient_info.full_name.first || ''} ${order.temp_patient_info.full_name.middle || ''} ${order.temp_patient_info.full_name.last || ''}`.trim();
      } else {
        orderObj.patient_name = 'Unknown Patient';
      }
      
      orderObj.doctor_name = order.doctor_id?.name || '-';
      
      // Add test details with staff assignments and results
      orderObj.order_details = orderDetails.map(detail => {
        const result = resultsMap[detail._id.toString()];
        return {
          test_name: detail.test_id?.test_name || 'Unknown Test',
          test_code: detail.test_id?.test_code,
          price: detail.test_id?.price,
          status: detail.status,
          staff_name: detail.staff_id?.full_name 
            ? `${detail.staff_id.full_name.first || ''} ${detail.staff_id.full_name.last || ''}`.trim()
            : null,
          staff_employee_number: detail.staff_id?.employee_number,
          has_result: !!result,
          result_value: result?.result_value || null,
          result_units: result?.units || null,
          result_reference_range: result?.reference_range || null,
          result_remarks: result?.remarks || null
        };
      });
      
      orderObj.test_count = orderDetails.length;
      
      return orderObj;
    });

    res.json({
      total: enrichedOrders.length,
      page: parseInt(page),
      totalPages: Math.ceil(enrichedOrders.length / parseInt(limit)),
      orders: enrichedOrders
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Order
 * @route   GET /api/owner/orders/:orderId
 * @access  Private (Owner)
 */
exports.getOrderById = async (req, res, next) => {
  try {
    const order = await Order.findOne({
      _id: req.params.orderId,
      owner_id: req.user._id
    })
      .populate('patient_id', 'full_name patient_id phone_number email identity_number')
      .populate('doctor_id', 'name phone_number email');

    if (!order) {
      return res.status(404).json({ message: '❌ Order not found' });
    }

    // Get order details (tests)
    const orderDetails = await OrderDetails.find({ order_id: order._id })
      .populate('test_id', 'test_name test_code price')
      .populate('staff_id', 'full_name employee_number');

    // Get results for each order detail
    const orderDetailsWithResults = await Promise.all(
      orderDetails.map(async (detail) => {
        const result = await Result.findOne({ detail_id: detail._id });
        
        // Check if test has components
        const testComponents = await TestComponent.find({ 
          test_id: detail.test_id._id,
          is_active: true 
        }).sort({ display_order: 1 });
        
        let components = [];
        let hasComponentResults = false;
        
        if (testComponents.length > 0 && result) {
          // Get component results
          const componentResults = await ResultComponent.find({ result_id: result._id })
            .populate('component_id', 'component_name component_code units reference_range');
            
          components = componentResults.map(compResult => ({
            component_name: compResult.component_name,
            component_code: compResult.component_id?.component_code || '',
            component_value: compResult.component_value,
            units: compResult.units || compResult.component_id?.units,
            reference_range: compResult.reference_range || compResult.component_id?.reference_range,
            is_abnormal: compResult.is_abnormal,
            remarks: compResult.remarks
          }));
          
          hasComponentResults = componentResults.length > 0;
        }
        
        // Determine if test is completed based on results or component results
        const isCompleted = result && (hasComponentResults || result.result_value);
        
        return {
          _id: detail._id,
          test_name: detail.test_id?.test_name || 'Unknown Test',
          test_code: detail.test_id?.test_code || '',
          price: detail.test_id?.price || 0,
          status: isCompleted ? 'completed' : detail.status,
          staff_name: detail.staff_id?.full_name || 'Unassigned',
          staff_employee_number: detail.staff_id?.employee_number || '',
          // Test-level result (for tests without components)
          result_value: result?.result_value,
          result_units: result?.units,
          result_reference_range: result?.reference_range,
          result_remarks: result?.remarks,
          // Component results (for tests with components)
          components: components,
          has_components: testComponents.length > 0,
          has_result: !!result,
          has_component_results: hasComponentResults,
          is_abnormal: result?.is_abnormal || components.some(c => c.is_abnormal),
          created_at: detail.createdAt,
          updated_at: detail.updatedAt
        };
      })
    );

    // Get invoice if exists
    const invoice = await Invoice.findOne({ order_id: order._id });

    res.json({
      _id: order._id,
      order_date: order.order_date,
      status: order.status,
      test_count: orderDetailsWithResults.length,
      patient: order.patient_id ? {
        name: order.patient_id.full_name,
        patient_id: order.patient_id.patient_id
      } : null,
      order_details: orderDetailsWithResults,
      invoice
    });
  } catch (err) {
    next(err);
  }
};

exports.getReports = async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;

    let start = startDate ? new Date(startDate) : new Date(new Date().setMonth(new Date().getMonth() - 1));
    let end = endDate ? new Date(endDate) : new Date();

    const query = { 
      owner_id: req.user._id,
      order_date: { $gte: start, $lte: end }
    };

    // Get orders in date range
    const orders = await Order.find(query).populate('patient_id', 'full_name patient_id');

    // Get invoices in date range
    const invoices = await Invoice.find({
      owner_id: req.user._id,
      invoice_date: { $gte: start, $lte: end }
    });

    const totalRevenue = invoices.reduce((sum, inv) => sum + (inv.total_amount || 0), 0);
    const paidRevenue = invoices
      .filter(inv => inv.payment_status === 'paid')
      .reduce((sum, inv) => sum + (inv.total_amount || 0), 0);

    // Get staff performance
    const orderDetails = await OrderDetails.find({
      status: 'completed'
    }).populate({
      path: 'order_id',
      match: { owner_id: req.user._id, order_date: { $gte: start, $lte: end } }
    });

    const staffPerformance = {};
    for (const detail of orderDetails) {
      if (detail.order_id && detail.staff_id) {
        const staffId = detail.staff_id.toString();
        if (!staffPerformance[staffId]) {
          staffPerformance[staffId] = { count: 0, staff_id: staffId };
        }
        staffPerformance[staffId].count++;
      }
    }

    // Populate staff names
    const staffIds = Object.keys(staffPerformance);
    const staffMembers = await Staff.find({ _id: { $in: staffIds } }).select('full_name employee_number');
    staffMembers.forEach(staff => {
      if (staffPerformance[staff._id.toString()]) {
        staffPerformance[staff._id.toString()].name = `${staff.full_name.first} ${staff.full_name.last}`;
        staffPerformance[staff._id.toString()].employee_number = staff.employee_number;
      }
    });

    // Get expenses
    const staff = await Staff.find({ owner_id: req.user._id });
    const totalSalaries = staff.reduce((sum, s) => sum + (s.salary || 0), 0);
    
    // Calculate subscription fee
    const subscriptionFee = await calculateTieredFee(req.user._id);
    const subscriptions = subscriptionFee.total;
    
    // Inventory expenses - placeholder for now (set to 0)
    const inventory = 0;

    res.json({
      period: { start, end },
      orders: {
        total: orders.length,
        completed: orders.filter(o => o.status === 'completed').length,
        processing: orders.filter(o => o.status === 'processing').length
      },
      revenue: {
        total: totalRevenue,
        paid: paidRevenue,
        pending: totalRevenue - paidRevenue
      },
      expenses: {
        salaries: totalSalaries,
        subscriptions: subscriptions,
        inventory: inventory
      },
      staffPerformance: Object.values(staffPerformance).sort((a, b) => b.count - a.count)
    });
  } catch (err) {
    next(err);
  }
};

// ==================== NOTIFICATIONS ====================

/**
 * @desc    Get All Notifications
 * @route   GET /api/owner/notifications
 * @access  Private (Owner)
 */
exports.getNotifications = async (req, res, next) => {
  try {
    const { unreadOnly } = req.query;
    
    const query = {
      receiver_id: req.user._id,
      receiver_model: 'Owner'
    };

    if (unreadOnly === 'true') {
      query.is_read = false;
    }

    // Don't use populate with refPath since 'System' is not an actual model
    // Instead, fetch notifications without populate and handle sender info separately
    const notifications = await Notification.find(query)
      .sort({ createdAt: -1 })
      .lean();

    // Process notifications to add sender info where applicable
    const processedNotifications = await Promise.all(
      notifications.map(async (notification) => {
        // If sender is 'System', don't try to populate
        if (notification.sender_model === 'System' || !notification.sender_id) {
          return {
            ...notification,
            sender_info: notification.sender_model === 'System' 
              ? { name: 'System', username: 'system' }
              : null
          };
        }

        // Manually fetch sender info based on sender_model
        try {
          let senderInfo = null;
          switch (notification.sender_model) {
            case 'Admin':
              const Admin = require('../models/Admin');
              senderInfo = await Admin.findById(notification.sender_id).select('name username').lean();
              break;
            case 'Owner':
              const Owner = require('../models/Owner');
              senderInfo = await Owner.findById(notification.sender_id).select('name username').lean();
              break;
            case 'Doctor':
              const Doctor = require('../models/Doctor');
              senderInfo = await Doctor.findById(notification.sender_id).select('name username').lean();
              break;
            case 'Staff':
              const Staff = require('../models/Staff');
              senderInfo = await Staff.findById(notification.sender_id).select('full_name username').lean();
              if (senderInfo?.full_name) {
                senderInfo.name = senderInfo.full_name;
              }
              break;
            case 'Patient':
              const Patient = require('../models/Patient');
              senderInfo = await Patient.findById(notification.sender_id).select('name username').lean();
              break;
          }
          return { ...notification, sender_info: senderInfo };
        } catch (e) {
          return { ...notification, sender_info: null };
        }
      })
    );

    res.json({ count: processedNotifications.length, notifications: processedNotifications });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Mark Notification as Read
 * @route   PUT /api/owner/notifications/:notificationId/read
 * @access  Private (Owner)
 */
exports.markNotificationAsRead = async (req, res, next) => {
  try {
    const notification = await Notification.findOne({
      _id: req.params.notificationId,
      receiver_id: req.user._id,
      receiver_model: 'Owner'
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

/**
 * @desc    Send Notification to Staff
 * @route   POST /api/owner/notifications/send
 * @access  Private (Owner)
 */
exports.sendNotificationToStaff = async (req, res, next) => {
  try {
    const { staff_id, title, message, type } = req.body;

    if (!staff_id || !title || !message) {
      return res.status(400).json({ message: '⚠️ Staff ID, title, and message are required' });
    }

    // Verify staff belongs to this owner
    const staff = await Staff.findOne({ _id: staff_id, owner_id: req.user._id });
    if (!staff) {
      return res.status(404).json({ message: '❌ Staff member not found' });
    }

    const notification = await Notification.create({
      sender_id: req.user._id,
      sender_model: 'Owner',
      receiver_id: staff_id,
      receiver_model: 'Staff',
      type: type || 'system',
      title,
      message
    });

    res.status(201).json({ 
      message: '✅ Notification sent successfully', 
      notification 
    });
  } catch (err) {
    next(err);
  }
};

// ==================== COMMUNICATION WITH ADMIN ====================

/**
 * @desc    Request Subscription Renewal
 * @route   POST /api/owner/request-renewal
 * @access  Private (Owner)
 */
exports.requestSubscriptionRenewal = async (req, res, next) => {
  try {
    const { renewal_duration, message } = req.body;

    const owner = await LabOwner.findById(req.user._id);
    
    // Calculate days until expiration
    const today = new Date();
    const endDate = new Date(owner.subscription_end);
    const daysRemaining = Math.ceil((endDate - today) / (1000 * 60 * 60 * 24));

    // Get the admin who approved this owner
    const Admin = require('../models/Admin');
    const admin = await Admin.findById(owner.admin_id);

    if (!admin) {
      return res.status(404).json({ message: '❌ Admin not found' });
    }

    const renewalMessage = message || 
      `I would like to renew my lab subscription for ${renewal_duration || 'another year'}. ` +
      `Current subscription ${daysRemaining < 0 ? `expired ${Math.abs(daysRemaining)} days ago` : `expires in ${daysRemaining} days`}.`;

    const notification = await Notification.create({
      sender_id: req.user._id,
      sender_model: 'Owner',
      receiver_id: admin._id,
      receiver_model: 'Admin',
      type: 'subscription',
      title: '🔄 Subscription Renewal Request',
      message: `From Lab Owner (${owner.name.first} ${owner.name.last}): ${renewalMessage}`
    });

    // 📱 Send push notification to admin if Firebase is available
    try {
      const notificationController = require('./notificationController');
      const pushResult = await notificationController.sendPushNotificationToAdmin(
        admin._id,
        '🔄 Subscription Renewal Request',
        `Lab Owner (${owner.name.first} ${owner.name.last}) requested subscription renewal.`,
        {
          type: 'subscription',
          owner_id: owner._id.toString(),
          owner_name: `${owner.name.first} ${owner.name.last}`,
          receiver_model: 'Admin'
        }
      );

      if (pushResult) {
        console.log('✅ DEBUG: Push notification sent to admin successfully');
      } else {
        console.log('📱 DEBUG: Push notification not sent to admin (Firebase not available or no token)');
      }
    } catch (pushError) {
      console.error('Failed to send push notification to admin (this does not affect request):', pushError);
    }

    res.status(201).json({ 
      message: '✅ Subscription renewal request sent to admin successfully',
      currentSubscriptionEnd: owner.subscription_end,
      daysRemaining: daysRemaining > 0 ? daysRemaining : 0,
      notification 
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Send Message to Admin
 * @route   POST /api/owner/contact-admin
 * @access  Private (Owner)
 */
exports.contactAdmin = async (req, res, next) => {
  try {
    const { title, message } = req.body;

    if (!title || !message) {
      return res.status(400).json({ message: '⚠️ Title and message are required' });
    }

    const owner = await LabOwner.findById(req.user._id);
    
    // Get the admin who approved this owner
    const Admin = require('../models/Admin');
    const admin = await Admin.findById(owner.admin_id);

    if (!admin) {
      return res.status(404).json({ message: '❌ Admin not found' });
    }

    const notification = await Notification.create({
      sender_id: req.user._id,
      sender_model: 'Owner',
      receiver_id: admin._id,
      receiver_model: 'Admin',
      type: 'system',
      title,
      message: `From Lab Owner (${owner.name.first} ${owner.name.last}): ${message}`
    });

    // Send WhatsApp notification to admin
    if (admin.phone_number) {
      try {
        const whatsappMessage = `📬 New Message from Lab Owner\n\n🏥 Lab: ${owner.lab_name}\n👤 Owner: ${owner.name.first} ${owner.name.last}\n📧 Email: ${owner.email}\n📱 Phone: ${owner.phone_number}\n\n📝 Subject: ${title}\n💬 Message:\n${message}\n\nPlease respond within 24 hours.`;

        const whatsappSuccess = await sendWhatsAppMessage(
          admin.phone_number,
          whatsappMessage,
          [],
          false, // Don't fallback to email since notification is already created
          '',
          ''
        );

        if (whatsappSuccess) {
          // WhatsApp sent successfully
        }
      } catch (whatsappErr) {
        console.error('Failed to send WhatsApp notification to admin:', whatsappErr);
        // Don't fail the request if WhatsApp fails
      }
    }

    res.status(201).json({ 
      message: '✅ Message sent to admin successfully', 
      notification 
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Reply to Notification
 * @route   POST /api/owner/notifications/:notificationId/reply
 * @access  Private (Owner)
 */
exports.replyToNotification = async (req, res, next) => {
  try {
    const { notificationId } = req.params;
    const { message } = req.body;

    if (!message) {
      return res.status(400).json({ message: '⚠️ Reply message is required' });
    }

    // Get the original notification
    const originalNotification = await Notification.findOne({
      _id: notificationId,
      receiver_id: req.user._id,
      receiver_model: 'Owner'
    });

    if (!originalNotification) {
      return res.status(404).json({ message: '❌ Notification not found' });
    }

    // Determine conversation_id (use parent's conversation_id or original notification's _id)
    const conversationId = originalNotification.conversation_id || originalNotification._id;

    // Create reply notification
    const replyNotification = await Notification.create({
      sender_id: req.user._id,
      sender_model: 'Owner',
      receiver_id: originalNotification.sender_id,
      receiver_model: originalNotification.sender_model,
      type: 'message',
      title: `Re: ${originalNotification.title}`,
      message,
      parent_id: notificationId,
      conversation_id: conversationId,
      is_reply: true
    });

    // Update original notification's conversation_id if it doesn't have one
    if (!originalNotification.conversation_id) {
      originalNotification.conversation_id = originalNotification._id;
      await originalNotification.save();
    }

    res.status(201).json({
      message: '✅ Reply sent successfully',
      notification: replyNotification
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Conversation Thread
 * @route   GET /api/owner/notifications/:notificationId/conversation
 * @access  Private (Owner)
 */
exports.getConversationThread = async (req, res, next) => {
  try {
    const { notificationId } = req.params;

    // Get the notification to find its conversation_id
    const notification = await Notification.findById(notificationId);

    if (!notification) {
      return res.status(404).json({ message: '❌ Notification not found' });
    }

    // Verify owner has access to this conversation
    if (notification.receiver_id.toString() !== req.user._id.toString() &&
        notification.sender_id?.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: '❌ Access denied' });
    }

    const conversationId = notification.conversation_id || notification._id;

    // Get all messages in the conversation
    const messages = await Notification.find({
      $or: [
        { _id: conversationId },
        { conversation_id: conversationId }
      ]
    })
    .sort({ createdAt: 1 });

    res.json({
      conversation_id: conversationId,
      message_count: messages.length,
      messages
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get All Conversations (grouped notifications)
 * @route   GET /api/owner/conversations
 * @access  Private (Owner)
 */
exports.getConversations = async (req, res, next) => {
  try {
    // Get all notifications where owner is sender or receiver
    const allNotifications = await Notification.find({
      $or: [
        { receiver_id: req.user._id, receiver_model: 'Owner' },
        { sender_id: req.user._id, sender_model: 'Owner' }
      ]
    })
    .sort({ createdAt: -1 });

    // Group by conversation_id
    const conversationMap = new Map();

    for (const notification of allNotifications) {
      const convId = (notification.conversation_id || notification._id).toString();
      
      if (!conversationMap.has(convId)) {
        conversationMap.set(convId, {
          conversation_id: convId,
          messages: [],
          last_message: notification,
          unread_count: 0,
          participant: notification.sender_id?.toString() === req.user._id.toString()
            ? notification.receiver_id
            : notification.sender_id
        });
      }

      const conversation = conversationMap.get(convId);
      conversation.messages.push(notification);
      
      // Update last message if this one is newer
      if (new Date(notification.createdAt) > new Date(conversation.last_message.createdAt)) {
        conversation.last_message = notification;
      }

      // Count unread messages
      if (!notification.is_read && notification.receiver_id?.toString() === req.user._id.toString()) {
        conversation.unread_count++;
      }
    }

    // Convert map to array and sort by last message time
    const conversations = Array.from(conversationMap.values())
      .sort((a, b) => new Date(b.last_message.createdAt) - new Date(a.last_message.createdAt));

    res.json({
      total: conversations.length,
      conversations
    });
  } catch (err) {
    next(err);
  }
};

// ==================== AUDIT LOGS ====================

/**
 * @desc    Get Audit Logs
 * @route   GET /api/owner/audit-logs
 * @access  Private (Owner)
 */
// ==================== PATIENTS VIEW (Read-Only) ====================

/**
 * @desc    Get All Patients (who had tests in this lab)
 * @route   GET /api/owner/patients
 * @access  Private (Owner)
 */
exports.getAllPatients = async (req, res, next) => {
  try {
    // Get all orders for this lab
    const orders = await Order.find({ owner_id: req.user._id })
      .populate('patient_id', 'full_name identity_number patient_id phone_number email')
      .select('patient_id');

    // Extract unique patient IDs
    const patientIds = [...new Set(orders.map(o => o.patient_id?._id?.toString()).filter(Boolean))];
    
    const patients = await Patient.find({ _id: { $in: patientIds } }).select('-password');

    res.json({ count: patients.length, patients });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Patient Details
 * @route   GET /api/owner/patients/:patientId
 * @access  Private (Owner)
 */
exports.getPatientById = async (req, res, next) => {
  try {
    const patient = await Patient.findById(req.params.patientId).select('-password');
    
    if (!patient) {
      return res.status(404).json({ message: '❌ Patient not found' });
    }

    // Verify patient has orders in this lab
    const hasOrders = await Order.findOne({ 
      patient_id: patient._id, 
      owner_id: req.user._id 
    });

    if (!hasOrders) {
      return res.status(403).json({ message: '⚠️ No records found for this patient in your lab' });
    }

    // Get patient's order history in this lab
    const orders = await Order.find({ 
      patient_id: patient._id, 
      owner_id: req.user._id 
    }).populate('requested_by', 'full_name');

    res.json({ patient, orderHistory: orders });
  } catch (err) {
    next(err);
  }
};

// ==================== FEEDBACK METHODS ====================

/**
 * @desc    Provide Feedback
 * @route   POST /api/owner/feedback
 * @access  Private (Owner)
 */
exports.provideFeedback = async (req, res, next) => {
  try {
    const owner_id = req.user._id;
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

    // Validate target exists and owner has access (skip for system feedback)
    let targetExists = target_type === 'system';
    let targetOwnerId = null;

    if (target_type !== 'system') {
      switch (target_type) {
        case 'lab':
          const lab = await LabOwner.findById(target_id);
          if (lab) {
            targetExists = true;
            targetOwnerId = lab._id;
          }
          break;
        case 'test':
          const test = await Test.findById(target_id);
          if (test && test.owner_id.toString() === owner_id.toString()) {
            targetExists = true;
            targetOwnerId = test.owner_id;
          }
          break;
        case 'order':
          const order = await Order.findOne({
            _id: target_id,
            owner_id: owner_id
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
      user_id: owner_id,
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
      user_id: owner_id,
      user_model: 'Owner',
      target_type,
      target_id: target_type === 'system' ? null : target_id,
      target_model,
      rating,
      message: message || '',
      is_anonymous: is_anonymous || false
    });

    await feedback.save();

    // Send notification to lab owner (skip for system feedback or self-feedback)
    if (targetOwnerId && targetOwnerId.toString() !== owner_id.toString()) {
      await Notification.create({
        sender_id: owner_id,
        sender_model: 'Owner',
        receiver_id: targetOwnerId,
        receiver_model: 'Owner',
        type: 'feedback',
        title: '⭐ New Feedback Received',
        message: `Lab owner provided ${rating}-star feedback on your ${target_type}`
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
 * @route   GET /api/owner/feedback
 * @access  Private (Owner)
 */
exports.getMyFeedback = async (req, res, next) => {
  try {
    const owner_id = req.user._id;
    const { page = 1, limit = 10, target_type } = req.query;

    const query = {
      user_id: owner_id,
      user_model: 'Owner'
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

// ==================== TEST COMPONENT MANAGEMENT ====================

/**
 * @desc    Add component to a test
 * @route   POST /api/owner/tests/:testId/components
 * @access  Private (Owner)
 */
exports.addTestComponent = async (req, res, next) => {
  try {
    const { testId } = req.params;
    const ownerId = req.user._id;
    const {
      component_name,
      component_code,
      units,
      reference_range,
      min_value,
      max_value,
      display_order,
      description
    } = req.body;

    // Verify test exists and belongs to owner
    const test = await Test.findOne({ _id: testId, owner_id: ownerId });
    if (!test) {
      return res.status(404).json({ 
        success: false, 
        message: 'Test not found or you do not have permission to modify it' 
      });
    }

    // Create test component
    const component = await TestComponent.create({
      test_id: testId,
      component_name,
      component_code,
      units,
      reference_range,
      min_value,
      max_value,
      display_order: display_order || 0,
      description
    });

    res.status(201).json({
      success: true,
      message: 'Test component added successfully',
      component
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get all components for a test
 * @route   GET /api/owner/tests/:testId/components
 * @access  Private (Owner)
 */
exports.getTestComponents = async (req, res, next) => {
  try {
    const { testId } = req.params;
    const ownerId = req.user._id;

    // Verify test exists and belongs to owner
    const test = await Test.findOne({ _id: testId, owner_id: ownerId });
    if (!test) {
      return res.status(404).json({ 
        success: false, 
        message: 'Test not found or you do not have permission to view it' 
      });
    }

    // Get all components for this test
    const components = await TestComponent.find({ 
      test_id: testId, 
      is_active: true 
    }).sort({ display_order: 1, createdAt: 1 });

    res.json({
      success: true,
      test: {
        _id: test._id,
        test_name: test.test_name,
        test_code: test.test_code
      },
      components,
      count: components.length
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update a test component
 * @route   PUT /api/owner/tests/:testId/components/:componentId
 * @access  Private (Owner)
 */
exports.updateTestComponent = async (req, res, next) => {
  try {
    const { testId, componentId } = req.params;
    const ownerId = req.user._id;
    const updateData = req.body;

    // Verify test exists and belongs to owner
    const test = await Test.findOne({ _id: testId, owner_id: ownerId });
    if (!test) {
      return res.status(404).json({ 
        success: false, 
        message: 'Test not found or you do not have permission to modify it' 
      });
    }

    // Find and update component
    const component = await TestComponent.findOneAndUpdate(
      { _id: componentId, test_id: testId },
      { $set: updateData },
      { new: true, runValidators: true }
    );

    if (!component) {
      return res.status(404).json({ 
        success: false, 
        message: 'Test component not found' 
      });
    }

    res.json({
      success: true,
      message: 'Test component updated successfully',
      component
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Delete a test component
 * @route   DELETE /api/owner/tests/:testId/components/:componentId
 * @access  Private (Owner)
 */
exports.deleteTestComponent = async (req, res, next) => {
  try {
    const { testId, componentId } = req.params;
    const ownerId = req.user._id;

    // Verify test exists and belongs to owner
    const test = await Test.findOne({ _id: testId, owner_id: ownerId });
    if (!test) {
      return res.status(404).json({ 
        success: false, 
        message: 'Test not found or you do not have permission to modify it' 
      });
    }

    // Soft delete component (set is_active to false)
    const component = await TestComponent.findOneAndUpdate(
      { _id: componentId, test_id: testId },
      { $set: { is_active: false } },
      { new: true }
    );

    if (!component) {
      return res.status(404).json({ 
        success: false, 
        message: 'Test component not found' 
      });
    }

    res.json({
      success: true,
      message: 'Test component deleted successfully'
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get All Results for Owner's Lab
 * @route   GET /api/owner/results
 * @access  Private (Owner)
 */
exports.getAllResults = async (req, res, next) => {
  try {
    const { page = 1, limit = 50, startDate, endDate, status, patientName, testName } = req.query;

    // Build query for results through order details
    let query = { owner_id: req.user._id };

    // Filter by date range if provided
    if (startDate || endDate) {
      query.order_date = {};
      if (startDate) query.order_date.$gte = new Date(startDate);
      if (endDate) query.order_date.$lte = new Date(endDate);
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    // Get orders with their details and results
    const orders = await Order.find(query)
      .populate('patient_id', 'full_name patient_id phone_number email')
      .populate('doctor_id', 'name')
      .sort({ order_date: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    // Filter out orders where patient_id doesn't exist
    const validOrders = orders.filter(order => order.patient_id);

    if (validOrders.length === 0) {
      return res.json({
        total: 0,
        page: parseInt(page),
        totalPages: 0,
        results: []
      });
    }

    // Get all order details for these orders
    const orderIds = validOrders.map(o => o._id);
    const orderDetails = await OrderDetails.find({ order_id: { $in: orderIds } })
      .populate('test_id', 'test_name test_code price')
      .populate('staff_id', 'full_name employee_number')
      .select('order_id test_id staff_id status result_id');

    // Get all results for these order details
    const detailIds = orderDetails.map(d => d._id);
    const results = await Result.find({ detail_id: { $in: detailIds } })
      .sort({ createdAt: -1 });

    // Group results by order
    const resultsByOrder = {};

    for (const order of validOrders) {
      const orderObj = order.toObject();
      const orderDetailIds = orderDetails
        .filter(d => d.order_id.toString() === order._id.toString())
        .map(d => d._id);

      const orderResults = results.filter(r => orderDetailIds.includes(r.detail_id));

      if (orderResults.length > 0) {
        // Apply filters
        let filteredResults = orderResults;

        if (status) {
          filteredResults = filteredResults.filter(r => r.status === status);
        }

        if (patientName) {
          const patientFullName = `${order.patient_id.full_name.first} ${order.patient_id.full_name.last}`.toLowerCase();
          if (!patientFullName.includes(patientName.toLowerCase())) {
            continue;
          }
        }

        if (testName) {
          filteredResults = filteredResults.filter(r => {
            const detail = orderDetails.find(d => d._id.toString() === r.detail_id.toString());
            return detail && detail.test_id && detail.test_id.test_name.toLowerCase().includes(testName.toLowerCase());
          });
        }

        if (filteredResults.length > 0) {
          resultsByOrder[order._id] = {
            order: {
              _id: order._id,
              order_id: order.order_id,
              order_date: order.order_date,
              status: order.status,
              patient_name: `${order.patient_id.full_name.first} ${order.patient_id.full_name.last}`,
              patient_id: order.patient_id.patient_id,
              doctor_name: order.doctor_id?.name || '-'
            },
            results: filteredResults.map(result => {
              const detail = orderDetails.find(d => d._id.toString() === result.detail_id.toString());
              return {
                _id: result._id,
                test_name: detail?.test_id?.test_name || 'Unknown Test',
                test_code: detail?.test_id?.test_code,
                result_value: result.result_value,
                units: result.units,
                reference_range: result.reference_range,
                status: result.status,
                remarks: result.remarks,
                created_at: result.createdAt,
                staff_name: detail?.staff_id ? `${detail.staff_id.full_name.first} ${detail.staff_id.full_name.last}` : null,
                component_name: result.component_name
              };
            })
          };
        }
      }
    }

    const allResults = Object.values(resultsByOrder);
    const totalResults = allResults.length;

    res.json({
      total: totalResults,
      page: parseInt(page),
      totalPages: Math.ceil(totalResults / parseInt(limit)),
      results: allResults.slice(0, parseInt(limit))
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get All Invoices for Owner's Lab
 * @route   GET /api/owner/invoices
 * @access  Private (Owner)
 */
exports.getAllInvoices = async (req, res, next) => {
  try {
    const { page = 1, limit = 50, startDate, endDate, status, patientName } = req.query;

    let query = { owner_id: req.user._id };

    // Filter by date range if provided
    if (startDate || endDate) {
      query.invoice_date = {};
      if (startDate) query.invoice_date.$gte = new Date(startDate);
      if (endDate) query.invoice_date.$lte = new Date(endDate);
    }

    // Filter by payment status if provided
    if (status) {
      query.payment_status = status;
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const invoices = await Invoice.find(query)
      .populate({
        path: 'order_id',
        populate: [
          { path: 'patient_id', select: 'full_name patient_id phone_number email' },
          { path: 'doctor_id', select: 'name' }
        ]
      })
      .sort({ invoice_date: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    // Filter by patient name if provided
    let filteredInvoices = invoices;
    if (patientName) {
      filteredInvoices = invoices.filter(invoice => {
        if (invoice.order_id?.patient_id?.full_name) {
          const fullName = `${invoice.order_id.patient_id.full_name.first} ${invoice.order_id.patient_id.full_name.last}`.toLowerCase();
          return fullName.includes(patientName.toLowerCase());
        }
        return false;
      });
    }

    const total = await Invoice.countDocuments(query);

    const formattedInvoices = filteredInvoices.map(invoice => ({
      _id: invoice._id,
      invoice_id: invoice.invoice_id,
      invoice_date: invoice.invoice_date,
      due_date: invoice.due_date,
      total_amount: invoice.total_amount,
      payment_status: invoice.payment_status,
      payment_date: invoice.payment_date,
      payment_method: invoice.payment_method,
      notes: invoice.notes,
      order: invoice.order_id ? {
        _id: invoice.order_id._id,
        order_id: invoice.order_id.order_id,
        order_date: invoice.order_id.order_date,
        status: invoice.order_id.status,
        patient_name: invoice.order_id.patient_id ?
          `${invoice.order_id.patient_id.full_name.first} ${invoice.order_id.patient_id.full_name.last}` : 'Unknown Patient',
        patient_id: invoice.order_id.patient_id?.patient_id,
        doctor_name: invoice.order_id.doctor_id?.name || '-'
      } : null
    }));

    res.json({
      total: patientName ? formattedInvoices.length : total,
      page: parseInt(page),
      totalPages: Math.ceil((patientName ? formattedInvoices.length : total) / parseInt(limit)),
      invoices: formattedInvoices
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Invoice Details by Invoice ID
 * @route   GET /api/owner/invoices/:invoiceId
 * @access  Private (Owner)
 */
exports.getInvoiceDetails = async (req, res) => {
  try {
    const { invoiceId } = req.params;
    const owner_id = req.user._id;

    const invoice = await Invoice.findOne({
      _id: invoiceId,
      owner_id: owner_id
    })
      .populate({
        path: 'order_id',
        populate: [
          { path: 'patient_id', select: 'full_name identity_number patient_id email phone_number birthday gender' },
          { path: 'doctor_id', select: 'name' }
        ]
      })
      .populate('owner_id', 'lab_name name address phone_number email')
      .populate('items.test_id', 'test_name test_code');

    if (!invoice) {
      return res.status(404).json({ message: "Invoice not found or access denied" });
    }

    // Check if invoice has a valid order
    if (!invoice.order_id) {
      // If no order_id, try to provide invoice details using the invoice's items array
      const subtotal = invoice.subtotal || invoice.items?.reduce((sum, item) => sum + (item.price || 0) * (item.quantity || 1), 0) || 0;
      const tax = 0;
      const discount = invoice.discount || 0;
      const total = subtotal + tax - discount;

      const labInfo = {
        name: invoice.owner_id?.lab_name || invoice.owner_id?.name || 'Medical Laboratory',
        address: invoice.owner_id?.address
          ? `${invoice.owner_id.address.street || ''}, ${invoice.owner_id.address.city || ''}, ${invoice.owner_id.address.state || ''} ${invoice.owner_id.address.postal_code || ''}`.trim().replace(/^,\s*/, '').replace(/,\s*$/, '')
          : null,
        phone: invoice.owner_id?.phone_number,
        email: invoice.owner_id?.email
      };

      return res.json({
        success: true,
        invoice: {
          _id: invoice._id,
          invoice_id: invoice.invoice_id,
          invoice_date: invoice.invoice_date,
          due_date: null,
          payment_status: 'paid',
          payment_date: invoice.payment_date,
          payment_method: invoice.payment_method,
          notes: invoice.remarks,
          order_id: null,
          order_date: null
        },
        lab: labInfo,
        patient: { name: 'Unknown Patient', patient_id: 'N/A', email: null, phone: null, age: null, gender: null },
        doctor: null,
        tests: invoice.items?.map(item => ({
          test_name: item.test_id?.test_name || item.test_name || 'Unknown Test',
          test_code: item.test_id?.test_code || 'N/A',
          price: item.price || 0,
          status: 'completed'
        })) || [],
        totals: {
          subtotal: subtotal,
          tax: tax,
          discount: discount,
          total: total,
          amount_paid: invoice.amount_paid || 0,
          balance_due: total - (invoice.amount_paid || 0)
        },
        warning: 'This invoice has no associated order. Some information may be limited.'
      });
    }

    // Get order details (tests)
    const details = await OrderDetails.find({ order_id: invoice.order_id._id })
      .populate('test_id', 'test_name test_code price');

    // Calculate totals
    const subtotal = invoice.subtotal || details.reduce((sum, d) => sum + (d.test_id?.price || 0), 0);
    const tax = 0;
    const discount = invoice.discount || 0;
    const total = invoice.total_amount || (subtotal + tax - discount);

    // Get patient info
    const patientInfo = invoice.order_id.patient_id
      ? {
          name: `${invoice.order_id.patient_id.full_name?.first || ''} ${invoice.order_id.patient_id.full_name?.last || ''}`.trim(),
          patient_id: invoice.order_id.patient_id.patient_id,
          email: invoice.order_id.patient_id.email,
          phone: invoice.order_id.patient_id.phone_number,
          age: invoice.order_id.patient_id.birthday ? Math.floor((new Date() - new Date(invoice.order_id.patient_id.birthday)) / 31557600000) : null,
          gender: invoice.order_id.patient_id.gender
        }
      : invoice.order_id.temp_patient_info || { name: 'Walk-in Patient', patient_id: 'N/A', email: null, phone: null, age: null, gender: null };

    // Get lab info
    const labInfo = {
      name: invoice.owner_id?.lab_name || invoice.owner_id?.name || 'Medical Laboratory',
      address: invoice.owner_id?.address
        ? `${invoice.owner_id.address.street || ''}, ${invoice.owner_id.address.city || ''}, ${invoice.owner_id.address.state || ''} ${invoice.owner_id.address.postal_code || ''}`.trim().replace(/^,\s*/, '').replace(/,\s*$/, '')
        : null,
      phone: invoice.owner_id?.phone_number,
      email: invoice.owner_id?.email
    };

    res.json({
      success: true,
      invoice: {
        _id: invoice._id,
        invoice_id: invoice.invoice_id,
        invoice_date: invoice.invoice_date,
        due_date: invoice.due_date,
        payment_status: 'paid',
        payment_date: invoice.payment_date,
        payment_method: invoice.payment_method,
        notes: invoice.notes,
        order_id: invoice.order_id._id,
        order_date: invoice.order_id.order_date
      },
      lab: labInfo,
      patient: patientInfo,
      doctor: invoice.order_id.doctor_id?.name
        ? `Dr. ${invoice.order_id.doctor_id.name.first || ''} ${invoice.order_id.doctor_id.name.middle || ''} ${invoice.order_id.doctor_id.name.last || ''}`.trim()
        : null,
      tests: details.map(d => ({
        test_name: d.test_id?.test_name || 'Unknown Test',
        test_code: d.test_id?.test_code || 'N/A',
        price: d.test_id?.price || 0,
        status: d.status
      })),
      totals: {
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        total: total,
        amount_paid: invoice.amount_paid || 0,
        balance_due: total - (invoice.amount_paid || 0)
      }
    });

  } catch (err) {
    console.error("Error fetching invoice details:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get Invoice by Order ID
 * @route   GET /api/owner/invoices/order/:orderId
 * @access  Private (Owner)
 */
exports.getInvoiceByOrderId = async (req, res) => {
  try {
    const { orderId } = req.params;
    const owner_id = req.user._id;

    const invoice = await Invoice.findOne({
      order_id: orderId,
      owner_id: owner_id
    })
      .populate({
        path: 'order_id',
        populate: [
          { path: 'patient_id', select: 'full_name patient_id email phone_number birthday gender' },
          { path: 'doctor_id', select: 'name' }
        ]
      })
      .populate('owner_id', 'lab_name name address phone_number email');

    if (!invoice) {
      return res.status(404).json({ message: "Invoice not found for this order" });
    }

    res.json({
      success: true,
      invoice: {
        _id: invoice._id,
        invoice_id: invoice.invoice_id,
        invoice_date: invoice.invoice_date,
        due_date: invoice.due_date,
        payment_status: 'paid',
        payment_date: invoice.payment_date,
        payment_method: invoice.payment_method,
        notes: invoice.notes,
        order_id: invoice.order_id._id,
        order_date: invoice.order_id.order_date,
        total_amount: invoice.total_amount
      }
    });

  } catch (err) {
    console.error("Error fetching invoice by order ID:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get Audit Logs
 * @route   GET /api/owner/audit-logs
 * @access  Private (Owner)
 */
exports.getAuditLogs = async (req, res, next) => {
  try {
    const { page = 1, limit = 50, startDate, endDate, action, staff_id } = req.query;

    const query = { owner_id: req.user._id };

    // Filter by date range
    if (startDate || endDate) {
      query.timestamp = {};
      if (startDate) query.timestamp.$gte = new Date(startDate);
      if (endDate) query.timestamp.$lte = new Date(endDate);
    }

    // Filter by action type
    if (action) {
      query.action = action;
    }

    // Filter by staff member
    if (staff_id) {
      query.staff_id = staff_id;
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const [auditLogs, total] = await Promise.all([
      AuditLog.find(query)
        .populate('staff_id', 'full_name employee_number')
        .sort({ timestamp: -1 })
        .skip(skip)
        .limit(parseInt(limit)),
      AuditLog.countDocuments(query)
    ]);

    // Also fetch staff members to get employee_number by username if staff_id didn't populate
    const staffMembers = await Staff.find({ owner_id: req.user._id }).select('username employee_number full_name');
    const staffByUsername = {};
    staffMembers.forEach(s => {
      staffByUsername[s.username] = s;
    });

    res.json({
      success: true,
      auditLogs: auditLogs.map(log => {
        // Try to get staff info from populated staff_id first
        let staffName = 'System';
        let employeeNumber = 'N/A';
        
        if (log.staff_id && log.staff_id.full_name) {
          staffName = `${log.staff_id.full_name.first || ''} ${log.staff_id.full_name.last || ''}`.trim();
          employeeNumber = log.staff_id.employee_number || 'N/A';
        } else if (log.username) {
          // Fallback: try to find staff by username
          const staffByName = staffByUsername[log.username];
          if (staffByName) {
            staffName = staffByName.full_name ? `${staffByName.full_name.first || ''} ${staffByName.full_name.last || ''}`.trim() : log.username;
            employeeNumber = staffByName.employee_number || 'N/A';
          } else {
            staffName = log.username;
          }
        }
        
        return {
          _id: log._id,
          staff_name: staffName,
          employee_number: employeeNumber,
          action: log.action,
          table_name: log.table_name,
          message: log.message,
          timestamp: log.timestamp
        };
      }),
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Audit Log Actions
 * @route   GET /api/owner/audit-logs/actions
 * @access  Private (Owner)
 */
exports.getAuditLogActions = async (req, res, next) => {
  try {
    const actions = await AuditLog.distinct('action', { owner_id: req.user._id });
    res.json({
      success: true,
      actions: actions.sort()
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Request subscription renewal
 * @route   POST /api/owner/request-renewal
 * @access  Private (Owner)
 */
exports.requestRenewal = async (req, res, next) => {
  try {
    const ownerId = req.user._id;
    const { renewal_period_months = 1, message = '' } = req.body;

    // Validate renewal period
    if (renewal_period_months < 1 || renewal_period_months > 12) {
      return res.status(400).json({
        success: false,
        error: '⚠️ Renewal period must be between 1 and 12 months'
      });
    }

    // Get owner details
    const owner = await LabOwner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({
        success: false,
        error: '❌ Owner not found'
      });
    }

    // Check if owner already has a pending renewal request
    const existingRequest = await Notification.findOne({
      sender_id: ownerId,
      sender_model: 'Owner',
      receiver_model: 'Admin',
      type: 'renewal_request',
      is_read: false
    });

    if (existingRequest) {
      return res.status(400).json({
        success: false,
        error: '⚠️ You already have a pending renewal request'
      });
    }

    // Calculate new subscription end date
    const currentEndDate = owner.subscription_end ? new Date(owner.subscription_end) : new Date();
    const newEndDate = new Date(currentEndDate);
    newEndDate.setMonth(newEndDate.getMonth() + renewal_period_months);

    // Calculate renewal fee
    const feeCalculation = await calculateTieredFee(ownerId);
    const renewalFee = feeCalculation.total * renewal_period_months;

    // Get admin to send notification to (use owner's admin or find first admin)
    let adminId = owner.admin_id;
    if (!adminId) {
      const Admin = require('../models/Admin');
      const admin = await Admin.findOne();
      adminId = admin?._id;
    }

    // Create renewal request notification for admin
    const adminNotification = await Notification.create({
      sender_id: ownerId,
      sender_model: 'Owner',
      receiver_id: adminId,
      receiver_model: 'Admin',
      type: 'renewal_request',
      title: 'Subscription Renewal Request',
      message: `${owner.lab_name} requests subscription renewal for ${renewal_period_months} month(s). Fee: $${renewalFee}. ${message ? 'Message: ' + message : ''}`,
      related_id: ownerId,
      metadata: {
        renewal_period_months: renewal_period_months,
        renewal_fee: renewalFee,
        current_end_date: owner.subscription_end,
        proposed_end_date: newEndDate
      }
    });

    // Create confirmation notification for the owner
    const ownerNotification = await Notification.create({
      sender_id: ownerId,
      sender_model: 'System',
      receiver_id: ownerId,
      receiver_model: 'Owner',
      type: 'renewal_confirmation',
      title: 'Renewal Request Submitted',
      message: `Your subscription renewal request for ${renewal_period_months} month(s) has been submitted successfully. Fee: $${renewalFee}. The admin will review your request soon.`,
      related_id: ownerId,
      metadata: {
        renewal_period_months: renewal_period_months,
        renewal_fee: renewalFee,
        proposed_end_date: newEndDate
      }
    });

    console.log('Created renewal request notification for admin:', adminNotification._id);
    console.log('Created renewal confirmation notification for owner:', ownerNotification._id);

    // Send push notification to admin
    const adminPushResult = await sendPushNotificationToAdmin(
      owner.admin_id,
      'Subscription Renewal Request',
      `${owner.lab_name} requested subscription renewal for ${renewal_period_months} month(s). Fee: $${renewalFee}`,
      {
        type: 'renewal_request',
        receiver_model: 'Admin',
        owner_id: ownerId.toString(),
        owner_name: `${owner.name.first} ${owner.name.last}`,
        renewal_period_months: renewal_period_months,
        renewal_fee: renewalFee
      }
    );

    if (adminPushResult) {
      console.log('✅ Push notification sent to admin successfully');
    } else {
      console.log('📱 Push notification not sent to admin (Firebase not available or no token)');
    }

    // Send push notification to owner
    await sendPushNotificationToOwner(
      ownerId,
      'Renewal Request Submitted',
      `Your subscription renewal request for ${renewal_period_months} month(s) has been submitted. Fee: $${renewalFee}`,
      {
        type: 'renewal_confirmation',
        renewal_period_months: renewal_period_months,
        renewal_fee: renewalFee
      }
    );

    // Log the renewal request
    await logAction(
      ownerId,
      'Owner',
      'RENEWAL_REQUEST',
      `Requested subscription renewal for ${renewal_period_months} months`,
      { renewal_period_months, renewal_fee: renewalFee }
    );

    res.json({
      success: true,
      message: '✅ Renewal request submitted successfully. Admin will review your request.',
      data: {
        renewal_period_months,
        renewal_fee: renewalFee,
        proposed_end_date: newEndDate
      }
    });

  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Renewal Requests for Owner
 * @route   GET /api/owner/renewal-requests
 * @access  Private (Owner)
 */
exports.getRenewalRequests = async (req, res, next) => {
  try {
    const ownerId = req.user._id;
    console.log('Getting renewal requests for owner:', ownerId);

    // Get all renewal request notifications sent by this owner
    const renewalRequests = await Notification.find({
      sender_id: ownerId,
      sender_model: 'Owner',
      type: 'renewal_request'
    })
    .sort({ createdAt: -1 })
    .populate('sender_id', 'lab_name name')
    .populate('receiver_id', 'name');

    console.log('Found renewal requests:', renewalRequests.length);
    console.log('Renewal requests data:', renewalRequests.map(r => ({ id: r._id, type: r.type, sender_model: r.sender_model })));

    // Get admin responses to renewal requests (notifications from admin to owner about renewal)
    const adminResponses = await Notification.find({
      receiver_id: ownerId,
      receiver_model: 'Owner',
      type: { $in: ['subscription_approved', 'subscription_denied', 'subscription_renewal'] }
    })
    .sort({ createdAt: -1 })
    .populate('sender_id', 'name')
    .populate('receiver_id', 'lab_name name');

    console.log('Found admin responses:', adminResponses.length);

    // Combine and format the data
    const formattedRequests = renewalRequests.map(request => {
      // Find corresponding admin response
      const response = adminResponses.find(resp =>
        resp.related_id && resp.related_id.toString() === request._id.toString()
      );

      return {
        id: request._id,
        status: response ? (response.type === 'subscription_approved' ? 'approved' :
                           response.type === 'subscription_denied' ? 'denied' : 'pending') : 'pending',
        requestedDate: request.createdAt,
        renewalPeriodMonths: request.metadata?.renewal_period_months || 1,
        renewalFee: request.metadata?.renewal_fee || 0,
        message: request.message,
        adminResponse: response ? {
          date: response.createdAt,
          message: response.message,
          type: response.type
        } : null
      };
    });

    console.log('Formatted requests:', formattedRequests.length);

    res.json({
      success: true,
      data: formattedRequests
    });

  } catch (err) {
    console.error('Error getting renewal requests:', err);
    next(err);
  }
};

module.exports = exports;

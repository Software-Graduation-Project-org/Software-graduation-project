const Order = require("../models/Order");
const OrderDetails = require("../models/OrderDetails");
const Test = require("../models/Test");
const LabOwner = require("../models/Owner");
const Notification = require("../models/Notification");
const Feedback = require("../models/Feedback");
const Patient = require("../models/Patient");
const Doctor = require("../models/Doctor");
const Staff = require("../models/Staff");
const Admin = require("../models/Admin");
const jwt = require('jsonwebtoken');
const sendEmail = require("../utils/sendEmail");
const sendSMS = require("../utils/sendSMS");
const { sendLabReport, sendWhatsAppMessage } = require("../utils/sendWhatsApp");
const { sendLabReportNotification } = require("../utils/sendNotification");

/**
 * @desc    Get all approved lab owners for public lab finder
 * @route   GET /api/public/labs
 * @access  Public
 */
exports.getAllLabs = async (req, res) => {
  try {
    // Get all approved lab owners with basic info
    const labs = await LabOwner.find({
      status: 'approved',
      is_active: true
    })
    .select('lab_name name phone_number email address office_hours status')
    .sort({ lab_name: 1 });

    // Format the response
    const formattedLabs = labs.map(lab => ({
      id: lab._id,
      lab_name: lab.lab_name,
      owner_name: `${lab.name.first} ${lab.name.middle ? lab.name.middle + ' ' : ''}${lab.name.last}`.trim(),
      phone_number: lab.phone_number,
      email: lab.email,
      address: lab.address,
      office_hours: lab.office_hours,
      status: lab.status
    }));

    res.json({
      success: true,
      count: formattedLabs.length,
      labs: formattedLabs
    });

  } catch (error) {
    console.error('Error fetching labs:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching laboratories'
    });
  }
};

/**
 * @desc    Patient submits registration form with personal info and test orders
 * @route   POST /api/public/submit-registration
 * @access  Public
 */
exports.submitRegistration = async (req, res) => {
  try {
    const { 
      lab_id,
      full_name, 
      identity_number, 
      birthday, 
      gender, 
      phone_number, 
      email, 
      address,
      social_status,
      insurance_provider,
      insurance_number,
      test_ids,
      remarks 
    } = req.body;

    // Validate required fields
    if (!lab_id) {
      return res.status(400).json({ message: "Lab selection is required" });
    }

    if (!full_name || !full_name.first || !full_name.last) {
      return res.status(400).json({ message: "Full name (first and last) is required" });
    }

    if (!identity_number || !birthday || !gender || !phone_number || !email || !address) {
      return res.status(400).json({ message: "All personal information fields are required" });
    }

    // Validate phone number format
    const phoneRegex = /^\+[1-9]\d{1,14}$/;
    if (!phoneRegex.test(phone_number)) {
      return res.status(400).json({ message: "Phone number must be in international format (e.g., +972594317447)" });
    }

    if (!test_ids || !Array.isArray(test_ids) || test_ids.length === 0) {
      return res.status(400).json({ message: "At least one test must be selected" });
    }

    // Verify lab exists
    const lab = await LabOwner.findById(lab_id);
    if (!lab) {
      return res.status(404).json({ message: "Lab not found" });
    }

    // Verify all tests exist and belong to this lab
    const tests = await Test.find({ 
      _id: { $in: test_ids },
      owner_id: lab_id 
    });

    if (tests.length !== test_ids.length) {
      return res.status(404).json({ message: "One or more tests not found or not available for this lab" });
    }

    // Generate registration token for account creation
    const registrationToken = Order.generateRegistrationToken();
    const tokenExpiry = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

    // Create pending order with patient info
    const order = await Order.create({
      temp_patient_info: {
        full_name,
        identity_number,
        email,
        phone_number,
        birthday,
        gender,
        address,
        social_status,
        insurance_provider,
        insurance_number
      },
      order_date: new Date(),
      status: 'pending', // Pending until patient creates account
      remarks: remarks || null,
      owner_id: lab_id,
      is_patient_registered: false,
      registration_token: registrationToken,
      registration_token_expires: tokenExpiry
    });

    // Create order details for each test
    const orderDetailsData = tests.map(test => ({
      order_id: order._id,
      test_id: test._id,
      status: 'pending',
      sample_collected: false
    }));

    await OrderDetails.insertMany(orderDetailsData);

    // Calculate total cost
    const totalCost = tests.reduce((sum, test) => sum + (test.price || 0), 0);

    // Create notification for lab staff/owner
    await Notification.create({
      receiver_id: lab_id,
      receiver_model: 'Owner',
      type: 'system',
      title: 'New Registration Request',
      message: `New patient registration request from ${full_name.first} ${full_name.last}. Order with ${tests.length} test(s) pending account creation.`,
      related_id: order._id
    });

    // Generate account creation link
    const registrationLink = `${process.env.FRONTEND_URL || 'http://localhost:8080'}/register/complete?token=${registrationToken}`;

    // Send email with registration link
    const emailSubject = `Complete Your Account Registration - ${lab.lab_name}`;
    const emailMessage = `
Hello ${full_name.first} ${full_name.last},

Thank you for choosing ${lab.lab_name}!

Your test order has been submitted successfully. To complete your registration and access your account, please click the link below:

${registrationLink}

Order Details:
- Tests Ordered: ${tests.length}
- Total Cost: ${totalCost} ILS
- Lab: ${lab.lab_name}

This link will expire in 7 days.

Next Steps:
1. Click the link above to create your account
2. Visit the lab with your ID for sample collection
3. Track your results online after processing

If you have any questions, please contact us at ${lab.phone_number}

Best regards,
${lab.lab_name}
    `;


    // Try WhatsApp first, fallback to email if needed
    const whatsappMessage = `Hello ${full_name.first} ${full_name.last},\n\nThank you for choosing ${lab.lab_name}!\nYour test order has been submitted successfully. To complete your registration and access your account, please click the link below:\n${registrationLink}\n\nOrder Details:\n- Tests Ordered: ${tests.length}\n- Total Cost: ${totalCost} ILS\n- Lab: ${lab.lab_name}\n\nThis link will expire in 7 days.\n\nNext Steps:\n1. Click the link above to create your account\n2. Visit the lab with your ID for sample collection\n3. Track your results online after processing`;
    const whatsappSuccess = await sendWhatsAppMessage(
      phone_number,
      whatsappMessage,
      [],
      true, // fallback to email
      emailSubject,
      emailMessage
    );
    if (!whatsappSuccess) {
      // Fallback to SMS if both WhatsApp and email fail
      const smsMessage = `Hello ${full_name.first}! Complete your registration at ${lab.lab_name}: ${registrationLink}. Tests: ${tests.length}, Total: ${totalCost} ILS. Link expires in 7 days.`;
      await sendSMS(phone_number, smsMessage);
    }

    res.status(201).json({
      success: true,
      message: "✅ Registration submitted successfully! Check your email and SMS for account creation link.",
      registration: {
        order_id: order._id,
        lab_name: lab.lab_name,
        patient_name: `${full_name.first} ${full_name.last}`,
        email,
        phone_number,
        tests_ordered: tests.map(t => ({
          test_name: t.test_name,
          test_code: t.test_code,
          price: t.price
        })),
        total_cost: totalCost,
        test_count: tests.length,
        status: "pending",
        next_steps: [
          "Check your email and SMS for account creation link",
          "Click the link to create your account",
          "Visit the lab with your ID for sample collection",
          "Track your results online after processing"
        ]
      }
    });

  } catch (err) {
    console.error("Error submitting registration:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get list of available labs
 * @route   GET /api/public/labs
 * @access  Public
 */
exports.getAvailableLabs = async (req, res) => {
  try {
    // Get only approved and active labs
    const labs = await LabOwner.find({ 
      status: 'approved',
      is_active: true 
    })
    .select('lab_name email phone_number address subscription_end_date')
    .lean();

    res.json({
      success: true,
      count: labs.length,
      labs: labs.map(lab => ({
        _id: lab._id,
        lab_name: lab.lab_name,
        email: lab.email,
        phone_number: lab.phone_number,
        address: lab.address,
        subscription_active: lab.subscription_end_date > new Date()
      }))
    });

  } catch (err) {
    console.error("Error fetching labs:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get available tests for a specific lab
 * @route   GET /api/public/labs/:labId/tests
 * @access  Public
 */
exports.getLabTests = async (req, res) => {
  try {
    const { labId } = req.params;

    // Verify lab exists and is active
    const lab = await LabOwner.findOne({ 
      _id: labId,
      status: 'approved',
      is_active: true 
    });

    if (!lab) {
      return res.status(404).json({ message: "Lab not found or inactive" });
    }

    // Get active tests for this lab
    const tests = await Test.find({ 
      owner_id: labId,
      is_active: true 
    })
    .select('test_code test_name sample_type price turnaround_time units reference_range')
    .sort({ test_name: 1 })
    .lean();

    res.json({
      success: true,
      lab: {
        _id: lab._id,
        lab_name: lab.lab_name
      },
      count: tests.length,
      tests: tests.map(test => ({
        _id: test._id,
        test_code: test.test_code,
        test_name: test.test_name,
        sample_type: test.sample_type,
        price: test.price,
        turnaround_time: test.turnaround_time,
        units: test.units,
        reference_range: test.reference_range
      }))
    });

  } catch (err) {
    console.error("Error fetching lab tests:", err);
    res.status(500).json({ error: err.message });
  }
};

// ============================================================================
// ACCOUNT REGISTRATION ENDPOINTS
// ============================================================================

/**
 * @desc    Verify registration token and get order details
 * @route   GET /api/public/register/verify/:token
 * @access  Public
 */
exports.verifyRegistrationToken = async (req, res) => {
  try {
    const { token } = req.params;

    const order = await Order.findOne({
      registration_token: token,
      registration_token_expires: { $gt: new Date() },
      is_patient_registered: false
    }).populate('owner_id', 'lab_name phone_number email');

    if (!order) {
      return res.status(400).json({ 
        success: false,
        message: "Invalid or expired registration token" 
      });
    }

    // Get tests for this order
    const orderDetails = await OrderDetails.find({ order_id: order._id })
      .populate('test_id', 'test_name test_code price');

    res.json({
      success: true,
      registration_data: {
        order_id: order._id,
        lab: {
          name: order.owner_id.lab_name,
          phone: order.owner_id.phone_number,
          email: order.owner_id.email
        },
        patient_info: order.temp_patient_info,
        tests: orderDetails.map(od => ({
          test_name: od.test_id.test_name,
          test_code: od.test_id.test_code,
          price: od.test_id.price
        })),
        total_cost: orderDetails.reduce((sum, od) => sum + (od.test_id.price || 0), 0)
      }
    });
  } catch (err) {
    console.error("Error verifying registration token:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Complete patient registration using token
 * @route   POST /api/public/register/complete
 * @access  Public
 */
exports.completeRegistration = async (req, res) => {
  try {
    const { token, username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ 
        message: "Username and password are required" 
      });
    }

    // Find order with valid token
    const order = await Order.findOne({
      registration_token: token,
      registration_token_expires: { $gt: new Date() },
      is_patient_registered: false
    });

    if (!order) {
      return res.status(400).json({ 
        message: "Invalid or expired registration token" 
      });
    }

    const Patient = require('../models/Patient');

    // Check if username already exists
    const existingUser = await Patient.findOne({ username });
    if (existingUser) {
      return res.status(400).json({ 
        message: "Username already exists. Please choose another." 
      });
    }

    // Check if email already registered
    const existingEmail = await Patient.findOne({ 
      email: order.temp_patient_info.email 
    });
    if (existingEmail) {
      return res.status(400).json({ 
        message: "Email already registered. Please login instead." 
      });
    }

    // Generate unique patient ID
    let newPatientId = 1000;

    try {
      // Find the highest numeric patient_id
      const lastPatient = await Patient.findOne({
        patient_id: { $exists: true, $ne: null, $ne: 'NaN', $regex: /^\d+$/ }
      }).sort({ patient_id: -1 });

      if (lastPatient && lastPatient.patient_id) {
        const lastId = parseInt(lastPatient.patient_id);
        if (!isNaN(lastId)) {
          newPatientId = lastId + 1;
        }
      }
    } catch (error) {
      console.warn('Error generating patient ID in public registration, using timestamp fallback:', error.message);
      // If there's any issue, generate a timestamp-based ID to ensure uniqueness
      newPatientId = parseInt(Date.now().toString());
    }

    // Ensure patient_id is always a valid number
    if (isNaN(newPatientId) || newPatientId < 1000) {
      newPatientId = parseInt(Date.now().toString());
    }
    // Create patient account (password will be hashed by the model's pre-save hook)
    const patient = await Patient.create({
      patient_id: newPatientId.toString(),
      username,
      password: 'StrongPassword123!', // Default strong password for all new patients
      full_name: order.temp_patient_info.full_name,
      identity_number: order.temp_patient_info.identity_number,
      birthday: order.temp_patient_info.birthday,
      gender: order.temp_patient_info.gender,
      phone_number: order.temp_patient_info.phone_number,
      email: order.temp_patient_info.email,
      address: order.temp_patient_info.address,
      social_status: order.temp_patient_info.social_status,
      insurance_provider: order.temp_patient_info.insurance_provider,
      insurance_number: order.temp_patient_info.insurance_number,
      is_active: true
    });

    // Link order to patient
    await Order.findByIdAndUpdate(order._id, {
      patient_id: patient._id,
      is_patient_registered: true,
      registration_token: null, // Clear token after use
      registration_token_expires: null
    });

    // Get order details to calculate invoice
    const OrderDetails = require('../models/OrderDetails');
    const Test = require('../models/Test');
    const Invoice = require('../models/Invoices');
    const Notification = require('../models/Notification');

    const orderDetails = await OrderDetails.find({ order_id: order._id })
      .populate('test_id', 'test_name price');

    // Create invoice automatically
    const subtotal = orderDetails.reduce((sum, detail) => {
      return sum + (detail.test_id.price || 0);
    }, 0);

    // Generate invoice ID
    const invoiceCount = await Invoice.countDocuments();
    const invoiceId = `INV-${String(invoiceCount + 1).padStart(6, '0')}`;

    const invoice = await Invoice.create({
      invoice_id: invoiceId,
      order_id: order._id,
      invoice_date: new Date(),
      subtotal,
      discount: 0,
      total_amount: subtotal,
      payment_status: 'paid', // Mark as paid initially
      payment_method: 'cash', // Default payment method
      payment_date: new Date(),
      paid_by: patient._id,
      owner_id: order.owner_id,
      items: orderDetails.map(d => ({
        test_id: d.test_id._id,
        test_name: d.test_id.test_name,
        price: d.test_id.price,
        quantity: 1
      }))
    });

    // Send invoice notification to patient
    await Notification.create({
      sender_id: order.owner_id,
      sender_model: 'Owner',
      receiver_id: patient._id,
      receiver_model: 'Patient',
      type: 'payment',
      title: 'Invoice Generated',
      message: `Your invoice has been generated. Total: ${subtotal} ILS. Payment status: Paid. Please visit the lab for sample collection.`
    });

    // Send welcome email
    const welcomeSubject = `Welcome to ${order.owner_id?.lab_name || 'MedLab System'}`;
    const welcomeMessage = `
Hello ${patient.full_name.first},

Your account has been successfully created!

Login Credentials:
- Username: ${username}
- Patient ID: ${newPatientId}

You can now:
- Login to track your test results
- View your order history
- Receive notifications about your tests

Please visit the lab with your ID for sample collection.

Best regards,
MedLab System
    `;


    // Try WhatsApp first, fallback to email if needed
    const whatsappWelcome = `Hello ${patient.full_name.first},\n\nYour account has been successfully created!\n\nLogin Credentials:\n- Username: ${username}\n- Patient ID: ${newPatientId}\n\nYou can now:\n- Login to track your test results\n- View your order history\n- Receive notifications about your tests\n\nPlease visit the lab with your ID for sample collection.\n\nBest regards,\nMedLab System`;
    const whatsappSuccess = await sendWhatsAppMessage(
      patient.phone_number,
      whatsappWelcome,
      [],
      true, // fallback to email
      welcomeSubject,
      welcomeMessage
    );
    if (!whatsappSuccess) {
      // Fallback to SMS if both WhatsApp and email fail
      const smsMessage = `Hello ${patient.full_name.first}! Your account has been created. Username: ${username}, Patient ID: ${newPatientId}. Please visit the lab with your ID for sample collection.`;
      await sendSMS(patient.phone_number, smsMessage);
    }

    // Notify lab owner
    await Notification.create({
      receiver_id: order.owner_id,
      receiver_model: 'Owner',
      type: 'system',
      title: 'Patient Account Created',
      message: `${patient.full_name.first} ${patient.full_name.last} has completed registration. Ready for sample collection.`,
      related_id: order._id
    });

    res.status(201).json({
      success: true,
      message: "✅ Account created successfully! Please login with your credentials.",
      patient: {
        patient_id: newPatientId,
        username,
        full_name: patient.full_name,
        email: patient.email
      }
    });
  } catch (err) {
    console.error("Error completing registration:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get system feedback for marketing pages
 * @route   GET /api/public/feedback/system
 * @access  Public
 */
exports.getSystemFeedback = async (req, res) => {
  try {
    const { limit = 20, minRating = 4, role } = req.query;

    // Build query filter
    const query = {
      rating: { $gte: parseInt(minRating) }
    };

    // Filter by role if specified
    if (role && ['Patient', 'Staff', 'Owner', 'Doctor'].includes(role)) {
      query.user_model = role;
    }

    const feedback = await Feedback.find(query)
    .populate({
      path: 'user_id',
      select: 'name full_name lab_name username'
    })
    .sort({ rating: -1, createdAt: -1 })
    .limit(parseInt(limit))
    .select('rating message user_id user_model is_anonymous createdAt')
    .lean();

    // Transform the data with proper user information
    const transformedFeedback = feedback.map(item => {
      let userName = 'Anonymous User';
      
      if (!item.is_anonymous && item.user_id) {
        if (item.user_model === 'Owner' && item.user_id.lab_name) {
          userName = item.user_id.lab_name;
        } else if (item.user_id.full_name) {
          userName = `${item.user_id.full_name.first} ${item.user_id.full_name.last}`;
        } else if (item.user_id.name) {
          userName = `${item.user_id.name.first} ${item.user_id.name.last}`;
        } else if (item.user_id.username) {
          userName = item.user_id.username;
        }
      }

      return {
        _id: item._id,
        user_id: item.is_anonymous ? null : item.user_id?._id,
        user_model: item.user_model,
        user_role: item.user_model, // For frontend display
        user_name: userName,
        target_type: 'system',
        target_id: null,
        rating: item.rating,
        message: item.message,
        is_anonymous: item.is_anonymous,
        createdAt: item.createdAt,
        updatedAt: item.createdAt
      };
    });

    // Group by role for statistics
    const roleStats = feedback.reduce((acc, item) => {
      acc[item.user_model] = (acc[item.user_model] || 0) + 1;
      return acc;
    }, {});

    res.json({
      success: true,
      count: transformedFeedback.length,
      feedback: transformedFeedback,
      statistics: {
        total: transformedFeedback.length,
        by_role: roleStats,
        average_rating: feedback.length > 0 
          ? (feedback.reduce((sum, f) => sum + f.rating, 0) / feedback.length).toFixed(1)
          : 0
      }
    });
  } catch (err) {
    console.error("Error fetching system feedback:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Submit contact form for laboratory owners interested in the system
 * @route   POST /api/public/contact
 * @access  Public
 */
exports.submitContactForm = async (req, res) => {
  try {
    const { name, email, phone, lab_name, message } = req.body;

    // Validate required fields
    if (!name || !email || !lab_name || !message) {
      return res.status(400).json({
        message: "Name, email, laboratory name, and message are required"
      });
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ message: "Please provide a valid email address" });
    }

    // Create contact inquiry record (you might want to create a Contact model for this)
    // For now, we'll just send an email notification to the admin

    // Send email notification to admin
    const adminEmailSubject = `New Contact Inquiry: ${lab_name}`;
    const adminEmailBody = `
      <h2>New Laboratory Contact Inquiry</h2>
      <p><strong>Contact Person:</strong> ${name}</p>
      <p><strong>Email:</strong> ${email}</p>
      <p><strong>Phone:</strong> ${phone || 'Not provided'}</p>
      <p><strong>Laboratory Name:</strong> ${lab_name}</p>
      <p><strong>Message:</strong></p>
      <p>${message.replace(/\n/g, '<br>')}</p>
      <hr>
      <p><em>This inquiry was submitted through the MedLab System contact form.</em></p>
    `;

    // Send email to admin (you'll need to configure admin email)
    try {
      await sendEmail(process.env.ADMIN_EMAIL || 'admin@medlabsystem.com', adminEmailSubject, adminEmailBody);
    } catch (emailError) {
      console.error('Failed to send admin notification email:', emailError);
      // Don't fail the request if email fails, just log it
    }

    // Send WhatsApp notification to admin
    if (process.env.ADMIN_PHONE) {
      try {
        const adminWhatsAppMessage = `🔔 New Lab Contact Inquiry\n\n📋 Laboratory: ${lab_name}\n👤 Contact: ${name}\n📧 Email: ${email}\n📱 Phone: ${phone || 'Not provided'}\n\n💬 Message:\n${message}\n\nPlease review and follow up within 24-48 hours.`;

        await sendWhatsAppMessage(
          process.env.ADMIN_PHONE,
          adminWhatsAppMessage,
          [],
          false, // Don't fallback to email since we already sent email above
          '',
          ''
        );
      } catch (whatsappError) {
        console.error('Failed to send WhatsApp notification to admin:', whatsappError);
        // Don't fail the request if WhatsApp fails
      }
    }

    // Send confirmation email to the contact person
    const confirmationSubject = 'Thank you for your interest in MedLab System';
    const confirmationBody = `
      <h2>Thank you for contacting us!</h2>
      <p>Dear ${name},</p>
      <p>Thank you for your interest in MedLab System. We have received your inquiry about implementing our laboratory management system for ${lab_name}.</p>
      <p>Our team will review your message and contact you within 24-48 hours to discuss your specific needs and how we can help transform your laboratory operations.</p>
      <p><strong>Your message:</strong></p>
      <p>${message.replace(/\n/g, '<br>')}</p>
      <br>
      <p>Best regards,<br>The MedLab System Team</p>
    `;

    try {
      await sendEmail(email, confirmationSubject, confirmationBody);
    } catch (emailError) {
      console.error('Failed to send confirmation email:', emailError);
    }

    res.status(200).json({
      message: "Contact form submitted successfully. We will contact you soon!",
      success: true
    });

  } catch (err) {
    console.error("Error submitting contact form:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get available subscription tiers for lab owner registration
 * @route   GET /api/public/subscription-tiers
 * @access  Public
 */
exports.getSubscriptionTiers = async (req, res) => {
  try {
    const tiers = {
      starter: {
        tier: 'starter',
        monthlyFee: 50,
        patientLimit: 500,
        description: 'Up to 500 patients - $50/month',
        features: [
          'Basic lab management',
          'Patient registration',
          'Test ordering and results',
          'Basic reporting',
          'Email notifications'
        ]
      },
      professional: {
        tier: 'professional',
        monthlyFee: 100,
        patientLimit: 2000,
        description: 'Up to 2000 patients - $100/month',
        features: [
          'All starter features',
          'Advanced reporting',
          'Inventory management',
          'Staff scheduling',
          'WhatsApp notifications',
          'Priority support'
        ]
      },
      enterprise: {
        tier: 'enterprise',
        monthlyFee: 200,
        patientLimit: null, // Unlimited
        description: 'Unlimited patients - $200/month',
        features: [
          'All professional features',
          'Multi-lab management',
          'Custom integrations',
          'Advanced analytics',
          'Dedicated account manager',
          '24/7 premium support'
        ]
      }
    };

    res.json({
      success: true,
      tiers: tiers
    });

  } catch (err) {
    console.error("Error fetching subscription tiers:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Lab Owner Self-Registration
 * @route   POST /api/public/owner/register
 * @access  Public
 */
exports.registerOwner = async (req, res) => {
  try {
    const {
      // Personal Information
      full_name,
      identity_number,
      birthday,
      gender,
      phone_number,
      email,
      address,
      
      // Lab Information
      lab_name,
      lab_license_number,
      subscription_period_months = 1,
      subscription_tier = 'starter',  // New field for plan selection
      subscription_end_date
    } = req.body;

    // Validate required fields
    if (!full_name || !full_name.first || !full_name.last) {
      return res.status(400).json({ message: "First name and last name are required" });
    }

    if (!identity_number || !birthday || !gender || !phone_number || !email) {
      return res.status(400).json({ message: "All personal information fields are required" });
    }

    if (!lab_name) {
      return res.status(400).json({ message: "Laboratory name is required" });
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ message: "Please provide a valid email address" });
    }

    // Check if email already exists
    const existingOwner = await LabOwner.findOne({ email });
    if (existingOwner) {
      return res.status(400).json({ message: "An account with this email already exists" });
    }

    // Check if identity number already exists
    const existingIdentity = await LabOwner.findOne({ identity_number });
    if (existingIdentity) {
      return res.status(400).json({ message: "An account with this identity number already exists" });
    }

    // Get default admin (first admin) to assign to this owner
    const defaultAdmin = await Admin.findOne().sort({ createdAt: 1 });
    if (!defaultAdmin) {
      return res.status(500).json({ message: "System not properly configured. No admin found." });
    }

    // Define available subscription tiers
    const subscriptionTiers = {
      starter: {
        tier: 'starter',
        monthlyFee: 50,
        patientLimit: 500,
        description: 'Up to 500 patients - $50/month'
      },
      professional: {
        tier: 'professional',
        monthlyFee: 100,
        patientLimit: 2000,
        description: 'Up to 2000 patients - $100/month'
      },
      enterprise: {
        tier: 'enterprise',
        monthlyFee: 200,
        patientLimit: null, // Unlimited
        description: 'Unlimited patients - $200/month'
      }
    };

    // Validate subscription tier
    if (!subscriptionTiers[subscription_tier]) {
      return res.status(400).json({ 
        message: "Invalid subscription tier. Please choose from: starter, professional, enterprise" 
      });
    }

    const subscriptionPricing = subscriptionTiers[subscription_tier];

    // Generate temporary username and password (will be sent upon approval)
    const tempUsername = `${full_name.first.toLowerCase()}${full_name.last.toLowerCase()}${Math.floor(Math.random() * 1000)}`;
    const tempPassword = Math.random().toString(36).slice(-8) + Math.random().toString(36).slice(-8);

    // Generate unique owner_id
    const owner_id = `OWN-${Date.now()}`;

    // Create owner account with is_active: false (pending approval)
    const newOwner = new LabOwner({
      name: full_name,
      identity_number,
      birthday,
      gender,
      phone_number,
      email,
      address: address || {},
      lab_name,
      lab_license_number,
      owner_id,
      username: tempUsername, // Temporary username
      password: tempPassword, // Temporary password (will be hashed by pre-save hook)
      admin_id: defaultAdmin._id,
      is_active: false,
      status: 'pending',
      subscriptionFee: subscriptionPricing.monthlyFee,
      subscription_period_months: parseInt(subscription_period_months) || 1,
      subscription_end: subscription_end_date ? new Date(subscription_end_date) : null,
      temp_credentials: {
        username: tempUsername,
        password: tempPassword
      }
    });

    await newOwner.save();

    // Send confirmation email to owner
    const ownerEmailSubject = 'Registration Received - Pending Admin Approval';
    const ownerEmailBody = `
      <h2>Welcome to MedLab System!</h2>
      <p>Dear ${full_name.first} ${full_name.last},</p>
      <p>Thank you for registering your laboratory <strong>${lab_name}</strong> with MedLab System.</p>
      
      <h3>Subscription Details:</h3>
      <p><strong>Monthly Fee:</strong> $${subscriptionPricing.monthlyFee}</p>
      <p><strong>Plan:</strong> ${subscriptionPricing.description}</p>
      
      <h3>Next Steps:</h3>
      <p>Your registration is currently <strong>pending administrative approval</strong>. Our team will review your application and verify your laboratory information.</p>
      <p>Once approved, you will receive an email with your login credentials (username and password) that you can use to access your account.</p>
      <p>After your first login, you can change your password in your profile settings.</p>
      
      <p>This process typically takes 24-48 hours. If you have any questions, please contact our support team.</p>
      
      <br>
      <p>Best regards,<br>The MedLab System Team</p>
    `;

    // TESTING: Email sending disabled
    // try {
    //   await sendEmail(email, ownerEmailSubject, ownerEmailBody);
    // } catch (emailError) {
    //   console.error('Failed to send owner confirmation email:', emailError);
    // }
    //
    // Send notification to admin
    const adminEmailSubject = `New Lab Owner Registration: ${lab_name}`;
    const adminEmailBody = `
      <h2>New Laboratory Owner Registration</h2>
      <p>A new laboratory has registered and is awaiting approval.</p>
      
      <h3>Personal Information:</h3>
      <p><strong>Name:</strong> ${full_name.first} ${full_name.middle || ''} ${full_name.last}</p>
      <p><strong>Email:</strong> ${email}</p>
      <p><strong>Phone:</strong> ${phone_number}</p>
      <p><strong>Identity Number:</strong> ${identity_number}</p>
      
      <h3>Laboratory Information:</h3>
      <p><strong>Lab Name:</strong> ${lab_name}</p>
      <p><strong>License Number:</strong> ${lab_license_number || 'Not provided'}</p>
      
      <h3>Subscription Details:</h3>
      <p><strong>Subscription Tier:</strong> ${subscriptionPricing.description}</p>
      <p><strong>Monthly Fee:</strong> $${subscriptionPricing.monthlyFee}</p>
      
      <p><strong>Please review and approve/reject this application in the admin panel.</strong></p>
      <p>Upon approval, login credentials will be automatically generated and sent to the owner.</p>
    `;

    // TESTING: Email sending disabled
    // try {
    //   const adminEmail = defaultAdmin.email || process.env.ADMIN_EMAIL || 'admin@medlabsystem.com';
    //   await sendEmail(adminEmail, adminEmailSubject, adminEmailBody);
    // } catch (emailError) {
    //   console.error('Failed to send admin notification email:', emailError);
    // }
    //
    // Create notification for admin
    try {
      const notification = await Notification.create({
        receiver_id: defaultAdmin._id,
        receiver_model: 'Admin',
        type: 'registration',
        title: 'New Lab Owner Registration',
        message: `${full_name.first} ${full_name.last} from ${lab_name} has registered and is awaiting approval.`,
        is_read: false
      });

      // 📱 Send push notification to admin if Firebase is available
      try {
        const notificationController = require('./notificationController');
        const pushResult = await notificationController.sendPushNotificationToAdmin(
          defaultAdmin._id,
          'New Lab Owner Registration',
          `${full_name.first} ${full_name.last} from ${lab_name} has registered and is awaiting approval.`,
          {
            type: 'registration',
            owner_name: `${full_name.first} ${full_name.last}`,
            lab_name: lab_name,
            receiver_model: 'Admin'
          }
        );

        if (pushResult) {
          console.log('✅ DEBUG: Push notification sent to admin for new registration');
        } else {
          console.log('📱 DEBUG: Push notification not sent to admin (Firebase not available or no token)');
        }
      } catch (pushError) {
        console.error('Failed to send push notification to admin (this does not affect registration):', pushError);
      }
    } catch (notifError) {
      console.error('Failed to create admin notification:', notifError);
    }

    res.status(201).json({
      success: true,
      message: "Registration submitted successfully! Your application is pending admin approval. You will receive an email once approved.",
      subscription: subscriptionPricing,
      owner: {
        name: `${full_name.first} ${full_name.last}`,
        email,
        lab_name,
        status: 'pending'
      }
    });

  } catch (err) {
    console.error("Error registering owner:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Unified Login - checks all user types in one request
 * @route   POST /api/public/login
 * @access  Public
 */
exports.unifiedLogin = async (req, res, next) => {
  try {
    const { username, password } = req.body;

    // Validate input
    if (!username || !password) {
      return res.status(400).json({ message: '⚠️ Username and password are required' });
    }

    // Try each user type in order: Patient, Doctor, Staff, Owner, Admin
    const userTypes = [
      {
        model: Patient,
        role: 'patient',
        route: '/patient-dashboard',
        fields: {
          _id: 1,
          patient_id: 1,
          full_name: 1,
          identity_number: 1,
          birthday: 1,
          gender: 1,
          insurance_provider: 1,
          insurance_number: 1,
          email: 1,
          username: 1
        }
      },
      {
        model: Doctor,
        role: 'doctor',
        route: '/doctor-dashboard',
        fields: {
          _id: 1,
          doctor_id: 1,
          full_name: 1,
          specialization: 1,
          license_number: 1,
          email: 1,
          username: 1
        }
      },
      {
        model: Staff,
        role: 'Staff',
        route: '/staff/dashboard',
        fields: {
          _id: 1,
          full_name: 1,
          employee_number: 1,
          position: 1,
          email: 1,
          username: 1,
          owner_id: 1
        }
      },
      {
        model: LabOwner,
        role: 'owner',
        route: '/owner/dashboard',
        fields: {
          _id: 1,
          lab_name: 1,
          owner_name: 1,
          email: 1,
          username: 1,
          phone_number: 1,
          license_number: 1,
          status: 1
        }
      },
      {
        model: Admin,
        role: 'admin',
        route: '/admin/dashboard',
        fields: {
          _id: 1,
          full_name: 1,
          email: 1,
          username: 1
        }
      }
    ];

    // Normalize username for staff (lowercase, spaces to dots)
    const normalizedUsername = username.replace(/\s+/g, '.').toLowerCase();

    for (const userType of userTypes) {
      // For staff, use normalized username
      const searchUsername = userType.role === 'staff' ? normalizedUsername : username;
      
      const user = await userType.model.findOne({
        $or: [{ username: searchUsername }, { email: username }]
      });

      if (user) {
        // Check password
        const isMatch = await user.comparePassword(password);
        if (isMatch) {
          // Update last login if field exists
          if (user.last_login !== undefined) {
            user.last_login = new Date();
            await user.save();
          }

          // Generate JWT token
          const tokenPayload = {
            _id: user._id,
            role: userType.role,
            username: user.username
          };

          // Add role-specific IDs
          if (userType.role === 'patient' && user.patient_id) {
            tokenPayload.patient_id = user.patient_id;
          } else if (userType.role === 'doctor' && user.doctor_id) {
            tokenPayload.doctor_id = user.doctor_id;
          } else if (userType.role === 'Staff' && user.owner_id) {
            tokenPayload.owner_id = user.owner_id;
          }

          const token = jwt.sign(
            tokenPayload,
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
          );

          // Prepare user data (remove password and other sensitive fields)
          const userData = {};
          Object.keys(userType.fields).forEach(field => {
            if (user[field] !== undefined) {
              userData[field] = user[field];
            }
          });

          return res.json({
            message: '✅ Login successful',
            token,
            role: userType.role,
            route: userType.route,
            user: userData
          });
        }
      }
    }

    // If we get here, no valid credentials were found
    return res.status(401).json({ message: '❌ Invalid email or password. Please try again.' });

  } catch (err) {
    next(err);
  }
};

const express = require('express');
const dotenv = require('dotenv');
const connectDB = require('./config/db');
const cronJobs = require('./cronJobs');
const logger = require('./utils/logger');
// const mongoSanitize = require('express-mongo-sanitize');

dotenv.config();

// Validate required environment variables
const requiredEnvVars = ['MONGO_URI', 'JWT_SECRET'];
const missingEnvVars = requiredEnvVars.filter(varName => !process.env[varName]);

if (missingEnvVars.length > 0) {
  logger.error(`Missing required environment variables: ${missingEnvVars.join(', ')}`);
  logger.error('Please check your .env file');
  process.exit(1);
}

connectDB();

const app = express();

// Security middleware
const helmet = require('helmet');
const cors = require('cors');

app.use(helmet()); // Add security headers
app.use(cors({
  origin: true, // Allow all origins for development
  credentials: true
}));

app.use(express.json());

// HTTP request logging
app.use(logger.httpLogger);

// Add request logging middleware
app.use((req, res, next) => {
  // console.log(`📨 REQUEST: ${req.method} ${req.path} - Headers: ${JSON.stringify(req.headers.authorization ? 'Bearer token present' : 'No auth')}`);
  next();
});

// Prevent caching for API responses
app.use('/api', (req, res, next) => {
  res.set('Cache-Control', 'no-cache, no-store, must-revalidate');
  res.set('Pragma', 'no-cache');
  res.set('Expires', '0');
  next();
});

// NoSQL Injection Protection - sanitize all user input
// Temporarily disabled to fix "Cannot set property query" error
// app.use(mongoSanitize({
//   replaceWith: '_'
// }));

// Routes
app.use('/api/public', require('./routes/publicRoutes')); // Legacy public routes (kept for backwards compatibility)
app.use('/api/admin', require('./routes/adminRoutes'));
app.use('/api/owner', require('./routes/ownerRoutes'));
app.use('/api/patient', require('./routes/patientRoutes'));
app.use('/api/staff', require('./routes/staffRoutes'));
app.use('/api/doctor', require('./routes/doctorRoutes'));
app.use('/api/invoice', require('./routes/invoiceRoutes')); // Invoice & payment endpoints
app.use('/api/whatsapp', require('./routes/whatsappRoutes')); // WhatsApp webhook
app.use('/api/notifications', require('./routes/notificationRoutes')); // Push notifications

// HL7 Integration Event Handlers
const Result = require('./models/Result');
const ResultComponent = require('./models/ResultComponent');
const OrderDetails = require('./models/OrderDetails');

// Handle ORU messages from HL7 server (device results)
process.on('hl7-result', async (data) => {
  try {
    const { resultInfo, observations } = data;

    // console.log(`📊 Processing HL7 ORU result for order: ${resultInfo.fillerOrderNumber}`);

    // Find the order detail
    const orderDetail = await OrderDetails.findById(resultInfo.fillerOrderNumber)
      .populate('test_id')
      .populate({
        path: 'order_id',
        populate: 'patient_id'
      });

    if (!orderDetail) {
      console.error(`❌ Order detail not found: ${resultInfo.fillerOrderNumber}`);
      return;
    }

    // Check if result already exists
    const existingResult = await Result.findOne({ detail_id: orderDetail._id });
    if (existingResult) {
      // console.log(`⚠️ Result already exists for order detail: ${orderDetail._id}`);
      return;
    }

    const test = orderDetail.test_id;
    const hasComponents = observations.length > 1;

    // Calculate abnormality
    let isAbnormal = false;
    let abnormalComponentsCount = 0;

    // Create result components
    const resultComponents = [];
    for (const obs of observations) {
      // Try to find corresponding test component by name or code
      let testComponent = await require('./models/TestComponent').findOne({
        test_id: test._id,
        $or: [
          { component_name: obs.name },
          { component_code: obs.code }
        ]
      });

      // If no component found and this is a single-value test, create a virtual component
      if (!testComponent && !hasComponents) {
        testComponent = {
          _id: null, // Virtual component
          component_name: obs.name || test.test_name,
          component_code: obs.code || test.test_code,
          units: obs.units,
          reference_range: obs.referenceRange
        };
      }

      if (testComponent) {
        const isComponentAbnormal = obs.isAbnormal || (obs.abnormalFlags && obs.abnormalFlags !== 'N' && obs.abnormalFlags !== '');
        if (isComponentAbnormal) {
          isAbnormal = true;
          abnormalComponentsCount++;
        }

        resultComponents.push({
          result_id: null, // Will be set after result creation
          component_id: testComponent._id,
          component_name: obs.name || testComponent.component_name,
          component_value: obs.value || obs.component_value || '',
          units: obs.units || testComponent.units,
          reference_range: obs.referenceRange || obs.reference_range || testComponent.reference_range,
          is_abnormal: isComponentAbnormal,
          remarks: obs.remarks || ''
        });
      }
    }

    // Create main result record
    const result = await Result.create({
      detail_id: orderDetail._id,
      staff_id: orderDetail.staff_id, // Use assigned staff
      has_components: hasComponents,
      result_value: hasComponents ? null : observations[0]?.value.toString(),
      units: hasComponents ? null : observations[0]?.units,
      reference_range: hasComponents ? null : observations[0]?.referenceRange,
      remarks: 'Generated via HL7 simulation',
      is_abnormal: isAbnormal,
      abnormal_components_count: abnormalComponentsCount
    });

    // Create result components if any (only for real components with valid IDs)
    const validResultComponents = resultComponents.filter(comp => comp.component_id !== null);
    if (validResultComponents.length > 0) {
      for (const comp of validResultComponents) {
        comp.result_id = result._id;
      }
      await ResultComponent.insertMany(validResultComponents);
    }

    // Log virtual components (those without database component_id)
    const virtualComponents = resultComponents.filter(comp => comp.component_id === null);
    if (virtualComponents.length > 0) {
      // console.log(`📝 Created ${virtualComponents.length} virtual result components (no matching test components in database)`);
    }

    // Update order detail status
    orderDetail.status = 'completed';
    orderDetail.result_id = result._id;
    await orderDetail.save();

    // console.log(`✅ HL7 Result processed: ${test.test_name} - ${isAbnormal ? 'ABNORMAL' : 'NORMAL'} (${abnormalComponentsCount} abnormal components)`);

    // Check if all tests in this order are completed and update order status
    let orderStatusUpdated = false;
    let updatedOrderStatus = order.status;
    try {
      const allOrderDetails = await require('./models/OrderDetails').find({ order_id: order._id });
      const totalTests = allOrderDetails.length;
      const finishedTests = allOrderDetails.filter(detail => 
        detail.status === 'completed' || detail.status === 'failed'
      ).length;

      // If all tests are finished (completed or failed), mark the order as completed
      if (totalTests > 0 && finishedTests === totalTests && order.status !== 'completed') {
        order.status = 'completed';
        await order.save();
        orderStatusUpdated = true;
        updatedOrderStatus = 'completed';
      }
    } catch (orderCheckError) {
      console.error('Error checking order completion:', orderCheckError);
    }

    // Send result_uploaded notification to all staff in the lab for synchronization
    try {
      const Staff = require('./models/Staff');
      const Notification = require('./models/Notification');
      const staffMembers = await Staff.find({ owner_id: order.owner_id });

      for (const staff of staffMembers) {
        const resultUploadedNotification = {
          sender_id: orderDetail.staff_id,
          sender_model: "Staff",
          receiver_id: staff._id,
          receiver_model: "Staff",
          type: "result_uploaded",
          title: "Device Result Received",
          message: `${test.test_name} result has been received from device for order ${order.order_id}`,
          related_id: orderDetail._id
        };
        await Notification.create(resultUploadedNotification);
      }
    } catch (staffNotificationError) {
      console.error('Error sending result_uploaded notification to staff:', staffNotificationError);
    }

    // Send notifications to patient only when order is completed
    try {
      // Order completion notification if all tests are done
      if (orderStatusUpdated) {
        const orderCompletionNotification = {
          sender_id: orderDetail.staff_id,
          sender_model: "Staff",
          receiver_id: order.patient_id._id,
          receiver_model: "Patient",
          type: "order_completed",
          title: "All Test Results Available",
          message: `All tests for your order at ${order.owner_id?.lab_name || 'Medical Lab'} are now completed. You can view all results in your dashboard.`,
          related_id: order._id
        };
        await Notification.create(orderCompletionNotification);

        // Push notification for order completion
        const notificationController = require('./controllers/notificationController');
        await notificationController.sendPushNotificationToPatient(
          order.patient_id._id,
          `✅ All Test Results Available`,
          `All tests for your order at ${order.owner_id?.lab_name || 'Medical Lab'} are now completed. Tap to view.`,
          {
            type: 'order_completed',
            order_id: order._id.toString(),
            receiver_model: 'Patient'
          }
        );

        // WhatsApp and Email for order completion
        const orderResultUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/patient/results/${order._id}`;
        const { sendNotification } = require('./utils/sendNotification');
        await sendNotification({
          phone: order.patient_id.phone_number,
          email: order.patient_id.email,
          whatsappMessage: `Hello ${order.patient_id.full_name?.first || ''} ${order.patient_id.full_name?.last || ''},\n\n✅ All test results for your order are now available.\n\n🔗 View all results: ${orderResultUrl}\n\n🏥 Lab: ${order.owner_id?.lab_name || 'Medical Lab'}\n\nBest regards,\nMedical Laboratory Team`,
          emailSubject: `All Test Results Available - ${order.owner_id?.lab_name || 'Medical Lab'}`,
          emailHtml: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #4A90E2;">All Test Results Available</h2>
              <p>Hello ${order.patient_id.full_name?.first || ''} ${order.patient_id.full_name?.last || ''},</p>
              <p>All test results for your order are now available.</p>

              <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0; text-align: center;">
                <a href="${orderResultUrl}" style="background-color: #4A90E2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold;">View All Results</a>
              </div>

              <div style="background-color: #e3f2fd; padding: 15px; border-radius: 5px; margin: 20px 0;">
                <p style="margin: 0;"><strong>🏥 Lab:</strong> ${order.owner_id?.lab_name || 'Medical Lab'}</p>
              </div>

              <br>
              <p>Best regards,<br><strong>Medical Laboratory Team</strong></p>
            </div>
          `
        });

        // Push notification to doctor for order completion
        if (order.doctor_id) {
          await notificationController.sendPushNotificationToDoctor(
            order.doctor_id._id,
            `✅ All Test Results Available`,
            `All test results for patient ${order.patient_id?.full_name?.first || ''} ${order.patient_id?.full_name?.last || ''} are now available.`,
            {
              type: 'order_completed',
              order_id: order._id.toString(),
              patient_id: order.patient_id?._id.toString(),
              receiver_model: 'Doctor'
            }
          );
        }
      }
    } catch (patientNotificationError) {
      console.error('Error sending patient notifications:', patientNotificationError);
    }

  } catch (error) {
    console.error('❌ Error processing HL7 result:', error.message);
  }
});

// Internal API for HL7 server communication
app.post('/api/internal/hl7-result', express.json(), async (req, res) => {
  try {
    const { resultInfo, observations } = req.body;

    // console.log(`📊 Processing HL7 ORU result for order: ${resultInfo.fillerOrderNumber || resultInfo.detailId}`);

    // Find the order detail
    const orderDetail = await require('./models/OrderDetails').findById(resultInfo.detailId || resultInfo.fillerOrderNumber)
      .populate('test_id')
      .populate({
        path: 'order_id',
        populate: 'patient_id'
      });

    if (!orderDetail) {
      console.error(`❌ Order detail not found: ${resultInfo.detailId || resultInfo.fillerOrderNumber}`);
      return res.status(404).json({ message: 'Order detail not found' });
    }

    // Check if result already exists
    const existingResult = await require('./models/Result').findOne({ detail_id: orderDetail._id });
    if (existingResult) {
      // console.log(`⚠️ Result already exists for order detail: ${orderDetail._id}`);
      return res.json({ message: 'Result already exists' });
    }

    const test = orderDetail.test_id;
    const hasComponents = observations.length > 1;

    // Calculate abnormality
    let isAbnormal = false;
    let abnormalComponentsCount = 0;

    // Create result components
    const resultComponents = [];
    for (const obs of observations) {
      // Try to find corresponding test component by name or code
      let testComponent = await require('./models/TestComponent').findOne({
        test_id: test._id,
        $or: [
          { component_name: obs.name },
          { component_code: obs.code }
        ]
      });

      // If no component found and this is a single-value test, create a virtual component
      if (!testComponent && !hasComponents) {
        testComponent = {
          _id: null, // Virtual component
          component_name: obs.name || test.test_name,
          component_code: obs.code || test.test_code,
          units: obs.units,
          reference_range: obs.referenceRange
        };
      }

      if (testComponent) {
        const isComponentAbnormal = obs.isAbnormal || (obs.abnormalFlags && obs.abnormalFlags !== 'N' && obs.abnormalFlags !== '');
        if (isComponentAbnormal) {
          isAbnormal = true;
          abnormalComponentsCount++;
        }

        resultComponents.push({
          result_id: null, // Will be set after result creation
          component_id: testComponent._id,
          component_name: obs.name || testComponent.component_name,
          component_value: obs.value || obs.component_value || '',
          units: obs.units || testComponent.units,
          reference_range: obs.referenceRange || obs.reference_range || testComponent.reference_range,
          is_abnormal: isComponentAbnormal,
          remarks: obs.remarks || ''
        });
      }
    }

    // Create main result record
    const Result = require('./models/Result');
    const result = await Result.create({
      detail_id: orderDetail._id,
      staff_id: orderDetail.staff_id, // Use assigned staff
      has_components: hasComponents,
      result_value: hasComponents ? null : observations[0]?.value.toString(),
      units: hasComponents ? null : observations[0]?.units,
      reference_range: hasComponents ? null : observations[0]?.referenceRange,
      remarks: 'Generated via HL7 simulation',
      is_abnormal: isAbnormal,
      abnormal_components_count: abnormalComponentsCount
    });

    // Create result components if any (only for real components with valid IDs)
    const validResultComponents = resultComponents.filter(comp => comp.component_id !== null);
    if (validResultComponents.length > 0) {
      for (const comp of validResultComponents) {
        comp.result_id = result._id;
      }
      await require('./models/ResultComponent').insertMany(validResultComponents);
    }

    // Log virtual components (those without database component_id)
    const virtualComponents = resultComponents.filter(comp => comp.component_id === null);
    if (virtualComponents.length > 0) {
      // console.log(`📝 Created ${virtualComponents.length} virtual result components (no matching test components in database)`);
    }

    // Update order detail status
    orderDetail.status = 'completed';
    orderDetail.result_id = result._id;
    await orderDetail.save();

    // Check if all tests in this order are completed and update order status
    let orderStatusUpdated = false;
    let updatedOrderStatus = order.status;
    try {
      const allOrderDetails = await require('./models/OrderDetails').find({ order_id: order._id });
      const totalTests = allOrderDetails.length;
      const finishedTests = allOrderDetails.filter(detail => 
        detail.status === 'completed' || detail.status === 'failed'
      ).length;

      // If all tests are finished (completed or failed), mark the order as completed
      if (totalTests > 0 && finishedTests === totalTests && order.status !== 'completed') {
        order.status = 'completed';
        await order.save();
        orderStatusUpdated = true;
        updatedOrderStatus = 'completed';
      }
    } catch (orderCheckError) {
      console.error('Error checking order completion:', orderCheckError);
    }

    // Send result_uploaded notification to all staff in the lab for synchronization
    try {
      const Staff = require('./models/Staff');
      const Notification = require('./models/Notification');
      const staffMembers = await Staff.find({ owner_id: order.owner_id });

      for (const staff of staffMembers) {
        const resultUploadedNotification = {
          sender_id: orderDetail.staff_id,
          sender_model: "Staff",
          receiver_id: staff._id,
          receiver_model: "Staff",
          type: "result_uploaded",
          title: "Device Result Received",
          message: `${test.test_name} result has been received from device for order ${order.order_id}`,
          related_id: orderDetail._id
        };
        await Notification.create(resultUploadedNotification);
      }
    } catch (staffNotificationError) {
      console.error('Error sending result_uploaded notification to staff:', staffNotificationError);
    }

    // Send notifications to patient only when order is completed
    try {
      // Order completion notification if all tests are done
      if (orderStatusUpdated) {
        const orderCompletionNotification = {
          sender_id: orderDetail.staff_id,
          sender_model: "Staff",
          receiver_id: order.patient_id._id,
          receiver_model: "Patient",
          type: "order_completed",
          title: "All Test Results Available",
          message: `All tests for your order at ${order.owner_id?.lab_name || 'Medical Lab'} are now completed. You can view all results in your dashboard.`,
          related_id: order._id
        };
        await Notification.create(orderCompletionNotification);

        // Push notification for order completion
        const notificationController = require('./controllers/notificationController');
        await notificationController.sendPushNotificationToPatient(
          order.patient_id._id,
          `✅ All Test Results Available`,
          `All tests for your order at ${order.owner_id?.lab_name || 'Medical Lab'} are now completed. Tap to view.`,
          {
            type: 'order_completed',
            order_id: order._id.toString(),
            receiver_model: 'Patient'
          }
        );

        // WhatsApp and Email for order completion
        const orderResultUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/patient/results/${order._id}`;
        const { sendNotification } = require('./utils/sendNotification');
        await sendNotification({
          phone: order.patient_id.phone_number,
          email: order.patient_id.email,
          whatsappMessage: `Hello ${order.patient_id.full_name?.first || ''} ${order.patient_id.full_name?.last || ''},\n\n✅ All test results for your order are now available.\n\n🔗 View all results: ${orderResultUrl}\n\n🏥 Lab: ${order.owner_id?.lab_name || 'Medical Lab'}\n\nBest regards,\nMedical Laboratory Team`,
          emailSubject: `All Test Results Available - ${order.owner_id?.lab_name || 'Medical Lab'}`,
          emailHtml: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #4A90E2;">All Test Results Available</h2>
              <p>Hello ${order.patient_id.full_name?.first || ''} ${order.patient_id.full_name?.last || ''},</p>
              <p>All test results for your order are now available.</p>

              <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0; text-align: center;">
                <a href="${orderResultUrl}" style="background-color: #4A90E2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold;">View All Results</a>
              </div>

              <div style="background-color: #e3f2fd; padding: 15px; border-radius: 5px; margin: 20px 0;">
                <p style="margin: 0;"><strong>🏥 Lab:</strong> ${order.owner_id?.lab_name || 'Medical Lab'}</p>
              </div>

              <br>
              <p>Best regards,<br><strong>Medical Laboratory Team</strong></p>
            </div>
          `
        });

        // Push notification to doctor for order completion
        if (order.doctor_id) {
          await notificationController.sendPushNotificationToDoctor(
            order.doctor_id._id,
            `✅ All Test Results Available`,
            `All test results for patient ${order.patient_id?.full_name?.first || ''} ${order.patient_id?.full_name?.last || ''} are now available.`,
            {
              type: 'order_completed',
              order_id: order._id.toString(),
              patient_id: order.patient_id?._id.toString(),
              receiver_model: 'Doctor'
            }
          );
        }
      }
    } catch (patientNotificationError) {
      console.error('Error sending patient notifications:', patientNotificationError);
    }

    res.json({ message: 'HL7 result processed successfully' });

  } catch (error) {
    console.error('❌ Error processing HL7 result:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// Error Middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error', { 
    error: err.message, 
    stack: err.stack,
    url: req.url,
    method: req.method 
  });
  console.error('ERROR DETAILS:', err); // Add console log for debugging
  res.status(500).json({ message: err.message });
});

module.exports = app;

/**
 * Combined Notification Utility - Sends both WhatsApp and Email
 */

const { sendWhatsAppMessage } = require('./sendWhatsApp');
const { sendEmail, sendHtmlEmail, sendEmailWithAttachments } = require('./sendEmail');
const { formatDate, formatDateTime } = require('./dateUtils');
const { generateTestResultPDF, generateInvoicePDF, cleanupPDFFile } = require('./pdfGenerator');
const Result = require('../models/Result');

/**
 * Send notification via both WhatsApp and Email
 * @param {Object} options - Notification options
 * @param {string} options.phone - Phone number for WhatsApp
 * @param {string} options.email - Email address
 * @param {string} options.whatsappMessage - WhatsApp message
 * @param {string} options.emailSubject - Email subject
 * @param {string} options.emailHtml - Email HTML content
 * @param {string} options.emailText - Email plain text (optional)
 * @param {Array} options.mediaUrls - WhatsApp media URLs (optional)
 * @param {Array} options.attachments - Email attachments (optional)
 * @param {boolean} options.whatsappOnly - Send only WhatsApp (default: false)
 * @param {boolean} options.emailOnly - Send only Email (default: false)
 * @returns {Promise<Object>} - Result object with success status for each method
 */
async function sendNotification(options) {
  const {
    phone,
    email,
    whatsappMessage,
    emailSubject,
    emailHtml,
    emailText,
    mediaUrls = [],
    attachments = [],
    whatsappOnly = false,
    emailOnly = false
  } = options;

  const results = {
    whatsapp: { success: false, error: null },
    email: { success: false, error: null }
  };

  // Send WhatsApp (unless emailOnly is true)
  if (!emailOnly && phone && whatsappMessage) {
    // Basic phone number validation
    const cleanPhone = phone.toString().replace(/\D/g, '');
    if (cleanPhone.length < 7) {
      results.whatsapp.error = 'Invalid phone number format';
    } else if (cleanPhone.startsWith('123456789') || cleanPhone === '1234567890' || cleanPhone.startsWith('555')) {
      // Skip obviously fake/test numbers
      results.whatsapp.error = 'Test phone number detected - WhatsApp not sent';
      console.log('📱 DEBUG: Skipping WhatsApp for test phone number:', phone);
    } else {
      try {
        const whatsappSuccess = await sendWhatsAppMessage(
          phone,
          whatsappMessage,
          mediaUrls,
          false // Don't use email fallback since we're sending both
        );
        results.whatsapp.success = whatsappSuccess;
        if (!whatsappSuccess) {
          results.whatsapp.error = 'WhatsApp sending failed';
        }
      } catch (error) {
        console.error('WhatsApp notification error:', error.message);
        results.whatsapp.error = error.message;
      }
    }
  }

  // Send Email (always if email details are provided)
  if (email && emailSubject && emailHtml) {
    // Basic email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      results.email.error = 'Invalid email format';
    } else {
      try {
        let emailResult;
        if (attachments && attachments.length > 0) {
          emailResult = await sendEmailWithAttachments(
            email,
            emailSubject,
            emailHtml,
            emailText,
            attachments
          );
        } else {
          emailResult = await sendHtmlEmail(
            email,
            emailSubject,
            emailHtml,
            emailText
          );
        }
        results.email.success = emailResult.success;
        if (!emailResult.success) {
          results.email.error = 'Email sending failed';
        }
      } catch (error) {
        console.error('Email notification error:', error.message);
        results.email.error = error.message;
      }
    }
  }

  return results;
}

/**
 * Send lab report notification via both WhatsApp and Email
 * @param {Object} patient - Patient object with phone_number, email, full_name
 * @param {Object} test - Test object with test_name
 * @param {string} resultUrl - URL to view results
 * @param {string} labName - Lab name
 * @param {string} barcode - Order barcode/ID
 * @param {boolean} isAbnormal - Whether results are abnormal
 * @param {number} abnormalCount - Number of abnormal components/values
 * @param {Object} order - Order object (for PDF generation)
 * @param {Object} result - Result object (for PDF generation)
 * @param {Object} detail - Order detail object (for PDF generation)
 * @returns {Promise<Object>} - Result object
 */
async function sendLabReport(patient, test, resultUrl, labName, barcode, isAbnormal = false, abnormalCount = 0, order = null, result = null, detail = null) {
  const patientName = `${patient.full_name?.first || ''} ${patient.full_name?.last || ''}`.trim();
  const patientPhone = patient.phone_number;
  const patientEmail = patient.email;

  let urgencyIndicator = '';
  let urgencyMessage = '';
  let emailAlertClass = '';

  if (isAbnormal) {
    urgencyIndicator = '🚨 CRITICAL: ';
    urgencyMessage = `\n\n⚠️ **IMPORTANT:** ${abnormalCount} abnormal value(s) detected. Please contact your doctor immediately for interpretation.`;
    emailAlertClass = 'alert-critical';
  }

  const whatsappMessage = `${urgencyIndicator}Your test result for ${test.test_name} is now available.\n\nHello ${patientName},\n\n✅ Your test result for *${test.test_name}* is now available.\n\n🔗 View your result: ${resultUrl}\n\n🏥 Lab: ${labName}\n📋 Order: ${barcode}${urgencyMessage}\n\nBest regards,\nMedical Laboratory Team`;

  const emailSubject = `${urgencyIndicator}${test.test_name} Result Available`;

  const emailHtml = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      ${isAbnormal ? '<div style="background-color: #ffebee; border: 2px solid #f44336; border-radius: 8px; padding: 15px; margin-bottom: 20px;"><h3 style="color: #d32f2f; margin: 0;">🚨 CRITICAL: Abnormal Test Results</h3><p style="margin: 10px 0 0 0; color: #d32f2f;">${abnormalCount} abnormal value(s) detected. Please contact your doctor immediately.</p></div>' : ''}

      <h2 style="color: #4A90E2;">Test Result Available</h2>
      <p>Hello ${patientName},</p>
      <p>Your test result for <strong>${test.test_name}</strong> is now available.</p>

      <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0; text-align: center;">
        <a href="${resultUrl}" style="background-color: #4A90E2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold;">View Your Result</a>
      </div>

      <div style="background-color: #e3f2fd; padding: 15px; border-radius: 5px; margin: 20px 0;">
        <p style="margin: 0;"><strong>🏥 Lab:</strong> ${labName}</p>
        <p style="margin: 5px 0 0 0;"><strong>📋 Order:</strong> ${barcode}</p>
      </div>

      ${isAbnormal ? '<div style="background-color: #ffebee; border-left: 4px solid #f44336; padding: 15px; margin: 20px 0;"><p style="margin: 0; color: #d32f2f;"><strong>Medical Alert:</strong> Your results show abnormal values. Please contact your healthcare provider immediately to discuss these results and next steps.</p></div>' : ''}

      <br>
      <p>Best regards,<br><strong>Medical Laboratory Team</strong></p>
      <hr style="border: none; border-top: 1px solid #eee;">
      <p style="color: #666; font-size: 12px;">This is an automated message from the Medical Lab System. Your PDF report is attached to this email.</p>
    </div>
  `;

  // Generate PDF attachment if we have the required data
  let attachments = [];
  let pdfPath = null;

  if (order && result && detail) {
    try {
      // Prepare report data for PDF generation
      const reportData = {
        lab: {
          name: labName,
          address: order.owner_id?.address || 'N/A',
          phone_number: order.owner_id?.phone_number || 'N/A'
        },
        patient: {
          name: patientName,
          patient_id: patient.patient_id,
          age: patient.birthday ? Math.floor((new Date() - new Date(patient.birthday)) / 31557600000) : null,
          gender: patient.gender
        },
        order: {
          date: order.order_date
        },
        test: {
          name: test.test_name,
          code: test.test_code
        },
        result: {
          value: result.result_value,
          units: result.units,
          reference_range: result.reference_range,
          remarks: result.remarks,
          components: result.components || []
        },
        technician: detail.staff_id ? `${detail.staff_id.full_name?.first || ''} ${detail.staff_id.full_name?.last || ''}`.trim() : null,
        report_date: new Date()
      };

      // Generate PDF
      pdfPath = await generateTestResultPDF(reportData);

      // Add PDF as attachment
      attachments.push({
        filename: `Lab_Report_${test.test_name.replace(/\s+/g, '_')}_${barcode}.pdf`,
        path: pdfPath,
        contentType: 'application/pdf'
      });

      // console.log('✅ PDF report generated for email attachment');
    } catch (pdfError) {
      console.error('❌ Failed to generate PDF:', pdfError);
      // Continue without PDF - don't fail the notification
    }
  }

  try {
    const notificationResult = await sendNotification({
      phone: patientPhone,
      email: patientEmail,
      whatsappMessage,
      emailSubject,
      emailHtml,
      attachments
    });

    // Clean up PDF file after sending
    if (pdfPath) {
      setTimeout(() => cleanupPDFFile(pdfPath), 5000); // Clean up after 5 seconds
    }

    return notificationResult;
  } catch (error) {
    // Clean up PDF file on error
    if (pdfPath) {
      cleanupPDFFile(pdfPath);
    }

    console.error('❌ Lab report notification failed:', error.message);

    // Return a result object instead of throwing to prevent upload failure
    return {
      whatsapp: { success: false, error: 'Notification system error' },
      email: { success: false, error: 'Notification system error' }
    };
  }
}

/**
 * Send invoice report via both WhatsApp and Email with PDF attachment
 * @param {Object} patient - Patient object
 * @param {Object} invoice - Invoice object
 * @param {string} invoiceUrl - URL to view invoice online
 * @param {string} labName - Lab name
 * @returns {Promise<Object>} - Result object
 */
async function sendInvoiceReport(patient, invoice, invoiceUrl, labName) {
  const patientName = `${patient.full_name?.first || ''} ${patient.full_name?.last || ''}`.trim();
  const patientPhone = patient.phone_number;
  const patientEmail = patient.email;

  const whatsappMessage = `🧾 Your invoice from ${labName} is ready.\n\nHello ${patientName},\n\n✅ Your invoice is now available.\n\n🔗 View your invoice: ${invoiceUrl}\n\n💰 Total Amount: ₪${invoice.total_amount?.toFixed(2) || 'N/A'}\n🧾 Invoice ID: ${invoice.invoice_id || `INV-${invoice._id.toString().slice(-6).toUpperCase()}`}\n\n🏥 Lab: ${labName}\n\nBest regards,\nMedical Laboratory Team`;

  const emailSubject = `Invoice Available - ${labName}`;

  const emailHtml = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h2 style="color: #4A90E2;">Invoice Available</h2>
      <p>Hello ${patientName},</p>
      <p>Your invoice from <strong>${labName}</strong> is now available.</p>

      <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0; text-align: center;">
        <a href="${invoiceUrl}" style="background-color: #4A90E2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold;">View Your Invoice</a>
      </div>

      <div style="background-color: #e3f2fd; padding: 15px; border-radius: 5px; margin: 20px 0;">
        <p style="margin: 0;"><strong>🏥 Lab:</strong> ${labName}</p>
        <p style="margin: 5px 0 0 0;"><strong>🧾 Invoice ID:</strong> ${invoice.invoice_id || `INV-${invoice._id.toString().slice(-6).toUpperCase()}`}</p>
        <p style="margin: 5px 0 0 0;"><strong>💰 Total Amount:</strong> ₪${invoice.total_amount?.toFixed(2) || 'N/A'}</p>
        <p style="margin: 5px 0 0 0;"><strong>📅 Date:</strong> ${new Date(invoice.created_at).toLocaleDateString()}</p>
      </div>

      <br>
      <p>Best regards,<br><strong>Medical Laboratory Team</strong></p>
      <hr style="border: none; border-top: 1px solid #eee;">
      <p style="color: #666; font-size: 12px;">This is an automated message from the Medical Lab System. Your PDF invoice is attached to this email.</p>
    </div>
  `;

  // Generate PDF attachment
  let attachments = [];
  let pdfPath = null;

  try {
    // Prepare invoice data for PDF generation
    const invoiceData = {
      invoice_id: invoice.invoice_id || `INV-${invoice._id.toString().slice(-6).toUpperCase()}`,
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
        name: patientName,
        patient_id: patient.patient_id
      },
      tests: invoice.items || [],
      payments: invoice.payments || []
    };

    // Generate PDF
    pdfPath = await generateInvoicePDF(invoiceData);

    // Add PDF as attachment
    attachments.push({
      filename: `Invoice_${invoice.invoice_id}.pdf`,
      path: pdfPath,
      contentType: 'application/pdf'
    });

    // console.log('✅ PDF invoice generated for email attachment');
  } catch (pdfError) {
    console.error('❌ Failed to generate invoice PDF:', pdfError);
    // Continue without PDF - don't fail the notification
  }

  try {
    const notificationResult = await sendNotification({
      phone: patientPhone,
      email: patientEmail,
      whatsappMessage,
      emailSubject,
      emailHtml,
      attachments
    });

    // Clean up PDF file after sending
    if (pdfPath) {
      setTimeout(() => cleanupPDFFile(pdfPath), 5000); // Clean up after 5 seconds
    }

    return notificationResult;
  } catch (error) {
    // Clean up PDF file on error
    if (pdfPath) {
      cleanupPDFFile(pdfPath);
    }

    console.error('❌ Invoice report notification failed:', error.message);

    // Return a result object instead of throwing to prevent upload failure
    return {
      whatsapp: { success: false, error: 'Notification system error' },
      email: { success: false, error: 'Notification system error' }
    };
  }
}



/**
 * Send payment reminder via both WhatsApp and Email
 * @param {string} patientPhone - Patient phone number
 * @param {string} patientEmail - Patient email address
 * @param {string} patientName - Patient name
 * @param {string} labName - Lab name
 * @param {number} amount - Amount due
 * @param {Date} dueDate - Due date
 * @param {string} invoiceId - Invoice ID
 * @returns {Promise<Object>} - Result object
 */
async function sendPaymentReminderNotification(patientPhone, patientEmail, patientName, labName, amount, dueDate, invoiceId) {
  const formattedDueDate = formatDate(dueDate);

  const whatsappMessage = `💳 *Payment Reminder*\n\nHello ${patientName},\n\nThis is a reminder that payment for your recent services at ${labName} is due.\n\n💰 Amount: ₪${amount.toFixed(2)}\n📅 Due Date: ${formattedDueDate}\n🧾 Invoice: ${invoiceId}\n\nPlease make your payment to avoid any delays in service.\n\nThank you!`;

  const emailSubject = `Payment Reminder - ${labName}`;
  const emailHtml = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h2 style="color: #4A90E2;">Payment Reminder</h2>
      <p>Hello ${patientName},</p>
      <p>This is a reminder that payment for your recent services at <strong>${labName}</strong> is due.</p>
      <div style="background-color: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #ffc107;">
        <p style="margin: 5px 0;"><strong>💰 Amount Due:</strong> ₪${amount.toFixed(2)}</p>
        <p style="margin: 5px 0;"><strong>📅 Due Date:</strong> ${formattedDueDate}</p>
        <p style="margin: 5px 0;"><strong>🧾 Invoice ID:</strong> ${invoiceId}</p>
      </div>
      <p>Please make your payment to avoid any delays in service or additional fees.</p>
      <br>
      <p>Thank you for choosing ${labName}!</p>
      <hr style="border: none; border-top: 1px solid #eee;">
      <p style="color: #666; font-size: 12px;">This is an automated message from the Medical Lab System.</p>
    </div>
  `;

  return await sendNotification({
    phone: patientPhone,
    email: patientEmail,
    whatsappMessage,
    emailSubject,
    emailHtml
  });
}

/**
 * Send general notification via both WhatsApp and Email
 * @param {string} phone - Phone number
 * @param {string} email - Email address
 * @param {string} message - Message content
 * @param {string} subject - Email subject
 * @param {Object} options - Additional options
 * @returns {Promise<Object>} - Result object
 */
async function sendGeneralNotification(phone, email, message, subject, options = {}) {
  const emailHtml = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h2 style="color: #4A90E2;">Medical Lab System Notification</h2>
      <p>${message.replace(/\n/g, '<br>')}</p>
      <hr style="border: none; border-top: 1px solid #eee;">
      <p style="color: #666; font-size: 12px;">This is an automated message from the Medical Lab System.</p>
    </div>
  `;

  return await sendNotification({
    phone,
    email,
    whatsappMessage: message,
    emailSubject: subject,
    emailHtml,
    ...options
  });
}

/**
 * Send account activation notification to new patients
 * @param {Object} patientInfo - Patient information object
 * @param {string} username - Generated username
 * @param {string} password - Generated password
 * @param {string} patientId - Patient ID
 * @param {string} barcode - Order barcode
 * @param {number} testCount - Number of tests ordered
 * @param {Date} orderDate - Order date
 * @returns {Promise<Object>} - Result object
 */
async function sendAccountActivation(patientInfo, username, password, patientId, barcode, testCount, orderDate) {
  const patientName = `${patientInfo.full_name.first} ${patientInfo.full_name.last}`;
  const patientPhone = patientInfo.phone_number;
  const patientEmail = patientInfo.email;

  // Format order date
  const formattedDate = formatDateTime(orderDate);

  // WhatsApp message
  const whatsappMessage = `🏥 *Welcome to Medical Lab System*

Hello ${patientName}!

Your patient account has been created successfully.

📋 *Account Details:*
• Patient ID: ${patientId}
• Username: ${username}
• Password: ${password}

🔐 *Please change your password after first login for security.*

📊 *Order Information:*
${barcode ? `• Order Barcode: ${barcode}` : ''}
• Tests Ordered: ${testCount}
• Order Date: ${formattedDate}
• Status: Processing

📱 *Login Instructions:*
1. Download the Medical Lab app
2. Use your username and password to login
3. View your test results and manage your account

For any questions, please contact the lab.

Thank you for choosing our services!`;

  // Email subject and HTML content
  const emailSubject = `Welcome to Medical Lab System - Your Account Details`;

  const emailHtml = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; background-color: #f8f9fa; padding: 20px;">
      <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
        <h1 style="color: #4A90E2; text-align: center; margin-bottom: 30px;">🏥 Welcome to Medical Lab System</h1>

        <p style="font-size: 16px; line-height: 1.6; color: #333;">Hello <strong>${patientName}</strong>,</p>

        <p style="font-size: 16px; line-height: 1.6; color: #333;">
          Your patient account has been created successfully. You can now access your medical test results and manage your account through our mobile app.
        </p>

        <div style="background-color: #e8f4fd; padding: 20px; border-radius: 8px; margin: 25px 0; border-left: 4px solid #4A90E2;">
          <h3 style="color: #4A90E2; margin-top: 0;">📋 Account Details</h3>
          <p style="margin: 8px 0;"><strong>Patient ID:</strong> ${patientId}</p>
          <p style="margin: 8px 0;"><strong>Username:</strong> ${username}</p>
          <p style="margin: 8px 0;"><strong>Password:</strong> ${password}</p>
        </div>

        <div style="background-color: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #ffc107;">
          <p style="margin: 0; color: #856404;">
            <strong>🔐 Security Notice:</strong> Please change your password after your first login for better security.
          </p>
        </div>

        <div style="background-color: #d1ecf1; padding: 20px; border-radius: 8px; margin: 25px 0; border-left: 4px solid #17a2b8;">
          <h3 style="color: #17a2b8; margin-top: 0;">📊 Order Information</h3>
          ${barcode ? `<p style="margin: 8px 0;"><strong>Order Barcode:</strong> ${barcode}</p>` : ''}
          <p style="margin: 8px 0;"><strong>Tests Ordered:</strong> ${testCount}</p>
          <p style="margin: 8px 0;"><strong>Order Date:</strong> ${formattedDate}</p>
          <p style="margin: 8px 0;"><strong>Status:</strong> Processing</p>
        </div>

        <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin: 25px 0;">
          <h3 style="color: #495057; margin-top: 0;">📱 How to Access Your Account</h3>
          <ol style="color: #333; padding-left: 20px;">
            <li>Download the Medical Lab mobile app from your app store</li>
            <li>Open the app and select "Patient Login"</li>
            <li>Enter your username: <strong>${username}</strong></li>
            <li>Enter your password: <strong>${password}</strong></li>
            <li>Change your password in the profile section after login</li>
          </ol>
        </div>

        <p style="font-size: 16px; line-height: 1.6; color: #333;">
          For any questions or assistance, please don't hesitate to contact our lab staff.
        </p>

        <p style="font-size: 16px; line-height: 1.6; color: #333;">
          Thank you for choosing our medical laboratory services!
        </p>

        <hr style="border: none; border-top: 1px solid #dee2e6; margin: 30px 0;">

        <p style="color: #6c757d; font-size: 14px; text-align: center;">
          This is an automated message from the Medical Lab System.<br>
          Please do not reply to this email.
        </p>
      </div>
    </div>
  `;

  return await sendNotification({
    phone: patientPhone,
    email: patientEmail,
    whatsappMessage,
    emailSubject,
    emailHtml
  });
}

/**
 * Send complete order results via both WhatsApp and Email
 * @param {Object} patient - Patient object
 * @param {Object} order - Order object
 * @param {Object} owner - Owner object
 * @param {Array} orderDetails - Array of order details with populated test and result data
 * @returns {Promise<Object>} - Result object with success status for each method
 */
async function sendOrderResults(patient, order, owner, orderDetails) {
  const patientName = `${patient.full_name?.first || ''} ${patient.full_name?.last || ''}`.trim();
  const patientPhone = patient.phone_number;
  const patientEmail = patient.email;
  const labName = owner.lab_name;
  const orderId = order._id.toString();

  // Count abnormal results
  let totalAbnormalCount = 0;
  let hasAbnormalResults = false;
  const testResults = [];

  for (const detail of orderDetails) {
    if (detail.status === 'completed') {
      const result = await Result.findOne({ detail_id: detail._id });
      if (result) {
        const abnormalCount = result.abnormal_components_count || 0;
        totalAbnormalCount += abnormalCount;
        if (abnormalCount > 0) hasAbnormalResults = true;

        testResults.push({
          testName: detail.test_id.test_name,
          isAbnormal: abnormalCount > 0,
          abnormalCount: abnormalCount,
          status: 'Completed'
        });
      }
    }
  }

  let urgencyIndicator = '';
  let urgencyMessage = '';
  let emailAlertClass = '';

  if (hasAbnormalResults) {
    urgencyIndicator = '🚨 CRITICAL: ';
    urgencyMessage = `\n\n⚠️ **IMPORTANT:** ${totalAbnormalCount} abnormal value(s) detected across your tests. Please contact your doctor immediately for interpretation.`;
    emailAlertClass = 'alert-critical';
  }

  // Build WhatsApp message
  let whatsappMessage = `${urgencyIndicator}Your Complete Lab Results Are Ready\n\nHello ${patientName},\n\n✅ All your test results are now available.\n\n🏥 Lab: ${labName}\n📋 Order: ${orderId}\n\n📊 Test Results Summary:\n`;

  testResults.forEach((test, index) => {
    whatsappMessage += `${index + 1}. ${test.testName} - ${test.status}`;
    if (test.isAbnormal) {
      whatsappMessage += ` (⚠️ ${test.abnormalCount} abnormal values)`;
    }
    whatsappMessage += '\n';
  });

  whatsappMessage += `\n🔗 View all results: ${process.env.FRONTEND_URL || 'http://localhost:8080'}/patient-dashboard/order-report/${orderId}${urgencyMessage}\n\nBest regards,\nMedical Laboratory Team`;

  // Build email subject and HTML
  const emailSubject = `${urgencyIndicator}Complete Lab Results Available - Order ${orderId}`;

  let emailHtml = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      ${hasAbnormalResults ? '<div style="background-color: #ffebee; border: 2px solid #f44336; border-radius: 8px; padding: 15px; margin-bottom: 20px;"><h3 style="color: #d32f2f; margin: 0;">🚨 CRITICAL: Abnormal Test Results</h3><p style="margin: 10px 0 0 0; color: #d32f2f;">${totalAbnormalCount} abnormal value(s) detected across your tests. Please contact your doctor immediately.</p></div>' : ''}

      <h2 style="color: #4A90E2;">Complete Lab Results Available</h2>
      <p>Hello ${patientName},</p>
      <p>All your test results are now available. Here's a summary of your completed tests:</p>

      <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0;">
        <h3 style="margin-top: 0; color: #333;">📊 Test Results Summary</h3>
        <table style="width: 100%; border-collapse: collapse;">
          <thead>
            <tr style="background-color: #e9ecef;">
              <th style="border: 1px solid #dee2e6; padding: 8px; text-align: left;">Test Name</th>
              <th style="border: 1px solid #dee2e6; padding: 8px; text-align: center;">Status</th>
              <th style="border: 1px solid #dee2e6; padding: 8px; text-align: center;">Abnormal Values</th>
            </tr>
          </thead>
          <tbody>`;

  testResults.forEach((test, index) => {
    const rowColor = test.isAbnormal ? '#ffebee' : '#f8f9fa';
    emailHtml += `
            <tr style="background-color: ${rowColor};">
              <td style="border: 1px solid #dee2e6; padding: 8px;">${test.testName}</td>
              <td style="border: 1px solid #dee2e6; padding: 8px; text-align: center;">${test.status}</td>
              <td style="border: 1px solid #dee2e6; padding: 8px; text-align: center;">${test.isAbnormal ? `${test.abnormalCount}` : '0'}</td>
            </tr>`;
  });

  emailHtml += `
          </tbody>
        </table>
      </div>

      <div style="background-color: #e3f2fd; padding: 15px; border-radius: 5px; margin: 20px 0; text-align: center;">
        <a href="${process.env.FRONTEND_URL || 'http://localhost:8080'}/patient-dashboard/order-report/${orderId}" style="background-color: #4A90E2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold;">View All Your Results</a>
      </div>

      <div style="background-color: #e3f2fd; padding: 15px; border-radius: 5px; margin: 20px 0;">
        <p style="margin: 0;"><strong>🏥 Lab:</strong> ${labName}</p>
        <p style="margin: 5px 0 0 0;"><strong>📋 Order ID:</strong> ${orderId}</p>
      </div>

      ${hasAbnormalResults ? '<div style="background-color: #ffebee; border-left: 4px solid #f44336; padding: 15px; margin: 20px 0;"><p style="margin: 0; color: #d32f2f;"><strong>Medical Alert:</strong> Your results show abnormal values. Please contact your healthcare provider immediately to discuss these results and next steps.</p></div>' : ''}

      <br>
      <p>Best regards,<br><strong>Medical Laboratory Team</strong></p>
      <hr style="border: none; border-top: 1px solid #eee;">
      <p style="color: #666; font-size: 12px;">This is an automated message from the Medical Lab System.</p>
    </div>
  `;

  return await sendNotification({
    phone: patientPhone,
    email: patientEmail,
    whatsappMessage,
    emailSubject,
    emailHtml
  });
}

/**
 * Send staff/doctor account activation via both WhatsApp and Email
 * @param {Object} userInfo - Staff or Doctor object
 * @param {string} username - Generated username
 * @param {string} password - Generated password
 * @param {string} role - 'Staff' or 'Doctor'
 * @param {string} labName - Lab name from owner
 * @returns {Promise<Object>} - Result object with success status for each method
 */
async function sendStaffDoctorActivation(userInfo, username, password, role, labName) {
  const userName = role === 'Staff' 
    ? `${userInfo.full_name?.first || ''} ${userInfo.full_name?.last || ''}`.trim()
    : `${userInfo.name?.first || ''} ${userInfo.name?.last || ''}`.trim();
  
  const userPhone = userInfo.phone_number;
  const userEmail = userInfo.email;

  // WhatsApp message
  const whatsappMessage = `🏥 *Welcome to ${labName}*

Hello ${userName}!

Your ${role.toLowerCase()} account has been created successfully.

📋 *Account Details:*
• Username: ${username}
• Password: ${password}
• Role: ${role}

🔐 *Please change your password after first login for security.*

📱 *Login Instructions:*
1. Download the Medical Lab app
2. Select "${role} Login"
3. Use your username and password to login
4. Change your password in the profile section

Welcome to the team!

Best regards,
${labName} Management`;

  // Email subject and HTML content
  const emailSubject = `Welcome to ${labName} - Your ${role} Account Details`;

  const emailHtml = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; background-color: #f8f9fa; padding: 20px;">
      <div style="background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
        <h1 style="color: #4A90E2; text-align: center; margin-bottom: 30px;">🏥 Welcome to ${labName}</h1>

        <p style="font-size: 16px; line-height: 1.6; color: #333;">Hello <strong>${userName}</strong>,</p>

        <p style="font-size: 16px; line-height: 1.6; color: #333;">
          Your ${role.toLowerCase()} account has been created successfully. You can now access the Medical Lab System to manage your responsibilities.
        </p>

        <div style="background-color: #e8f4fd; padding: 20px; border-radius: 8px; margin: 25px 0; border-left: 4px solid #4A90E2;">
          <h3 style="color: #4A90E2; margin-top: 0;">📋 Account Details</h3>
          <p style="margin: 8px 0;"><strong>Username:</strong> ${username}</p>
          <p style="margin: 8px 0;"><strong>Password:</strong> ${password}</p>
          <p style="margin: 8px 0;"><strong>Role:</strong> ${role}</p>
        </div>

        <div style="background-color: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #ffc107;">
          <p style="margin: 0; color: #856404;">
            <strong>🔐 Security Notice:</strong> Please change your password after your first login for better security.
          </p>
        </div>

        <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin: 25px 0;">
          <h3 style="color: #495057; margin-top: 0;">📱 How to Access Your Account</h3>
          <ol style="color: #333; padding-left: 20px;">
            <li>Download the Medical Lab mobile app from your app store</li>
            <li>Open the app and select "${role} Login"</li>
            <li>Enter your username: <strong>${username}</strong></li>
            <li>Enter your password: <strong>${password}</strong></li>
            <li>Change your password in the profile section after login</li>
          </ol>
        </div>

        <p style="font-size: 16px; line-height: 1.6; color: #333;">
          Welcome to the ${labName} team! If you have any questions or need assistance getting started, please contact your lab owner.
        </p>

        <hr style="border: none; border-top: 1px solid #dee2e6; margin: 30px 0;">

        <p style="color: #6c757d; font-size: 14px; text-align: center;">
          This is an automated message from the Medical Lab System.<br>
          Please do not reply to this email.
        </p>
      </div>
    </div>
  `;

  return await sendNotification({
    phone: userPhone,
    email: userEmail,
    whatsappMessage,
    emailSubject,
    emailHtml
  });
}

module.exports = {
  sendNotification,
  sendLabReport,
  sendInvoiceReport,
  sendOrderResults,
  sendStaffDoctorActivation,
  sendPaymentReminderNotification,
  sendGeneralNotification,
  sendAccountActivation
};
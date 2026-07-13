/**
 * Send Email Utility using Nodemailer
 */

const nodemailer = require('nodemailer');

// Create transporter with better configuration
const createTransporter = () => {
  // Use Gmail as default, but allow other services
  const service = process.env.EMAIL_SERVICE || 'gmail';
  const host = process.env.EMAIL_HOST;
  const port = process.env.EMAIL_PORT || (service === 'gmail' ? 587 : 587);
  const secure = process.env.EMAIL_SECURE === 'true' || service === 'gmail';

  if (service === 'gmail') {
    return nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASSWORD
      }
    });
  } else {
    // Custom SMTP configuration
    return nodemailer.createTransport({
      host: host,
      port: port,
      secure: secure,
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASSWORD
      }
    });
  }
};

/**
 * Send a plain text email
 * @param {string} to - Recipient email address
 * @param {string} subject - Email subject
 * @param {string} text - Plain text message
 * @returns {Promise<Object>} - Result object
 */
const sendEmail = async (to, subject, text) => {
  try {
    if (!process.env.EMAIL_USER || !process.env.EMAIL_PASSWORD) {
      throw new Error('Email credentials not configured');
    }

    const transporter = createTransporter();

    const mailOptions = {
      from: `"Medical Lab System" <${process.env.EMAIL_USER}>`,
      to: to,
      subject: subject,
      text: text
    };

    const info = await transporter.sendMail(mailOptions);

    // console.log('📧 Email sent successfully:', info.messageId);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error('❌ Error sending email:', error);
    throw new Error(`Failed to send email: ${error.message}`);
  }
};

/**
 * Send an HTML email
 * @param {string} to - Recipient email address
 * @param {string} subject - Email subject
 * @param {string} html - HTML content
 * @param {string} text - Plain text fallback
 * @returns {Promise<Object>} - Result object
 */
const sendHtmlEmail = async (to, subject, html, text = '') => {
  console.log('📧 DEBUG: sendHtmlEmail called with:');
  console.log('   To:', to);
  console.log('   Subject:', subject);
  console.log('   HTML length:', html?.length || 0);
  console.log('   Text length:', text?.length || 0);
  console.log('   Email user configured:', !!process.env.EMAIL_USER);
  console.log('   Email password configured:', !!process.env.EMAIL_PASSWORD);

  try {
    if (!process.env.EMAIL_USER || !process.env.EMAIL_PASSWORD) {
      throw new Error('Email credentials not configured');
    }

    console.log('📧 DEBUG: Creating email transporter...');
    const transporter = createTransporter();

    const mailOptions = {
      from: `"Medical Lab System" <${process.env.EMAIL_USER}>`,
      to: to,
      subject: subject,
      html: html,
      text: text || html.replace(/<[^>]*>/g, '') // Strip HTML tags for text version
    };

    console.log('📧 DEBUG: Sending email with options:', {
      from: mailOptions.from,
      to: mailOptions.to,
      subject: mailOptions.subject,
      hasHtml: !!mailOptions.html,
      hasText: !!mailOptions.text
    });

    const info = await transporter.sendMail(mailOptions);

    console.log('📧 DEBUG: HTML Email sent successfully, messageId:', info.messageId);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error('📧 DEBUG: Error sending HTML email:', error.message);
    console.error('📧 DEBUG: Error details:', error);
    throw new Error(`Failed to send HTML email: ${error.message}`);
  }
};

/**
 * Send email with attachments
 * @param {string} to - Recipient email address
 * @param {string} subject - Email subject
 * @param {string} html - HTML content
 * @param {string} text - Plain text fallback
 * @param {Array} attachments - Array of attachment objects
 * @returns {Promise<Object>} - Result object
 */
const sendEmailWithAttachments = async (to, subject, html, text = '', attachments = []) => {
  try {
    if (!process.env.EMAIL_USER || !process.env.EMAIL_PASSWORD) {
      throw new Error('Email credentials not configured');
    }

    const transporter = createTransporter();

    const mailOptions = {
      from: `"Medical Lab System" <${process.env.EMAIL_USER}>`,
      to: to,
      subject: subject,
      html: html,
      text: text || html.replace(/<[^>]*>/g, ''),
      attachments: attachments
    };

    const info = await transporter.sendMail(mailOptions);

    // console.log('📧 Email with attachments sent successfully:', info.messageId);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error('❌ Error sending email with attachments:', error);
    throw new Error(`Failed to send email with attachments: ${error.message}`);
  }
};

module.exports = {
  sendEmail,
  sendHtmlEmail,
  sendEmailWithAttachments
};

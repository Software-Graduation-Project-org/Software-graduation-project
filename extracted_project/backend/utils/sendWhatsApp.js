const twilio = require('twilio');
const sendEmail = require('./sendEmail'); // Fallback to email

const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);

// Use production WhatsApp number if available, otherwise fallback to sandbox
const WHATSAPP_NUMBER = process.env.TWILIO_WHATSAPP_NUMBER || 'whatsapp:+14155238886';

/**
 * Send a WhatsApp message
 * @param {string} to - Recipient phone number (e.g., '+972594317447')
 * @param {string} message - Text message
 * @param {string[]} mediaUrls - Array of media URLs (e.g., PDF links)
 * @param {boolean} useFallback - Whether to fallback to email if WhatsApp fails
 * @param {string} emailSubject - Email subject for fallback
 * @param {string} emailHtml - Email HTML for fallback
 * @returns {Promise<boolean>} - Success status
 */
async function sendWhatsAppMessage(to, message, mediaUrls = [], useFallback = true, emailSubject = '', emailHtml = '') {
  console.log('📱 DEBUG: sendWhatsAppMessage called with:');
  console.log('   To:', to);
  console.log('   Message length:', message?.length || 0);
  console.log('   Media URLs count:', mediaUrls?.length || 0);
  console.log('   Use fallback:', useFallback);
  console.log('   WhatsApp number:', WHATSAPP_NUMBER);

  try {
    const payload = {
      from: WHATSAPP_NUMBER,
      to: `whatsapp:${to}`,
      body: message,
    };

    if (mediaUrls && mediaUrls.length > 0) {
      payload.mediaUrl = mediaUrls;
    }

    console.log('📱 DEBUG: Sending WhatsApp payload:', { from: payload.from, to: payload.to, hasBody: !!payload.body, hasMedia: !!payload.mediaUrl });
    const result = await client.messages.create(payload);
    console.log('📱 DEBUG: WhatsApp message sent successfully, SID:', result.sid);
    return true;
  } catch (error) {
    console.error('📱 DEBUG: Failed to send WhatsApp message:', error.message);
    console.error('📱 DEBUG: Error details:', error);

    if (useFallback && emailSubject && emailHtml) {
      // console.log('Falling back to email...');
      try {
        await sendEmail(to, emailSubject, emailHtml); // Assuming sendEmail accepts email address
        // console.log('Email fallback sent successfully');
        return true;
      } catch (emailError) {
        console.error('Email fallback also failed:', emailError.message);
        return false;
      }
    }

    return false;
  }
}

/**
 * Send lab report via WhatsApp
 * @param {string} patientPhone - Patient's phone number
 * @param {string} patientEmail - Patient's email for fallback
 * @param {string} reportUrl - URL to the PDF report
 * @param {string} patientName - Patient's name
 */
async function sendLabReport(patientPhone, patientEmail, reportUrl, patientName = 'Patient') {
  const message = `Hello ${patientName},\n\nYour lab report is ready. Please find it attached.`;
  const mediaUrls = [reportUrl];

  const emailSubject = 'Your Lab Report';
  const emailHtml = `
    <h2>Hello ${patientName},</h2>
    <p>Your lab report is ready.</p>
    <p><a href="${reportUrl}">Download your report here</a></p>
    <p>Best regards,<br>Medical Lab Team</p>
  `;

  return await sendWhatsAppMessage(patientPhone, message, mediaUrls, true, emailSubject, emailHtml);
}



/**
 * Send a WhatsApp template message
 * @param {string} to - Recipient phone number (e.g., '+972594317447')
 * @param {string} contentSid - Template content SID from Twilio
 * @param {object} contentVariables - Variables for the template (e.g., {"1":"12/1","2":"3pm"})
 * @param {boolean} useFallback - Whether to fallback to email if WhatsApp fails
 * @param {string} emailSubject - Email subject for fallback
 * @param {string} emailHtml - Email HTML for fallback
 * @returns {Promise<boolean>} - Success status
 */
async function sendWhatsAppTemplate(to, contentSid, contentVariables, useFallback = true, emailSubject = '', emailHtml = '') {
  try {
    const payload = {
      from: WHATSAPP_NUMBER,
      to: `whatsapp:${to}`,
      contentSid: contentSid,
      contentVariables: JSON.stringify(contentVariables),
    };

    const result = await client.messages.create(payload);
    // console.log('WhatsApp template message sent successfully:', result.sid);
    return true;
  } catch (error) {
    console.error('Failed to send WhatsApp template message:', error.message);

    if (useFallback && emailSubject && emailHtml) {
      // console.log('Falling back to email...');
      try {
        await sendEmail(to, emailSubject, emailHtml);
        // console.log('Email fallback sent successfully');
        return true;
      } catch (emailError) {
        console.error('Email fallback also failed:', emailError.message);
        return false;
      }
    }

    return false;
  }
}

module.exports = {
  sendWhatsAppMessage,
  sendWhatsAppTemplate,
  sendLabReport,
};

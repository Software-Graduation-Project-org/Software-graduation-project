/**
 * Send SMS Utility
 */

const sendSMS = async (phoneNumber, message) => {
  try {
    // For now, just log the SMS that would be sent
    // console.log('📱 SMS would be sent:');
    // console.log(`To: ${phoneNumber}`);
    // console.log(`Message: ${message}`);
    // console.log('---');

    // Simulate successful SMS sending
    return { success: true, message: 'SMS logged (not actually sent)' };

    /* Example with Twilio:
    const twilio = require('twilio');

    const client = twilio(
      process.env.TWILIO_ACCOUNT_SID,
      process.env.TWILIO_AUTH_TOKEN
    );

    const result = await client.messages.create({
      body: message,
      from: process.env.TWILIO_PHONE_NUMBER,
      to: phoneNumber
    });

    return { success: true, messageId: result.sid };
    */
  } catch (error) {
    console.error('❌ Error sending SMS:', error);
    throw new Error(`Failed to send SMS: ${error.message}`);
  }
};

module.exports = sendSMS;

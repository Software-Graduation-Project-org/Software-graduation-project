const express = require('express');
const router = express.Router();
const twilio = require('twilio');
const Notification = require('../models/Notification');
const Admin = require('../models/Admin');
const LabOwner = require('../models/Owner');
const { sendWhatsAppMessage } = require('../utils/sendWhatsApp');

// Twilio webhook for incoming WhatsApp messages
router.post('/webhook', async (req, res) => {
  try {
    const { From, Body, To } = req.body;

    // Remove 'whatsapp:' prefix from phone numbers
    const senderPhone = From.replace('whatsapp:', '');
    const twilioNumber = To.replace('whatsapp:', '');

    console.log(`Incoming WhatsApp from ${senderPhone}: ${Body}`);

    // Find admin by phone number
    const admin = await Admin.findOne({ phone_number: senderPhone });
    if (admin) {
      // Admin sending message - send directly to their owner
      const owner = await LabOwner.findOne({ admin_id: admin._id });
      if (owner) {
        const directMessage = `📬 Direct Message from Admin\n\n💬 ${Body}\n\n---\nRegards,\n${admin.full_name.first} ${admin.full_name.last}`;
        await sendWhatsAppMessage(owner.phone_number, directMessage);
        console.log('Direct message sent to owner');
      } else {
        console.log('No owner found for this admin');
      }
      return res.status(200).send('OK');
    }

    // Find owner by phone number
    const owner = await LabOwner.findOne({ phone_number: senderPhone });
    if (owner) {
      // Owner sending message - send directly to their admin
      const admin = await Admin.findById(owner.admin_id);
      if (admin) {
        const directMessage = `📬 Direct Message from Owner\n\n💬 ${Body}\n\n---\nRegards,\n${owner.name.first} ${owner.name.last}`;
        await sendWhatsAppMessage(admin.phone_number, directMessage);
        console.log('Direct message sent to admin');
      } else {
        console.log('No admin found for this owner');
      }
      return res.status(200).send('OK');
    }

    console.log('Message from unknown number, ignoring');
    res.status(200).send('OK');
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(500).send('Error');
  }
});

module.exports = router;
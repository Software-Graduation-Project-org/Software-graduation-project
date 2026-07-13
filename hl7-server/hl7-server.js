const express = require('express');
const mongoose = require('mongoose');
const net = require('net');
const EventEmitter = require('events');
const moment = require('moment');

class HL7Server extends EventEmitter {
  constructor(port = 2575) {
    super();
    this.port = port;
    this.server = null;
    this.connections = new Map();
  }

  start() {
    this.server = net.createServer((socket) => {
      const clientId = `${socket.remoteAddress}:${socket.remotePort}`;
      console.log(`🔗 HL7 Client connected: ${clientId}`);

      let buffer = '';

      socket.on('data', (data) => {
        buffer += data.toString();

        // Check for MLLP envelope (HL7 message wrapped in <VT>...<FS><CR>)
        const startBlock = String.fromCharCode(11); // <VT>
        const endBlock = String.fromCharCode(28) + String.fromCharCode(13); // <FS><CR>

        if (buffer.includes(startBlock) && buffer.includes(endBlock)) {
          const startIndex = buffer.indexOf(startBlock);
          const endIndex = buffer.indexOf(endBlock);

          if (startIndex < endIndex) {
            const hl7Message = buffer.substring(startIndex + 1, endIndex);
            buffer = buffer.substring(endIndex + 2);

            this.handleHL7Message(hl7Message, socket, clientId);
          }
        }
      });

      socket.on('close', () => {
        console.log(`❌ HL7 Client disconnected: ${clientId}`);
        this.connections.delete(clientId);
      });

      socket.on('error', (err) => {
        console.error(`⚠️ HL7 Socket error for ${clientId}:`, err.message);
      });

      this.connections.set(clientId, socket);
    });

    this.server.listen(this.port, () => {
      console.log(`🏥 HL7 Server listening on port ${this.port}`);
      console.log(`📡 Ready to receive HL7 messages (ORM, ORU)`);
    });

    this.server.on('error', (err) => {
      console.error('❌ HL7 Server error:', err.message);
    });
  }

  handleHL7Message(message, socket, clientId) {
    try {
      console.log(`📨 Received HL7 message from ${clientId}:`);
      console.log(message.substring(0, 200) + (message.length > 200 ? '...' : ''));

      const segments = message.split('\r');
      const msh = segments.find(s => s.startsWith('MSH'));

      if (!msh) {
        console.error('❌ Invalid HL7 message: Missing MSH segment');
        return;
      }

      const fields = msh.split('|');
      const messageType = fields[9]; // MSH-9: Message Type
      const triggerEvent = fields[10]; // MSH-10: Trigger Event

      console.log(`📋 Message Type: ${messageType}^${triggerEvent}`);

      switch (`${messageType}^${triggerEvent}`) {
        case 'ORM^O01':
          this.handleORM(message, segments, socket, clientId);
          break;
        case 'ORU^R01':
          this.handleORU(message, segments, socket, clientId);
          break;
        default:
          console.log(`⚠️ Unsupported message type: ${messageType}^${triggerEvent}`);
      }

    } catch (error) {
      console.error('❌ Error processing HL7 message:', error.message);
    }
  }

  handleORM(message, segments, socket, clientId) {
    console.log('🏥 Processing ORM^O01 (Order Message)');

    // Extract order information
    const orc = segments.find(s => s.startsWith('ORC'));
    const obr = segments.find(s => s.startsWith('OBR'));

    if (!orc || !obr) {
      console.error('❌ Invalid ORM: Missing ORC or OBR segments');
      return;
    }

    const orcFields = orc.split('|');
    const obrFields = obr.split('|');

    const orderInfo = {
      orderControl: orcFields[1], // ORC-1: Order Control
      placerOrderNumber: orcFields[2], // ORC-2: Placer Order Number
      fillerOrderNumber: orcFields[3], // ORC-3: Filler Order Number
      testCode: obrFields[4], // OBR-4: Universal Service ID
      priority: obrFields[5], // OBR-5: Priority
      requestedDateTime: obrFields[6], // OBR-6: Requested Date/Time
      observationDateTime: obrFields[7], // OBR-7: Observation Date/Time
      collectorIdentifier: obrFields[10], // OBR-10: Collector Identifier
      specimenReceivedDateTime: obrFields[14], // OBR-14: Specimen Received Date/Time
    };

    console.log('📋 Order Info:', orderInfo);

    // Emit event for backend to process
    this.emit('orm-received', {
      message,
      orderInfo,
      clientId,
      timestamp: new Date()
    });

    // Send ACK
    this.sendACK(socket, 'ORM', 'O01', orderInfo.placerOrderNumber);
  }

  handleORU(message, segments, socket, clientId) {
    console.log('📊 Processing ORU^R01 (Result Message)');

    // Extract result information
    const obr = segments.find(s => s.startsWith('OBR'));
    const obxSegments = segments.filter(s => s.startsWith('OBX'));

    if (!obr) {
      console.error('❌ Invalid ORU: Missing OBR segment');
      return;
    }

    const obrFields = obr.split('|');

    const resultInfo = {
      fillerOrderNumber: obrFields[3], // OBR-3: Filler Order Number
      universalServiceId: obrFields[4], // OBR-4: Universal Service ID
      priority: obrFields[5], // OBR-5: Priority
      resultStatus: obrFields[25], // OBR-25: Result Status
      parentResult: obrFields[26], // OBR-26: Parent Result
      resultCopiesTo: obrFields[28], // OBR-28: Result Copies To
      parent: obrFields[29], // OBR-29: Parent
    };

    const observations = obxSegments.map(obx => {
      const fields = obx.split('|');
      return {
        setId: fields[1], // OBX-1: Set ID
        valueType: fields[2], // OBX-2: Value Type
        observationIdentifier: fields[3], // OBX-3: Observation Identifier
        observationSubId: fields[4], // OBX-4: Observation Sub-ID
        observationValue: fields[5], // OBX-5: Observation Value
        units: fields[6], // OBX-6: Units
        referenceRange: fields[7], // OBX-7: Reference Range
        abnormalFlags: fields[8], // OBX-8: Abnormal Flags
        probability: fields[9], // OBX-9: Probability
        natureOfAbnormalTest: fields[10], // OBX-10: Nature of Abnormal Test
        observationResultStatus: fields[11], // OBX-11: Observation Result Status
        dateLastObsNormalValues: fields[12], // OBX-12: Date Last Obs Normal Values
        userDefinedAccessChecks: fields[13], // OBX-13: User Defined Access Checks
        dateTimeOfTheObservation: fields[14], // OBX-14: Date/Time of the Observation
      };
    });

    console.log('📋 Result Info:', resultInfo);
    console.log(`📊 Observations: ${observations.length}`);

    // Emit event for backend to process
    this.emit('oru-received', {
      message,
      resultInfo,
      observations,
      clientId,
      timestamp: new Date()
    });

    // Send ACK
    this.sendACK(socket, 'ORU', 'R01', resultInfo.fillerOrderNumber);
  }

  sendACK(socket, messageType, triggerEvent, messageId) {
    const timestamp = moment().format('YYYYMMDDHHmmss');
    const ackMessage = `MSH|^~\\&|LIS|LAB|APP|SENDING|${timestamp}||ACK|${Date.now()}|P|2.5\rMSA|AA|${messageId}`;

    // Wrap in MLLP envelope
    const mllpMessage = String.fromCharCode(11) + ackMessage + String.fromCharCode(28) + String.fromCharCode(13);

    socket.write(mllpMessage);
    console.log(`✅ Sent ACK for ${messageType}^${triggerEvent}`);
  }

  stop() {
    if (this.server) {
      this.server.close();
      console.log('🛑 HL7 Server stopped');
    }
  }

  // Method to parse HL7 message directly (for internal processing)
  async parseHL7Message(message) {
    try {
      const segments = message.split('\r');
      const msh = segments.find(s => s.startsWith('MSH'));

      if (!msh) {
        throw new Error('Invalid HL7 message: Missing MSH segment');
      }

      const fields = msh.split('|');
      const messageType = fields[9]; // MSH-9: Message Type
      const triggerEvent = fields[10]; // MSH-10: Trigger Event

      if (`${messageType}^${triggerEvent}` !== 'ORU^R01') {
        throw new Error(`Unsupported message type for parsing: ${messageType}^${triggerEvent}`);
      }

      // Extract result information (same as handleORU)
      const obr = segments.find(s => s.startsWith('OBR'));
      const obxSegments = segments.filter(s => s.startsWith('OBX'));

      if (!obr) {
        throw new Error('Invalid ORU: Missing OBR segment');
      }

      const obrFields = obr.split('|');

      const resultInfo = {
        fillerOrderNumber: obrFields[3], // OBR-3: Filler Order Number
        universalServiceId: obrFields[4], // OBR-4: Universal Service ID
        priority: obrFields[5], // OBR-5: Priority
        resultStatus: obrFields[25], // OBR-25: Result Status
        parentResult: obrFields[26], // OBR-26: Parent Result
        resultCopiesTo: obrFields[28], // OBR-28: Result Copies To
        parent: obrFields[29], // OBR-29: Parent
      };

      const observations = obxSegments.map(obx => {
        const fields = obx.split('|');
        const observationIdentifier = fields[3]; // OBX-3: Observation Identifier (code^name)
        const identifierParts = observationIdentifier ? observationIdentifier.split('^') : ['', ''];
        
        return {
          setId: fields[1], // OBX-1: Set ID
          valueType: fields[2], // OBX-2: Value Type
          observationIdentifier: observationIdentifier,
          code: identifierParts[0] || '',
          name: identifierParts[1] || observationIdentifier || 'Unknown',
          observationSubId: fields[4], // OBX-4: Observation Sub-ID
          value: fields[5], // OBX-5: Observation Value
          component_value: fields[5], // Alias for compatibility
          units: fields[6], // OBX-6: Units
          referenceRange: fields[7], // OBX-7: Reference Range
          reference_range: fields[7], // Alias for compatibility
          abnormalFlags: fields[8], // OBX-8: Abnormal Flags
          isAbnormal: fields[8] && fields[8] !== 'N' && fields[8] !== '', // Check if abnormal
          probability: fields[9], // OBX-9: Probability
          natureOfAbnormalTest: fields[10], // OBX-10: Nature of Abnormal Test
          observationResultStatus: fields[11], // OBX-11: Observation Result Status
          dateLastObsNormalValues: fields[12], // OBX-12: Date Last Obs Normal Values
          userDefinedAccessChecks: fields[13], // OBX-13: User Defined Access Checks
          dateTimeOfTheObservation: fields[14], // OBX-14: Date/Time of the Observation
          remarks: '' // No remarks in standard OBX
        };
      });

      return {
        resultInfo,
        observations
      };

    } catch (error) {
      console.error('❌ Error parsing HL7 message:', error.message);
      throw error;
    }
  }
}

// Export for use in other modules
module.exports = HL7Server;
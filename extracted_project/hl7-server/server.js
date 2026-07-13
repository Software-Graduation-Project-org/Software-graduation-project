require('dotenv').config();
const mongoose = require('mongoose');
const HL7Server = require('./hl7-server');

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGO_URI);
    console.log(`📊 MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    console.error(`❌ Database connection error: ${error.message}`);
    process.exit(1);
  }
};

const startHL7Server = async () => {
  await connectDB();

  const port = process.env.PORT || 2575; // Use PORT env var or default to 2575
  const hl7Server = new HL7Server(port);

  // Add HTTP server for backend communication
  const http = require('http');
  const httpPort = process.env.HTTP_PORT || (parseInt(port) + 1000); // Use HTTP_PORT or port + 1000

  const httpServer = http.createServer((req, res) => {
    if (req.method === 'POST' && req.url === '/process-hl7-oru') {
      let body = '';
      req.on('data', chunk => {
        body += chunk.toString();
      });
      req.on('end', async () => {
        try {
          const data = JSON.parse(body);
          console.log('🎭 Processing fake HL7 ORU message from backend via HTTP');

          // Parse the HL7 message directly using the same logic as handleORU
          const message = data.message;
          const segments = message.split('\r');
          const obr = segments.find(s => s.startsWith('OBR'));
          const obxSegments = segments.filter(s => s.startsWith('OBX'));

          if (!obr) {
            console.error('❌ Invalid ORU: Missing OBR segment');
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Invalid ORU: Missing OBR segment' }));
            return;
          }

          const obrFields = obr.split('|');

          const resultInfo = {
            detailId: data.orderInfo.detailId,
            testCode: data.orderInfo.testCode,
            testName: data.orderInfo.testName,
            patientId: data.orderInfo.patientId,
            timestamp: data.orderInfo.timestamp,
            isAbnormal: data.orderInfo.isAbnormal,
            fillerOrderNumber: obrFields[3], // OBR-3: Filler Order Number
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
              // Add parsed names for easier processing
              name: fields[3] ? fields[3].split('^')[1] : '',
              code: fields[3] ? fields[3].split('^')[0] : '',
              value: fields[5] || '',
              isAbnormal: fields[8] && fields[8] !== 'N' && fields[8] !== '',
              referenceRange: fields[7] || ''
            };
          });

          console.log('📊 Fake ORU Result processed:', resultInfo);
          console.log(`📈 ${observations.length} observations processed`);

          console.log('📊 Fake ORU Result processed:', resultInfo);
          console.log(`📈 ${observations.length} observations processed`);

          // Send result back to backend via HTTP
          const backendOptions = {
            hostname: 'localhost',
            port: 5000, // Backend port
            path: '/api/internal/hl7-result',
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Content-Length': Buffer.byteLength(JSON.stringify({
                resultInfo,
                observations
              }))
            }
          };

          const backendReq = http.request(backendOptions, (backendRes) => {
            console.log(`📡 HL7 result sent to backend: ${backendRes.statusCode}`);
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ message: 'HL7 ORU processed successfully' }));
          });

          backendReq.on('error', (e) => {
            console.error(`❌ Error sending HL7 result to backend: ${e.message}`);
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: e.message }));
          });

          backendReq.write(JSON.stringify({
            resultInfo,
            observations
          }));
          backendReq.end();

        } catch (error) {
          console.error('❌ Error processing fake HL7 ORU message:', error);
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: error.message }));
        }
      });
    } else {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Endpoint not found' }));
    }
  });

  httpServer.listen(httpPort, () => {
    console.log(`🌐 HL7 HTTP Server listening on port ${httpPort}`);
  });

  // Handle ORM messages (orders from backend)
  hl7Server.on('orm-received', (data) => {
    console.log('📨 ORM Order received:', data.orderInfo);

    // Here we could emit to device simulators or log for processing
    // For now, just log the order
    console.log('🏥 Order ready for device processing');
  });

  // Handle ORU messages (results from devices)
  hl7Server.on('oru-received', (data) => {
    console.log('📊 ORU Result received:', data.resultInfo);
    console.log(`📈 ${data.observations.length} observations received`);

    // Emit event that backend can listen to
    process.emit('hl7-result', data);
  });

  hl7Server.start();

  // Graceful shutdown
  process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down HL7 Server...');
    hl7Server.stop();
    mongoose.connection.close();
    process.exit(0);
  });
};

// Handle ORM messages from backend
process.on('send-hl7-orm', (data) => {
  console.log('📨 Received ORM from backend:', data.orderInfo.testCode);

  // Forward to all connected device simulators
  // In a real implementation, this would route to specific devices
  process.emit('hl7-orm', data);
});

// Handle direct ORU processing from backend (for fake data simulation)
process.on('process-hl7-oru', async (data) => {
  console.log('🎭 Processing fake HL7 ORU message from backend simulation');

  try {
    // Parse the HL7 message directly
    const hl7Server = new HL7Server(2575);
    const parsedData = await hl7Server.parseHL7Message(data.message);

    // Create result data structure
    const resultData = {
      resultInfo: {
        detailId: data.orderInfo.detailId,
        testCode: data.orderInfo.testCode,
        testName: data.orderInfo.testName,
        patientId: data.orderInfo.patientId,
        timestamp: data.orderInfo.timestamp,
        isAbnormal: data.orderInfo.isAbnormal
      },
      observations: parsedData.observations || []
    };

    console.log('📊 Fake ORU Result processed:', resultData.resultInfo);
    console.log(`📈 ${resultData.observations.length} observations processed`);

    // Instead of emitting, make HTTP call to backend
    const http = require('http');

    const postData = JSON.stringify(resultData);

    const options = {
      hostname: 'localhost',
      port: 5000,
      path: '/api/internal/hl7-result',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };

    const req = http.request(options, (res) => {
      console.log(`📡 HL7 result sent to backend: ${res.statusCode}`);
    });

    req.on('error', (e) => {
      console.error(`❌ Error sending HL7 result to backend: ${e.message}`);
    });

    req.write(postData);
    req.end();

  } catch (error) {
    console.error('❌ Error processing fake HL7 ORU message:', error);
  }
});

startHL7Server();
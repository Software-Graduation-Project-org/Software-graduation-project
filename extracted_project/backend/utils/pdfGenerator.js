const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

/**
 * Generate PDF for test result matching Flutter frontend design
 * @param {Object} reportData - Report data object
 * @returns {Promise<string>} - Path to generated PDF file
 */
async function generateTestResultPDF(reportData) {
  return new Promise((resolve, reject) => {
    try {
      const fileName = `test_result_${reportData.order._id}_${Date.now()}.pdf`;
      const filePath = path.join(__dirname, '../../temp', fileName);

      // Ensure temp directory exists
      const tempDir = path.dirname(filePath);
      if (!fs.existsSync(tempDir)) {
        fs.mkdirSync(tempDir, { recursive: true });
      }

      const doc = new PDFDocument({
        size: 'A4',
        margin: 50,
        bufferPages: true
      });

      const stream = fs.createWriteStream(filePath);
      doc.pipe(stream);

      // Colors matching Flutter theme
      const primaryBlue = [26, 115, 232]; // #1a73e8
      const textDark = [33, 33, 33]; // #212121
      const textMedium = [117, 117, 117]; // #757575
      const lightBlue = [232, 240, 254]; // #e8f0fe
      const borderColor = [220, 227, 238]; // #dce3ee

      // Helper function to add header
      function addHeader() {
        // Header background
        doc.rect(0, 0, doc.page.width, 80).fill(primaryBlue[0]/255, primaryBlue[1]/255, primaryBlue[2]/255);

        // Hospital icon (simulated with text)
        doc.fillColor('white').fontSize(24).font('Helvetica-Bold').text('MEDICAL LAB', 50, 25);

        // Lab name and info
        doc.fillColor('white').fontSize(18).font('Helvetica-Bold')
           .text(reportData.lab.name, 90, 20, { width: 300 });

        if (reportData.lab.address) {
          doc.fillColor('white').fontSize(10).font('Helvetica')
             .text(reportData.lab.address, 90, 45);
        }

        if (reportData.lab.phone_number) {
          doc.fillColor('white').fontSize(10).font('Helvetica')
             .text(`Phone: ${reportData.lab.phone_number}`, 90, 58);
        }

        // Title
        doc.fillColor('white').fontSize(14).font('Helvetica')
           .text('Laboratory Test Report', 90, 70);

        // Status badge (top right)
        const statusText = 'COMPLETED';
        const statusColor = [76, 175, 80]; // green

        doc.fillColor(statusColor[0]/255, statusColor[1]/255, statusColor[2]/255)
           .rect(doc.page.width - 150, 20, 100, 25).fill();

        doc.fillColor('white').fontSize(10).font('Helvetica-Bold')
           .text(statusText, doc.page.width - 125, 28);

        // Completed count
        doc.fillColor(textMedium[0]/255, textMedium[1]/255, textMedium[2]/255)
           .fontSize(9).font('Helvetica')
           .text('1/1 Completed', doc.page.width - 125, 45);
      }

      // Start with header
      addHeader();
      doc.moveDown(2);

      // Abnormal Results Warning Banner (if applicable)
      let hasAbnormal = false;
      let abnormalCount = 0;

      if (reportData.result.components && reportData.result.components.length > 0) {
        for (const component of reportData.result.components) {
          if (component.is_abnormal) {
            hasAbnormal = true;
            abnormalCount++;
          }
        }
      }

      if (hasAbnormal) {
        // Red warning banner
        doc.fillColor(1, 0.9, 0.9).rect(50, doc.y, doc.page.width - 100, 60).fill();
        doc.strokeColor(1, 0.5, 0.5).lineWidth(2).rect(50, doc.y - 60, doc.page.width - 100, 60).stroke();

        doc.fillColor(0.8, 0, 0).fontSize(16).font('Helvetica-Bold')
           .text('CRITICAL: Abnormal Results Detected', 70, doc.y - 45);

        doc.fillColor(0.6, 0, 0).fontSize(12).font('Helvetica')
           .text(`${abnormalCount} abnormal value(s) found. Please contact your healthcare provider immediately for interpretation and next steps.`,
                 70, doc.y - 25, { width: doc.page.width - 140 });

        doc.moveDown(2);
      }

      // Patient Information Section
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(16).font('Helvetica-Bold')
         .text('Patient Information', 50, doc.y);

      doc.moveDown(0.5);

      // Patient info in a bordered box
      const patientY = doc.y;
      doc.strokeColor(borderColor[0]/255, borderColor[1]/255, borderColor[2]/255)
         .lineWidth(1).rect(50, patientY, doc.page.width - 100, 80).stroke();

      // Patient Name (full width)
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('Patient Name:', 60, patientY + 10);
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text(reportData.patient.name, 140, patientY + 10);

      // ID Number and Gender (side by side)
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('ID Number:', 60, patientY + 25);
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text(reportData.patient.patient_id || 'N/A', 130, patientY + 25);

      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('Gender:', 300, patientY + 25);
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text(reportData.patient.gender || 'N/A', 350, patientY + 25);

      // Date of Birth and Insurance (side by side)
      const ageText = reportData.patient.age ? `${reportData.patient.age} years` : 'N/A';
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('Age:', 60, patientY + 40);
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text(ageText, 90, patientY + 40);

      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('Insurance:', 300, patientY + 40);
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text('None', 360, patientY + 40);

      // Order Date (full width)
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('Order Date:', 60, patientY + 55);
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text(new Date(reportData.order.date).toLocaleDateString(), 130, patientY + 55);

      // Report Date and Doctor (side by side)
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('Report Date:', 60, patientY + 70);
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text(new Date(reportData.report_date).toLocaleDateString(), 130, patientY + 70);

      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('Doctor:', 300, patientY + 70);
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text('Not assigned', 340, patientY + 70);

      doc.moveDown(3);

      // Test Results Section
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(16).font('Helvetica-Bold')
         .text('Test Results', 50, doc.y);

      doc.moveDown(0.5);

      // Results table
      const tableTop = doc.y;
      const tableWidth = doc.page.width - 100;
      const colWidths = [tableWidth * 0.35, tableWidth * 0.25, tableWidth * 0.25, tableWidth * 0.15];

      // Table border
      doc.strokeColor(borderColor[0]/255, borderColor[1]/255, borderColor[2]/255)
         .lineWidth(1).rect(50, tableTop, tableWidth, 30).stroke();

      // Table header background
      doc.fillColor(lightBlue[0]/255, lightBlue[1]/255, lightBlue[2]/255)
         .rect(50, tableTop, tableWidth, 30).fill();

      // Table headers
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold');

      doc.text('Test Name', 60, tableTop + 10);
      doc.text('Result', 60 + colWidths[0], tableTop + 10, { width: colWidths[1], align: 'center' });
      doc.text('Reference', 60 + colWidths[0] + colWidths[1], tableTop + 10, { width: colWidths[2], align: 'center' });
      doc.text('Unit', 60 + colWidths[0] + colWidths[1] + colWidths[2], tableTop + 10, { width: colWidths[3], align: 'center' });

      let currentY = tableTop + 35;

      // Test result row
      doc.strokeColor(borderColor[0]/255, borderColor[1]/255, borderColor[2]/255)
         .lineWidth(1).rect(50, currentY - 5, tableWidth, 25).stroke();

      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(11).font('Helvetica');

      // Test name
      doc.text(reportData.test.name, 60, currentY);

      // Result
      let resultText = 'N/A';
      let resultColor = textDark;

      if (reportData.result.components && reportData.result.components.length > 0) {
        // Component-based results - show first component or summary
        const firstComponent = reportData.result.components[0];
        resultText = firstComponent.result_value || 'N/A';
        if (firstComponent.is_abnormal) {
          resultColor = [244, 67, 54]; // red
        }
      } else {
        resultText = reportData.result.value || 'N/A';
      }

      doc.fillColor(resultColor[0]/255, resultColor[1]/255, resultColor[2]/255)
         .text(resultText, 60 + colWidths[0], currentY, { width: colWidths[1], align: 'center' });

      // Reference range
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .text(reportData.result.reference_range || 'N/A', 60 + colWidths[0] + colWidths[1], currentY, { width: colWidths[2], align: 'center' });

      // Unit
      const unitText = (reportData.result.units || '').replace(/μ/g, 'u');
      doc.text(unitText, 60 + colWidths[0] + colWidths[1] + colWidths[2], currentY, { width: colWidths[3], align: 'center' });

      currentY += 30;

      // Add component details if they exist
      if (reportData.result.components && reportData.result.components.length > 1) {
        for (let i = 1; i < reportData.result.components.length; i++) {
          const component = reportData.result.components[i];

          doc.strokeColor(borderColor[0]/255, borderColor[1]/255, borderColor[2]/255)
             .lineWidth(1).rect(50, currentY - 5, tableWidth, 25).stroke();

          doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
             .fontSize(10).font('Helvetica')
             .text(`  ${component.component_name || 'Component'}`, 60, currentY);

          const compResultColor = component.is_abnormal ? [244, 67, 54] : textDark;
          doc.fillColor(compResultColor[0]/255, compResultColor[1]/255, compResultColor[2]/255)
             .text(component.result_value || 'N/A', 60 + colWidths[0], currentY, { width: colWidths[1], align: 'center' });

          doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
             .text(component.reference_range || 'N/A', 60 + colWidths[0] + colWidths[1], currentY, { width: colWidths[2], align: 'center' });

          doc.text(component.units || '', 60 + colWidths[0] + colWidths[1] + colWidths[2], currentY, { width: colWidths[3], align: 'center' });

          currentY += 25;
        }
      }

      // Remarks section
      if (reportData.result.remarks) {
        doc.moveDown(2);
        doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
           .fontSize(14).font('Helvetica-Bold')
           .text('Remarks:', 50, doc.y);

        doc.moveDown(0.5);
        doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
           .fontSize(11).font('Helvetica')
           .text(reportData.result.remarks, 50, doc.y, { width: doc.page.width - 100 });
      }

      // Technician
      if (reportData.technician) {
        doc.moveDown(1);
        doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
           .fontSize(12).font('Helvetica-Bold')
           .text('Technician:', 50, doc.y);
        doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
           .fontSize(12).font('Helvetica')
           .text(reportData.technician, 120, doc.y);
      }

      // Footer
      const footerY = doc.page.height - 50;
      doc.fillColor(textMedium[0]/255, textMedium[1]/255, textMedium[2]/255)
         .fontSize(8).font('Helvetica')
         .text('This report is confidential and intended for the patient named above only.', 50, footerY, { align: 'center', width: doc.page.width - 100 });

      doc.text('Generated by Medical Lab System', 50, footerY + 15, { align: 'center', width: doc.page.width - 100 });

      doc.end();

      stream.on('finish', () => {
        resolve(filePath);
      });

      stream.on('error', (error) => {
        reject(error);
      });

    } catch (error) {
      reject(error);
    }
  });
}

/**
 * Generate PDF for invoice
 * @param {Object} invoiceData - Invoice data object
 * @returns {Promise<string>} - Path to generated PDF file
 */
/**
 * Generate PDF for invoice matching Flutter frontend design
 * @param {Object} invoiceData - Invoice data object
 * @returns {Promise<string>} - Path to generated PDF file
 */
async function generateInvoicePDF(invoiceData) {
  return new Promise((resolve, reject) => {
    try {
      const fileName = `invoice_${invoiceData.invoice_id}_${Date.now()}.pdf`;
      const filePath = path.join(__dirname, '../../temp', fileName);

      // Ensure temp directory exists
      const tempDir = path.dirname(filePath);
      if (!fs.existsSync(tempDir)) {
        fs.mkdirSync(tempDir, { recursive: true });
      }

      const doc = new PDFDocument({
        size: 'A4',
        margin: 50,
        bufferPages: true
      });

      const stream = fs.createWriteStream(filePath);
      doc.pipe(stream);

      // Colors matching Flutter theme
      const primaryBlue = [26, 115, 232]; // #1a73e8
      const textDark = [33, 33, 33]; // #212121
      const textMedium = [117, 117, 117]; // #757575
      const lightBlue = [232, 240, 254]; // #e8f0fe
      const borderColor = [220, 227, 238]; // #dce3ee
      const successGreen = [76, 175, 80]; // green
      const warningOrange = [255, 152, 0]; // orange
      const errorRed = [244, 67, 54]; // red

      // Helper function to add header
      function addHeader() {
        // Header background
        doc.rect(0, 0, doc.page.width, 80).fill(primaryBlue[0]/255, primaryBlue[1]/255, primaryBlue[2]/255);

        // Hospital icon (simulated with text)
        doc.fillColor('white').fontSize(24).font('Helvetica-Bold').text('MEDICAL LAB', 50, 25);

        // Lab name and info
        doc.fillColor('white').fontSize(18).font('Helvetica-Bold')
           .text(invoiceData.lab.name, 90, 20, { width: 300 });

        if (invoiceData.lab.address) {
          doc.fillColor('white').fontSize(10).font('Helvetica')
             .text(invoiceData.lab.address, 90, 45);
        }

        if (invoiceData.lab.phone_number) {
          doc.fillColor('white').fontSize(10).font('Helvetica')
             .text(`Phone: ${invoiceData.lab.phone_number}`, 90, 58);
        }

        // Title
        doc.fillColor('white').fontSize(14).font('Helvetica')
           .text('Laboratory Invoice', 90, 70);

        // Status badge (top right)
        let statusText = 'UNPAID';
        let statusColor = errorRed;

        if (invoiceData.status === 'paid' || invoiceData.status === 'Paid') {
          statusText = 'PAID';
          statusColor = successGreen;
        } else if (invoiceData.status === 'partial' || invoiceData.status === 'Partial') {
          statusText = 'PARTIAL';
          statusColor = warningOrange;
        }

        doc.fillColor(statusColor[0]/255, statusColor[1]/255, statusColor[2]/255)
           .rect(doc.page.width - 120, 20, 80, 25).fill();

        doc.fillColor('white').fontSize(10).font('Helvetica-Bold')
           .text(statusText, doc.page.width - 100, 28);
      }

      // Start with header
      addHeader();
      doc.moveDown(2);

      // Invoice Details Section
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(16).font('Helvetica-Bold')
         .text('Invoice Details', 50, doc.y);

      doc.moveDown(0.5);

      // Invoice details in a bordered box
      const invoiceY = doc.y;
      doc.strokeColor(borderColor[0]/255, borderColor[1]/255, borderColor[2]/255)
         .lineWidth(1).rect(50, invoiceY, doc.page.width - 100, 60).stroke();

      // Invoice Number and Date (side by side)
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('Invoice Number:', 60, invoiceY + 10);
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text(invoiceData.invoice_id, 150, invoiceY + 10);

      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('Invoice Date:', 350, invoiceY + 10);
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text(new Date(invoiceData.created_at || invoiceData.invoice_date).toLocaleDateString(), 430, invoiceY + 10);

      // Due Date and Payment Method (side by side)
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('Due Date:', 60, invoiceY + 25);
      const dueDate = invoiceData.due_date ? new Date(invoiceData.due_date).toLocaleDateString() : 'N/A';
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text(dueDate, 120, invoiceY + 25);

      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('Payment Method:', 350, invoiceY + 25);
      const paymentMethod = invoiceData.payment_method || 'Cash';
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text(paymentMethod, 450, invoiceY + 25);

      // Order ID and Status (side by side)
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('Order ID:', 60, invoiceY + 40);
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text(invoiceData.order_id || 'N/A', 120, invoiceY + 40);

      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('Status:', 350, invoiceY + 40);
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text(invoiceData.status || 'Unpaid', 390, invoiceY + 40);

      doc.moveDown(3);

      // Patient Information Section
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(16).font('Helvetica-Bold')
         .text('Patient Information', 50, doc.y);

      doc.moveDown(0.5);

      // Patient info in a bordered box
      const patientY = doc.y;
      doc.strokeColor(borderColor[0]/255, borderColor[1]/255, borderColor[2]/255)
         .lineWidth(1).rect(50, patientY, doc.page.width - 100, 45).stroke();

      // Patient Name (full width)
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('Patient Name:', 60, patientY + 10);
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text(invoiceData.patient.name, 140, patientY + 10);

      // ID Number and Phone (side by side)
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('ID Number:', 60, patientY + 25);
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text(invoiceData.patient.patient_id || 'N/A', 130, patientY + 25);

      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold').text('Phone:', 350, patientY + 25);
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica').text(invoiceData.patient.phone || 'N/A', 390, patientY + 25);

      doc.moveDown(3);

      // Tests/Services Section
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(16).font('Helvetica-Bold')
         .text('Tests & Services', 50, doc.y);

      doc.moveDown(0.5);

      // Tests table
      const tableTop = doc.y;
      const tableWidth = doc.page.width - 100;
      const colWidths = [tableWidth * 0.5, tableWidth * 0.15, tableWidth * 0.175, tableWidth * 0.175];

      // Table border
      doc.strokeColor(borderColor[0]/255, borderColor[1]/255, borderColor[2]/255)
         .lineWidth(1).rect(50, tableTop, tableWidth, 30).stroke();

      // Table header background
      doc.fillColor(lightBlue[0]/255, lightBlue[1]/255, lightBlue[2]/255)
         .rect(50, tableTop, tableWidth, 30).fill();

      // Table headers
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold');

      doc.text('Test/Service', 60, tableTop + 10);
      doc.text('Qty', 60 + colWidths[0], tableTop + 10, { width: colWidths[1], align: 'center' });
      doc.text('Unit Price', 60 + colWidths[0] + colWidths[1], tableTop + 10, { width: colWidths[2], align: 'center' });
      doc.text('Total', 60 + colWidths[0] + colWidths[1] + colWidths[2], tableTop + 10, { width: colWidths[3], align: 'center' });

      let currentY = tableTop + 35;

      // Test rows
      if (invoiceData.tests && invoiceData.tests.length > 0) {
        invoiceData.tests.forEach((test) => {
          doc.strokeColor(borderColor[0]/255, borderColor[1]/255, borderColor[2]/255)
             .lineWidth(1).rect(50, currentY - 5, tableWidth, 25).stroke();

          doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
             .fontSize(11).font('Helvetica');

          // Test name
          doc.text(test.test_name || test.name, 60, currentY);

          // Quantity
          doc.text((test.quantity || 1).toString(), 60 + colWidths[0], currentY, { width: colWidths[1], align: 'center' });

          // Unit price
          const unitPrice = test.price || test.unit_price || 0;
          doc.text(`$${unitPrice.toFixed(2)}`, 60 + colWidths[0] + colWidths[1], currentY, { width: colWidths[2], align: 'center' });

          // Total
          const quantity = test.quantity || 1;
          const total = unitPrice * quantity;
          doc.text(`$${total.toFixed(2)}`, 60 + colWidths[0] + colWidths[1] + colWidths[2], currentY, { width: colWidths[3], align: 'center' });

          currentY += 25;
        });
      }

      // Totals section
      doc.moveDown(2);

      // Totals box
      const totalsY = doc.y;
      const totalsWidth = 250;
      const totalsHeight = 80;

      doc.strokeColor(borderColor[0]/255, borderColor[1]/255, borderColor[2]/255)
         .lineWidth(1).rect(doc.page.width - 50 - totalsWidth, totalsY, totalsWidth, totalsHeight).stroke();

      // Totals background
      doc.fillColor(lightBlue[0]/255, lightBlue[1]/255, lightBlue[2]/255)
         .rect(doc.page.width - 50 - totalsWidth, totalsY, totalsWidth, totalsHeight).fill();

      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica-Bold');

      let totalsCurrentY = totalsY + 10;

      // Subtotal
      doc.text('Subtotal:', doc.page.width - 40 - totalsWidth + 10, totalsCurrentY);
      doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
         .fontSize(12).font('Helvetica')
         .text(`$${(invoiceData.subtotal || 0).toFixed(2)}`, doc.page.width - 60, totalsCurrentY, { align: 'right', width: 80 });

      totalsCurrentY += 15;

      // Discount
      if (invoiceData.discount && invoiceData.discount > 0) {
        doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
           .fontSize(12).font('Helvetica-Bold')
           .text('Discount:', doc.page.width - 40 - totalsWidth + 10, totalsCurrentY);
        doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
           .fontSize(12).font('Helvetica')
           .text(`-$${(invoiceData.discount || 0).toFixed(2)}`, doc.page.width - 60, totalsCurrentY, { align: 'right', width: 80 });

        totalsCurrentY += 15;
      }

      // Tax
      if (invoiceData.tax && invoiceData.tax > 0) {
        doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
           .fontSize(12).font('Helvetica-Bold')
           .text('Tax:', doc.page.width - 40 - totalsWidth + 10, totalsCurrentY);
        doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
           .fontSize(12).font('Helvetica')
           .text(`$${(invoiceData.tax || 0).toFixed(2)}`, doc.page.width - 60, totalsCurrentY, { align: 'right', width: 80 });

        totalsCurrentY += 15;
      }

      // Total
      doc.fillColor(primaryBlue[0]/255, primaryBlue[1]/255, primaryBlue[2]/255)
         .fontSize(14).font('Helvetica-Bold')
         .text('TOTAL:', doc.page.width - 40 - totalsWidth + 10, totalsCurrentY + 5);

      doc.fillColor(primaryBlue[0]/255, primaryBlue[1]/255, primaryBlue[2]/255)
         .fontSize(14).font('Helvetica-Bold')
         .text(`$${(invoiceData.total_amount || invoiceData.total || 0).toFixed(2)}`, doc.page.width - 60, totalsCurrentY + 5, { align: 'right', width: 80 });

      // Payment Information Section
      if (invoiceData.payments && invoiceData.payments.length > 0) {
        doc.moveDown(3);
        doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
           .fontSize(16).font('Helvetica-Bold')
           .text('Payment Information', 50, doc.y);

        doc.moveDown(0.5);

        invoiceData.payments.forEach((payment, index) => {
          const paymentY = doc.y + (index * 40);
          doc.strokeColor(borderColor[0]/255, borderColor[1]/255, borderColor[2]/255)
             .lineWidth(1).rect(50, paymentY, doc.page.width - 100, 35).stroke();

          doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
             .fontSize(12).font('Helvetica-Bold').text('Amount Paid:', 60, paymentY + 8);
          doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
             .fontSize(12).font('Helvetica').text(`$${payment.amount_paid.toFixed(2)}`, 140, paymentY + 8);

          doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
             .fontSize(12).font('Helvetica-Bold').text('Payment Method:', 300, paymentY + 8);
          doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
             .fontSize(12).font('Helvetica').text(payment.payment_method || 'Cash', 400, paymentY + 8);

          doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
             .fontSize(12).font('Helvetica-Bold').text('Payment Date:', 60, paymentY + 20);
          doc.fillColor(textDark[0]/255, textDark[1]/255, textDark[2]/255)
             .fontSize(12).font('Helvetica').text(new Date(payment.payment_date).toLocaleDateString(), 140, paymentY + 20);
        });
      }

      // Footer
      const footerY = doc.page.height - 50;
      doc.fillColor(textMedium[0]/255, textMedium[1]/255, textMedium[2]/255)
         .fontSize(8).font('Helvetica')
         .text('Thank you for choosing our medical laboratory services.', 50, footerY, { align: 'center', width: doc.page.width - 100 });

      doc.text('This invoice was generated electronically and is valid without signature.', 50, footerY + 12, { align: 'center', width: doc.page.width - 100 });

      doc.text('Generated by Medical Lab System', 50, footerY + 24, { align: 'center', width: doc.page.width - 100 });

      doc.end();

      stream.on('finish', () => {
        resolve(filePath);
      });

      stream.on('error', (error) => {
        reject(error);
      });

    } catch (error) {
      reject(error);
    }
  });
}

/**
 * Clean up temporary PDF files
 * @param {string} filePath - Path to the PDF file to delete
 */
function cleanupPDFFile(filePath) {
  try {
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      // console.log(`Cleaned up PDF file: ${filePath}`);
    }
  } catch (error) {
    console.error(`Error cleaning up PDF file ${filePath}:`, error);
  }
}

module.exports = {
  generateTestResultPDF,
  generateInvoicePDF,
  cleanupPDFFile
};